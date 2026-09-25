import 'package:flutter_module/tabs/promo/scroll_push.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feeds a velocity curve sampled at 120 Hz, like a ProMotion scroll callback.
void _feed(
  ScrollPush push,
  double Function(double t) velocity, {
  double from = 0,
  double to = 0.1,
}) {
  for (var t = from; t <= to + 1e-9; t += 1 / 120) {
    push.addSample(velocity(t), t);
  }
}

void main() {
  group('ScrollPush', () {
    test('is zero before any samples', () {
      expect(ScrollPush().accelerationAt(0), 0);
    });

    test('reports how fast the scroll velocity is changing', () {
      final push = ScrollPush();

      _feed(push, (t) => 1000 * t);

      expect(push.accelerationAt(0.1), closeTo(1000, 10));
    });

    test('a scroll that is slowing down pushes the other way', () {
      final push = ScrollPush();

      _feed(push, (t) => 2000 - 1500 * t);

      expect(push.accelerationAt(0.1), closeTo(-1500, 15));
    });

    test('clamps a violent flick to the maximum', () {
      final push = ScrollPush(maxAcceleration: 6000);

      var peak = 0.0;
      for (var t = 0.0; t <= 0.1; t += 1 / 120) {
        push.addSample(100000 * t, t);
        if (push.accelerationAt(t) > peak) peak = push.accelerationAt(t);
      }

      expect(peak, lessThanOrEqualTo(6000));
      expect(push.accelerationAt(0.1), closeTo(6000, 10));
    });

    test('fades to zero once the samples stop', () {
      final push = ScrollPush(holdSeconds: 0.08);
      _feed(push, (t) => 1000 * t);

      expect(push.accelerationAt(0.1 + 0.05), isNot(0));
      expect(push.accelerationAt(0.1 + 0.2), 0);
    });

    test('ignores a sample too close to the previous one to difference', () {
      final push = ScrollPush();
      _feed(push, (t) => 1000 * t);

      // A host that reports twice in one frame: 1ms apart, same speed.
      push.addSample(1000 * 0.1, 0.101);

      expect(push.accelerationAt(0.101), closeTo(1000, 10));
    });

    test('treats a sample after a long pause as a fresh start', () {
      final push = ScrollPush();

      push.addSample(0, 0);
      push.addSample(3000, 0.5);

      expect(push.accelerationAt(0.5), 0);
    });
  });
}
