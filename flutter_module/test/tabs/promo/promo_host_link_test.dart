import 'package:flutter/services.dart';
import 'package:flutter_module/tabs/promo/promo_host_link.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

const _channel = MethodChannel(PromoHostLink.channelName);
const _codec = StandardMethodCodec();

vm.Aabb2 _box(double x, double y, [double w = 100, double h = 60]) =>
    vm.Aabb2.minMax(vm.Vector2(x, y), vm.Vector2(x + w, y + h));

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

/// Delivers [method] from the "host", as a native `invokeMethod` would.
Future<void> _fromHost(String method, Object? arguments) async {
  await _messenger.handlePlatformMessage(
    PromoHostLink.channelName,
    _codec.encodeMethodCall(MethodCall(method, arguments)),
    (_) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PromoHostLink', () {
    late List<bool> visibility;
    late List<(double, double)> scrolls;
    late PromoHostLink link;

    setUp(() {
      visibility = [];
      scrolls = [];
      link = PromoHostLink(
        onVisibility: visibility.add,
        onScroll: (progress, velocity) => scrolls.add((progress, velocity)),
      )..attach();
    });

    tearDown(() {
      link.detach();
      _messenger.setMockMethodCallHandler(_channel, null);
    });

    test('passes host visibility on', () async {
      await _fromHost('visibility', {'visible': false});

      expect(visibility, [false]);
    });

    test('passes host scroll progress and velocity on', () async {
      await _fromHost('scroll', {'progress': 0.25, 'velocity': -1200});

      expect(scrolls, [(0.25, -1200.0)]);
    });

    test('ready pulls the host state', () async {
      _messenger.setMockMethodCallHandler(_channel, (call) async {
        expect(call.method, 'ready');
        return {'visible': false, 'progress': 0.4};
      });

      final state = await link.ready();

      expect(state?.visible, isFalse);
      expect(state?.progress, 0.4);
    });

    test('ready is null when running without a host', () async {
      expect(await link.ready(), isNull);
    });

    test('claim tells the host the code', () async {
      MethodCall? received;
      _messenger.setMockMethodCallHandler(_channel, (call) async {
        received = call;
        return null;
      });

      await link.claim('HOLO20');

      expect(received?.method, 'claimPromo');
      expect(received?.arguments, {'code': 'HOLO20'});
    });

    test('claim without a host is harmless', () async {
      await expectLater(link.claim('HOLO20'), completes);
    });

    test('reports badge bounds as x, y, w, h, throttled', () async {
      final sent = <Object?>[];
      _messenger.setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'badgeBounds') sent.add(call.arguments);
        return null;
      });

      link.reportBadgeBounds(_box(10, 20), 0);
      link.reportBadgeBounds(_box(11, 20), 0.1);
      await pumpEventQueue();

      expect(sent, [
        {'x': 10.0, 'y': 20.0, 'w': 100.0, 'h': 60.0},
      ]);
    });
  });

  group('BoundsThrottle', () {
    test('sends the first bounds', () {
      expect(BoundsThrottle().shouldSend(_box(0, 0), 0), isTrue);
    });

    test('skips bounds that barely moved', () {
      final throttle = BoundsThrottle(minMove: 4)..shouldSend(_box(0, 0), 0);

      expect(throttle.shouldSend(_box(3, 0), 1), isFalse);
    });

    test('skips bounds that arrive too soon, however far they moved', () {
      final throttle = BoundsThrottle(minInterval: 1 / 30)
        ..shouldSend(_box(0, 0), 0);

      expect(throttle.shouldSend(_box(50, 0), 0.01), isFalse);
    });

    test('sends once the badge moved far enough and enough time passed', () {
      final throttle = BoundsThrottle(minMove: 4, minInterval: 1 / 30)
        ..shouldSend(_box(0, 0), 0);

      expect(throttle.shouldSend(_box(0, 0, 105), 0.05), isTrue);
    });

    test('measures movement from the last bounds it sent', () {
      final throttle = BoundsThrottle(minMove: 4)..shouldSend(_box(0, 0), 0);

      throttle.shouldSend(_box(3, 0), 1);

      expect(throttle.shouldSend(_box(5, 0), 2), isTrue);
    });
  });
}
