import 'package:flutter_module/tabs/scene/campfire_shadows.dart';
import 'package:flutter_module/tabs/scene/super_ultra/super_ultra_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Normal never casts; Ultra and above cast unless switched off', () {
    expect(campfireCastsShadow(ultraOrAbove: false, effectOn: true), isFalse);
    expect(campfireCastsShadow(ultraOrAbove: true, effectOn: true), isTrue);
    expect(campfireCastsShadow(ultraOrAbove: true, effectOn: false), isFalse);
  });

  test('gives the shadow atlas to the god rays while they draw', () {
    expect(
      campfireCastsShadow(ultraOrAbove: true, effectOn: true, godRaysOn: true),
      isFalse,
    );
  });

  test('fire shadows is a lighting effect in the menu', () {
    expect(SuperUltraEffect.fireShadows.group, SuperUltraEffectGroup.lighting);
  });
}
