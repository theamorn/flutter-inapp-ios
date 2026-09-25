import 'package:flutter/services.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// What the host knows about the tile when Dart asks, via `ready`.
class PromoHostState {
  const PromoHostState({required this.visible, required this.progress});

  final bool visible;
  final double progress;
}

/// Dart's half of the `com.theamorn.hybrid/promo` contract. The table lives
/// in `docs/hybrid-demo/ARCHITECTURE.md`; do not rename anything here alone.
///
/// Every call to the host tolerates a missing host, so the route also runs
/// standalone with `flutter run --route /promo`.
class PromoHostLink {
  PromoHostLink({
    required this.onVisibility,
    required this.onScroll,
    this._channel = const MethodChannel(channelName),
    BoundsThrottle? boundsThrottle,
  }) : _boundsThrottle = boundsThrottle ?? BoundsThrottle();

  static const channelName = 'com.theamorn.hybrid/promo';

  /// The host scrolled the tile into or out of view.
  final void Function(bool visible) onVisibility;

  /// [progress]: the tile center's offset from the viewport center, in half
  /// viewport heights. [velocity]: the page's content-offset speed, logical
  /// px/s, positive toward the end of the page.
  final void Function(double progress, double velocity) onScroll;

  final MethodChannel _channel;
  final BoundsThrottle _boundsThrottle;

  void attach() => _channel.setMethodCallHandler(_handle);

  void detach() => _channel.setMethodCallHandler(null);

  Future<void> _handle(MethodCall call) async {
    final arguments = call.arguments as Map<Object?, Object?>?;
    switch (call.method) {
      case 'visibility':
        onVisibility(arguments?['visible'] == true);
      case 'scroll':
        onScroll(
          _number(arguments?['progress']),
          _number(arguments?['velocity']),
        );
      default:
        throw MissingPluginException('promo: ${call.method}');
    }
  }

  static double _number(Object? value) => (value as num? ?? 0).toDouble();

  /// Asks the host for the tile's current state. Pushes sent before this
  /// handler existed may have been dropped, so Dart pulls instead of waiting.
  Future<PromoHostState?> ready() async {
    final reply = await _invoke<Map<Object?, Object?>>('ready');
    if (reply == null) return null;
    return PromoHostState(
      visible: reply['visible'] != false,
      progress: _number(reply['progress']),
    );
  }

  /// Tells the host the promo was claimed. The host owns the price.
  Future<void> claim(String code) =>
      _invoke<void>('claimPromo', {'code': code});

  /// Tells the host where the badge is, so a touch starting there goes to
  /// Flutter instead of scrolling the page. Throttled: nothing is sent while
  /// the badge hangs still.
  void reportBadgeBounds(vm.Aabb2 bounds, double nowSeconds) {
    if (!_boundsThrottle.shouldSend(bounds, nowSeconds)) return;
    _invoke<void>('badgeBounds', {
      'x': bounds.min.x,
      'y': bounds.min.y,
      'w': bounds.max.x - bounds.min.x,
      'h': bounds.max.y - bounds.min.y,
    });
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null; // Running standalone, without a host.
    } on PlatformException {
      return null;
    }
  }
}

/// Limits `badgeBounds` traffic: send when the badge moved noticeably, and
/// no more often than a frame at 30 Hz.
class BoundsThrottle {
  BoundsThrottle({this.minMove = 4, this.minInterval = 1 / 30});

  /// Logical pixels any edge must move before it is worth telling the host.
  final double minMove;
  final double minInterval;

  vm.Aabb2? _sent;
  double _sentAt = double.negativeInfinity;

  bool shouldSend(vm.Aabb2 bounds, double nowSeconds) {
    final sent = _sent;
    if (sent != null) {
      if (nowSeconds - _sentAt < minInterval) return false;
      final moved = [
        (bounds.min - sent.min).x.abs(),
        (bounds.min - sent.min).y.abs(),
        (bounds.max - sent.max).x.abs(),
        (bounds.max - sent.max).y.abs(),
      ].reduce((a, b) => a > b ? a : b);
      if (moved < minMove) return false;
    }
    _sent = vm.Aabb2.copy(bounds);
    _sentAt = nowSeconds;
    return true;
  }
}
