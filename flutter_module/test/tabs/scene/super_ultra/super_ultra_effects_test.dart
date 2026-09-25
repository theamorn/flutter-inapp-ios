import 'package:flutter_module/tabs/scene/super_ultra/super_ultra_effects.dart';
import 'package:flutter_scene/scene.dart' show AntiAliasingMode;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SuperUltraAntiAliasing', () {
    test('defaults to SMAA, not MSAA', () {
      // MSAA with the sea's scene-colour read splits the scene pass and
      // round-trips the 4x depth buffer through memory every frame.
      expect(SuperUltraAntiAliasing.initial.mode, AntiAliasingMode.smaa);
    });

    test('offers every concrete mode once, and never auto', () {
      final modes = SuperUltraAntiAliasing.values.map((aa) => aa.mode);
      expect(modes.toSet(), hasLength(SuperUltraAntiAliasing.values.length));
      expect(modes, isNot(contains(AntiAliasingMode.auto)));
    });
  });

  group('SuperUltraRenderScale', () {
    test('defaults to 85%', () {
      expect(SuperUltraRenderScale.initial.scale, 0.85);
    });

    test('runs from full resolution down, never above it', () {
      final scales =
          SuperUltraRenderScale.values.map((scale) => scale.scale).toList();
      expect(scales.first, 1.0);
      for (var i = 1; i < scales.length; i++) {
        expect(scales[i], lessThan(scales[i - 1]));
        expect(scales[i], greaterThan(0.0));
      }
    });
  });
}
