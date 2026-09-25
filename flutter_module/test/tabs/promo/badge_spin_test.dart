import 'dart:math' as math;

import 'package:flutter_module/tabs/promo/badge_spin.dart';
import 'package:flutter_test/flutter_test.dart';

void _run(BadgeSpin spin, double seconds, {void Function()? eachFrame}) {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    spin.step(1 / 60);
    eachFrame?.call();
  }
}

void main() {
  group('BadgeSpin', () {
    test('rests facing front', () {
      final spin = BadgeSpin();

      _run(spin, 1);

      expect(spin.yaw, 0);
      expect(spin.isBackFacing, isFalse);
    });

    test('a sideways flick spins the badge around to its back', () {
      final spin = BadgeSpin();
      var sawBack = false;
      var turned = 0.0;

      spin.flick(30);
      _run(
        spin,
        3,
        eachFrame: () {
          sawBack |= spin.isBackFacing;
          turned = math.max(turned, spin.yaw.abs());
        },
      );

      expect(sawBack, isTrue);
      expect(turned, greaterThan(2 * math.pi));
    });

    test('the strap twist unwinds it back to the front', () {
      final spin = BadgeSpin();

      spin.flick(30);
      _run(spin, 12);

      expect(spin.yaw, closeTo(0, 0.05));
      expect(spin.isBackFacing, isFalse);
    });

    test('flip turns the badge over and keeps it on its back', () {
      final spin = BadgeSpin();

      spin.flip();
      _run(spin, 6);

      expect(spin.showsBack, isTrue);
      expect(spin.yaw, closeTo(math.pi, 0.05));
      expect(spin.isBackFacing, isTrue);
    });

    test('flipping again returns it to the front', () {
      final spin = BadgeSpin();

      spin.flip();
      _run(spin, 6);
      spin.flip();
      _run(spin, 6);

      expect(spin.showsBack, isFalse);
      expect(spin.isBackFacing, isFalse);
    });

    test('caps how fast a flick can spin it', () {
      final spin = BadgeSpin(maxSpeed: 40);

      spin.flick(1000);

      expect(spin.speed, 40);
    });

    test('survives a huge frame without NaN', () {
      final spin = BadgeSpin();

      spin.flick(40);
      spin.step(0.5);

      expect(spin.yaw.isFinite, isTrue);
      expect(spin.speed.isFinite, isTrue);
    });
  });
}
