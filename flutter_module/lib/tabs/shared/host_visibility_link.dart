import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart's half of the smallest host contract: the native page tells a Flutter
/// surface whether it can be seen, so the surface can stop rendering when it
/// cannot. Used by `/product` and `/reviews`; the channel tables live in
/// `docs/hybrid-demo/ARCHITECTURE.md`.
///
/// | Direction      | Method       | Arguments   | Reply       |
/// |----------------|--------------|-------------|-------------|
/// | native → Dart  | `visibility` | `{visible}` | none        |
/// | Dart → native  | `ready`      | none        | `{visible}` |
///
/// A missing host counts as visible, so each route also runs standalone with
/// `flutter run --route /product`.
class HostVisibilityLink {
  HostVisibilityLink(String channelName)
    : _channel = MethodChannel(channelName);

  final MethodChannel _channel;

  /// Whether the host currently shows this surface.
  final ValueNotifier<bool> visible = ValueNotifier<bool>(true);

  /// Starts listening, then pulls the host's current state: a `visibility`
  /// push sent before the handler existed may have been dropped.
  Future<void> attach() async {
    _channel.setMethodCallHandler(_handle);
    try {
      final reply = await _channel.invokeMapMethod<String, Object?>('ready');
      if (reply != null) visible.value = reply['visible'] != false;
    } on MissingPluginException {
      // Standalone run: no host, stay visible.
    } on PlatformException catch (error) {
      debugPrint('${_channel.name}: ready failed: $error');
    }
  }

  void detach() {
    _channel.setMethodCallHandler(null);
    visible.dispose();
  }

  Future<void> _handle(MethodCall call) async {
    switch (call.method) {
      case 'visibility':
        final arguments = call.arguments as Map<Object?, Object?>?;
        visible.value = arguments?['visible'] != false;
      default:
        throw MissingPluginException('${_channel.name}: ${call.method}');
    }
  }
}
