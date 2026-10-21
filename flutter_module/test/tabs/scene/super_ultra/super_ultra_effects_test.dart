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
      final scales = SuperUltraRenderScale.values
          .where((scale) => !scale.adaptive)
          .map((scale) => scale.scale)
          .toList();
      expect(scales.first, 1.0);
      for (var i = 1; i < scales.length; i++) {
        expect(scales[i], lessThan(scales[i - 1]));
        expect(scales[i], greaterThan(0.0));
      }
    });
  });
  test('Auto render scale is adaptive and starts from full resolution', () {
    expect(SuperUltraRenderScale.auto.adaptive, isTrue);
    expect(SuperUltraRenderScale.auto.scale, 1.0);
    expect(SuperUltraRenderScale.values.where((s) => s.adaptive), [
      SuperUltraRenderScale.auto,
    ]);
    expect(SuperUltraRenderScale.initial, SuperUltraRenderScale.percent85);
  });

  test('frame cap and scene copies default to the engine behaviour', () {
    expect(SuperUltraFrameCap.initial.fps, isNull);
    expect(SuperUltraSceneCopies.initial.batches, isNull);
    expect(SuperUltraFrameCap.fps60.fps, 60);
    expect(SuperUltraSceneCopies.shared.batches, 1);
  });

  test('the firepit stones compare custom indirect against the engine', () {
    // On (the default, like every effect) is the custom indirect; off puts
    // the engine's image-based light back.
    expect(SuperUltraEffect.stoneIndirect.group, SuperUltraEffectGroup.lighting);
    expect(SuperUltraEffect.stoneIndirect.label, contains('firepit'));
  });

  test('grass thinning by quality tier has a full-density comparison', () {
    expect(SuperUltraEffect.grassThinning.group, SuperUltraEffectGroup.scene);
    expect(SuperUltraEffect.grassThinning.cost, contains('75%'));
  });

  test('the lightning ripple is a post effect, on by default like the rest', () {
    expect(SuperUltraEffect.lightningRipple.group, SuperUltraEffectGroup.post);
    expect(SuperUltraEffect.lightningRipple.label, contains('ripple'));
  });

  test('the wind (flag and swaying trees) is scene content, on by default', () {
    expect(SuperUltraEffect.wind.group, SuperUltraEffectGroup.scene);
    expect(SuperUltraEffect.wind.cost, contains('flag'));
  });

  test('GPU pacing picks are 1 and 2 frames in flight, 1 by default', () {
    expect(SuperUltraGpuPacing.values.map((p) => p.frames), [1, 2]);
    expect(SuperUltraGpuPacing.initial, SuperUltraGpuPacing.one);
  });

  test('ground decals (scorch and footprints) are scene content, on by default', () {
    expect(SuperUltraEffect.decals.group, SuperUltraEffectGroup.scene);
    expect(SuperUltraEffect.decals.cost, contains('scorch'));
  });

  test('depth of field and auto-exposure are post effects, on by default', () {
    expect(SuperUltraEffect.depthOfField.group, SuperUltraEffectGroup.post);
    expect(SuperUltraEffect.depthOfField.cost, contains('Bokeh'));
    expect(SuperUltraEffect.autoExposure.group, SuperUltraEffectGroup.post);
    expect(SuperUltraEffect.autoExposure.cost, contains('adaptation'));
  });

  test('nocturnal fireflies are scene content, on by default', () {
    expect(SuperUltraEffect.fireflies.group, SuperUltraEffectGroup.scene);
    expect(SuperUltraEffect.fireflies.cost, contains('fireflies'));
  });
}