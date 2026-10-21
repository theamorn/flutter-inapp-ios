import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The samplers flutter_scene binds, by name, for every full-tier lit material.
const Set<String> _engineFullLitSamplers = {
  'brdf_lut',
  'irradiance_field',
  'prefiltered_radiance',
  'prefiltered_radiance_b',
  'punctual_index',
  'punctual_lights',
  'shadow_map',
  'ssao_texture',
};

/// The samplers flutter_scene 0.24.3 binds for every lean-tier lit material
/// (`*_lean` entry points).
const Set<String> _engineLeanLitSamplers = {
  'brdf_lut',
  'prefiltered_radiance',
  'punctual_index',
  'punctual_lights',
  'shadow_map',
};

/// Each Metal fragment entry point in [msl] and the textures it declares.
Map<String, Set<String>> _fragmentTextures(String msl) {
  final entries = RegExp(
    r'fragment\s+\w+\s+(\w+)\s*\((.*?)\)\s*\{',
    dotAll: true,
  );
  final texture = RegExp(r'(\w+)\s*\[\[texture\(\d+\)\]\]');
  return {
    for (final m in entries.allMatches(msl))
      m.group(1)!: {
        for (final t in texture.allMatches(m.group(2)!)) t.group(1)!,
      },
  };
}

void main() {
  // A hook that stops reading an engine input (an Ambient() that overwrites
  // the irradiance, say) lets the compiler strip that sampler from the Metal
  // shader. flutter_scene 0.24 still binds it by name, Metal gets slot -1,
  // and Apple GPUs crash in setFragmentTexture (the simulator and Vulkan
  // shrug it off). Every lit .fmat must keep all of its tier's samplers.
  test('every lit .fmat keeps the engine samplers in its Metal shaders', () {
    final bundles = [
      for (final dir in ['metal_ios', 'metal_desktop'])
        if (Directory('flutter_scene_generated/$dir').existsSync())
          ...Directory('flutter_scene_generated/$dir')
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.shaderbundle')),
    ];
    expect(
      bundles,
      isNotEmpty,
      reason: 'no generated Metal shader bundles; build the app once first',
    );

    final problems = <String>[];
    var litShaders = 0;
    for (final bundle in bundles) {
      final msl = latin1.decode(bundle.readAsBytesSync());
      _fragmentTextures(msl).forEach((name, textures) {
        final engine = textures.intersection(_engineFullLitSamplers);
        if (engine.isEmpty) return;
        litShaders++;
        final expected = name.contains('_lean')
            ? _engineLeanLitSamplers
            : _engineFullLitSamplers;
        final missing = expected.difference(engine);
        if (missing.isNotEmpty) {
          problems.add(
            '$name (${bundle.uri.pathSegments.last}) '
            'lost ${missing.toList()..sort()}',
          );
        }
      });
    }
    expect(litShaders, greaterThan(0), reason: 'found no lit fragment shaders');
    expect(problems, isEmpty);
  });
}
