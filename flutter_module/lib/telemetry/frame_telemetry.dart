import 'dart:async';
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Batches Flutter frame timings so telemetry does not become part of the load.
final class FrameTelemetryReporter {
  FrameTelemetryReporter(this.route);

  static const _channel = MethodChannel('com.theamorn.hybrid/telemetry');
  static const _minimumBatchFrames = 30;
  static const _maximumBatchAge = Duration(milliseconds: 750);

  final String route;
  final Stopwatch _batchAge = Stopwatch();

  int _frameCount = 0;
  int _buildMicroseconds = 0;
  int _rasterMicroseconds = 0;
  int _vsyncIntervalCount = 0;
  int _vsyncIntervalMicroseconds = 0;
  int? _lastVsyncMicroseconds;
  bool _sendInProgress = false;

  void start() {
    _batchAge.start();
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    Timer.periodic(_maximumBatchAge, (_) {
      if (_frameCount > 0 && !_sendInProgress) {
        unawaited(_sendBatch());
      }
    });
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frameCount += 1;
      _buildMicroseconds += timing.buildDuration.inMicroseconds;
      _rasterMicroseconds += timing.rasterDuration.inMicroseconds;

      final vsync = timing.timestampInMicroseconds(FramePhase.vsyncStart);
      final previousVsync = _lastVsyncMicroseconds;
      if (previousVsync != null && vsync > previousVsync) {
        _vsyncIntervalMicroseconds += vsync - previousVsync;
        _vsyncIntervalCount += 1;
      }
      _lastVsyncMicroseconds = vsync;
    }

    final batchReady =
        _frameCount >= _minimumBatchFrames ||
        _batchAge.elapsed >= _maximumBatchAge;
    if (batchReady && !_sendInProgress) {
      unawaited(_sendBatch());
    }
  }

  Future<void> _sendBatch() async {
    if (_frameCount == 0) {
      return;
    }

    _sendInProgress = true;
    final frames = _frameCount;
    final buildMicros = _buildMicroseconds;
    final rasterMicros = _rasterMicroseconds;
    final intervalCount = _vsyncIntervalCount;
    final intervalMicros = _vsyncIntervalMicroseconds;

    _frameCount = 0;
    _buildMicroseconds = 0;
    _rasterMicroseconds = 0;
    _vsyncIntervalCount = 0;
    _vsyncIntervalMicroseconds = 0;
    _batchAge.reset();

    final fps = intervalCount == 0
        ? 0.0
        : 1000000.0 * intervalCount / intervalMicros;
    try {
      await _channel.invokeMethod<void>('reportFrameTimings', {
        'route': route,
        'uiMillis': buildMicros / frames / 1000.0,
        'rasterMillis': rasterMicros / frames / 1000.0,
        'fps': fps,
      });
    } on MissingPluginException {
      // Expected when the module runs standalone without a native HUD.
    } on PlatformException {
      // Telemetry must never disturb the feature being measured.
    } finally {
      _sendInProgress = false;
    }
  }
}
