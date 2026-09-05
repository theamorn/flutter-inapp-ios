import 'dart:async';
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Batches Flutter frame timings so telemetry does not become part of the load.
final class FrameTelemetryReporter with WidgetsBindingObserver {
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
  bool _started = false;
  bool _active = true;
  Timer? _timer;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    didChangeAppLifecycleState(
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
    );
  }

  void stop() {
    if (!_started) return;
    _started = false;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    _resetWindow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _timer?.cancel();
    _resetWindow();
    if (!_started || !_active) return;
    _batchAge.start();
    _timer = Timer.periodic(_maximumBatchAge, (_) {
      if (_frameCount > 0 && !_sendInProgress) {
        unawaited(_sendBatch());
      }
    });
  }

  void _resetWindow() {
    _frameCount = 0;
    _buildMicroseconds = 0;
    _rasterMicroseconds = 0;
    _vsyncIntervalCount = 0;
    _vsyncIntervalMicroseconds = 0;
    // Hidden time must never become a very slow frame on tab return.
    _lastVsyncMicroseconds = null;
    _batchAge.stop();
    _batchAge.reset();
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!_started || !_active) return;
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
