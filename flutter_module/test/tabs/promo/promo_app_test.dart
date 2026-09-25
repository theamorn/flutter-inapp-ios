import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter_module/tabs/promo/holo_card_game.dart';
import 'package:flutter_module/tabs/promo/promo_app.dart';
import 'package:flutter_module/tabs/promo/promo_host_link.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel(PromoHostLink.channelName);
const _codec = StandardMethodCodec();

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

Future<void> _fromHost(String method, Object? arguments) async {
  await _messenger.handlePlatformMessage(
    PromoHostLink.channelName,
    _codec.encodeMethodCall(MethodCall(method, arguments)),
    (_) {},
  );
}

Future<HoloCardGame> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 340);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const HoloPromoApp());
  // Let the game load its shader and lay out, then run a few frames.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final widget = tester.widget<GameWidget<HoloCardGame>>(
    find.byType(GameWidget<HoloCardGame>),
  );
  return widget.game!;
}

void main() {
  tearDown(() => _messenger.setMockMethodCallHandler(_channel, null));

  testWidgets('host visibility pauses and resumes the badge', (tester) async {
    final game = await _pumpApp(tester);
    expect(game.paused, isFalse);

    await _fromHost('visibility', {'visible': false});
    expect(game.paused, isTrue);

    await _fromHost('visibility', {'visible': true});
    expect(game.paused, isFalse);
  });

  testWidgets('tapping the badge claims the promo with the host', (
    tester,
  ) async {
    final claims = <Object?>[];
    _messenger.setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'claimPromo') claims.add(call.arguments);
      return null;
    });
    final game = await _pumpApp(tester);

    final center = game.physics.pose.center;
    await tester.tapAt(Offset(center.x, center.y));
    // Past the gesture arena's tap and double-tap timeouts.
    await tester.pump(const Duration(milliseconds: 500));

    expect(claims, [
      {'code': 'HOLO20'},
    ]);
    expect(game.claimed, isTrue);
  });

  testWidgets('dragging the badge moves it', (tester) async {
    final game = await _pumpApp(tester);
    final start = game.physics.pose.center.clone();

    final gesture = await tester.startGesture(Offset(start.x, start.y));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));

    expect(game.physics.pose.center.x, greaterThan(start.x + 20));
  });
}
