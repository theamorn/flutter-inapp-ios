import 'dart:io';

import 'package:flutter_module/tabs/scene/super_ultra/stone_lighting.dart';
// The engine's own .fmat compiler (pure Dart, no GPU).
// ignore: implementation_imports
import 'package:flutter_scene/src/fmat/fmat.dart';
// ignore: implementation_imports
import 'package:flutter_scene/src/fmat/fmat_emitter.dart' show lightingHooksIn;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

const _stone = 'assets/materials/campfire_stone.fmat';

FmatCompilation _compile(String path) =>
    compileFmat(File(path).readAsStringSync(), fileName: path);

String _body(String path) => _compile(path).material.fragmentSource;

Map<String, FmatType> _params(FmatCompilation c) =>
    {for (final p in c.material.parameters) p.name: p.type};

double _luma(Vector3 c) => c.dot(Vector3(0.2126, 0.7152, 0.0722));

void main() {
  group('additive_glow.fmat', () {
    final c = _compile('assets/materials/additive_glow.fmat');

    test('adds light without writing depth', () {
      expect(c.material.blending, FmatBlending.additive);
      expect(c.material.depthWrite, isFalse);
      expect(c.material.shadingModel, FmatShadingModel.unlit);
    });

    test('faces the camera and fades where it meets real geometry', () {
      expect(c.material.vertexSource, contains('camera_position'));
      expect(c.material.engineInputs, contains('scene_depth'));
      expect(_params(c)['glow'], FmatType.vec4);
    });

    test('keeps highp and compiles', () {
      expect(c.material.fragmentSource, contains('precision highp float;'));
      expect(c.glsl, isNotEmpty);
      expect(c.vertexGlsl, isNotEmpty);
    });
  });

  group('retired 0.23 workarounds', () {
    test('heat haze is unlit with a bounded scene-color reach and uses vertex.model_transform', () {
      final c = _compile('assets/materials/heat_haze.fmat');
      expect(c.material.shadingModel, FmatShadingModel.unlit);
      expect(c.material.sceneColorReach, isNotNull);
      expect(
        File('assets/materials/heat_haze.fmat').readAsStringSync(),
        contains('vertex.model_transform'),
      );
      expect(c.glsl, isNotEmpty);
    });

    test('decal_ground compiles with the decal contract', () {
      final c = _compile('assets/materials/decal_ground.fmat');
      expect(c.material.engineInputs, ['scene_depth']);
      expect(c.sidecar.toString(), contains('decal_inverse'));
    });
  });

  group('campfire_stone.fmat & stoneLightingFor', () {
    test('supplies its own indirect light through Light, Ambient and Composite', () {
      final c = _compile(_stone);
      expect(c.material.shadingModel, FmatShadingModel.lit);
      expect(
        lightingHooksIn(c.material.fragmentSource),
        {'Light', 'Ambient', 'Composite'},
      );
      final params = _params(c);
      expect(params['sky_upper'], FmatType.vec4);
      expect(params['sky_lower'], FmatType.vec4);
    });

    test('replaces the engine image-based light instead of scaling it', () {
      final c = _compile(_stone);
      expect(c.material.environmentLighting, isTrue);
      final body = c.material.fragmentSource;
      expect(body, contains('ambient.irradiance = '));
      expect(body, contains('ambient.radiance = '));
      expect(body, isNot(contains('ambient.irradiance *=')));
    });

    test('adds procedural stone grain, base stain, rain slickness and ember bounce', () {
      final body = _body(_stone);
      expect(body, contains('StoneGrain'));
      expect(body, contains('base_stain'));
      expect(body, contains('ember_bounce'));
    });

    test('keeps highp, never double-attenuates, and premultiplies alpha once in Composite', () {
      final body = _body(_stone);
      expect(body, contains('precision highp float;'));
      expect(
        body,
        contains('LightTerms Light(MaterialInputs material, LightContext light)'),
      );
      expect(
        body,
        contains('highp vec4 Composite(MaterialInputs material, LightingResult result)'),
      );
      for (final term in [
        'light.shadow',
        'light.distance_attenuation',
        'light.cone_attenuation',
      ]) {
        expect(body, isNot(contains(term)), reason: term);
      }
      expect(RegExp(r'result\.alpha').allMatches(body), hasLength(1));
    });

    test('stoneLightingFor obeys ambient, day/night, and storm invariants', () {
      final zero = stoneLightingFor(ambient: 0, night: 0, weather: 0);
      expect(zero.upper.length, 0);
      expect(zero.lower.length, 0);

      final day = stoneLightingFor(ambient: 0.8, night: 0, weather: 0);
      final night = stoneLightingFor(ambient: 0.8, night: 1, weather: 0);
      expect(_luma(day.upper), greaterThan(_luma(night.upper)));
      expect(_luma(day.lower), lessThan(_luma(day.upper)));
      expect(StoneIndirectMode.initial, StoneIndirectMode.custom);
    });
  });

  group('wind materials (flag.fmat & foliage_sway.fmat)', () {
    test('flag.fmat is two-sided lit cloth pinned at the pole with Thai flag colours', () {
      final c = _compile('assets/materials/flag.fmat');
      expect(c.material.shadingModel, FmatShadingModel.lit);
      expect(c.material.culling, FmatCulling.none);
      expect(_params(c)['wind'], FmatType.vec4);
      expect(c.material.vertexSource, contains('material_params.wind'));
      expect(c.material.vertexSource, contains('vertex.world_normal = '));
      expect(c.material.fragmentSource, contains('precision highp float;'));
    });

    test('foliage_sway.fmat bends with height in the wind and keeps the imported colour', () {
      final c = _compile('assets/materials/foliage_sway.fmat');
      expect(c.material.shadingModel, FmatShadingModel.lit);
      expect(_params(c)['wind'], FmatType.vec4);
      expect(_params(c)['sway'], FmatType.vec4);
      expect(_params(c)['base_color'], FmatType.vec4);
      expect(c.material.vertexSource, contains('vertex.model_transform'));
      expect(c.material.fragmentSource, contains('precision highp float;'));
      expect(c.material.fragmentSource, contains('forward_scatter'));
    });
  });
}
