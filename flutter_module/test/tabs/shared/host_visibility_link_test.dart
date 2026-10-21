import 'package:flutter/services.dart';
import 'package:flutter_module/tabs/shared/host_visibility_link.dart';
import 'package:flutter_test/flutter_test.dart';

const _name = 'com.theamorn.hybrid/test-surface';
const _channel = MethodChannel(_name);
const _codec = StandardMethodCodec();

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

/// Delivers [method] from the "host", as a native `invokeMethod` would.
Future<void> _fromHost(String method, Object? arguments) async {
  await _messenger.handlePlatformMessage(
    _name,
    _codec.encodeMethodCall(MethodCall(method, arguments)),
    (_) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => _messenger.setMockMethodCallHandler(_channel, null));

  test('ready pulls the host state', () async {
    _messenger.setMockMethodCallHandler(_channel, (call) async {
      expect(call.method, 'ready');
      return {'visible': false};
    });
    final link = HostVisibilityLink(_name);

    await link.attach();

    expect(link.visible.value, isFalse);
    link.detach();
  });

  test('a missing host counts as visible', () async {
    final link = HostVisibilityLink(_name);

    await link.attach();

    expect(link.visible.value, isTrue);
    link.detach();
  });

  test('follows visibility pushes from the host', () async {
    _messenger.setMockMethodCallHandler(
      _channel,
      (_) async => {'visible': true},
    );
    final link = HostVisibilityLink(_name);
    await link.attach();
    final seen = <bool>[];
    link.visible.addListener(() => seen.add(link.visible.value));

    await _fromHost('visibility', {'visible': false});
    await _fromHost('visibility', {'visible': true});

    expect(seen, [false, true]);
    link.detach();
  });
}
