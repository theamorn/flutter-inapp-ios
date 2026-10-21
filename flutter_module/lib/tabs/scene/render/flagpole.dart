import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import 'wind.dart';

/// The flag material, compiled by the build hook.
const String kFlagFmat = 'assets/materials/flag.fmat';

/// A flagpole whose flag flies in the shared wind ([Wind]): a metal pole
/// with a ball on top, and `flag.fmat` (the Thai flag) on a flat grid hung
/// from the top.
class Flagpole {
  Flagpole._(this.root, this._material);

  /// The pole's root: its base sits at the root's origin.
  final Node root;
  final PreprocessedMaterial _material;

  static Future<Flagpole> build({
    required String name,
    double poleHeight = 4.5,
    double flagLength = 1.5,
  }) async {
    // The Thai flag's 2:3 proportions.
    final flagHeight = flagLength * 2 / 3;
    final material = await loadFmatMaterial(kFlagFmat);
    material.parameters.setVec4('flag', Vector4(flagLength, 0, 0, 0));

    final metal = PhysicallyBasedMaterial()
      ..baseColorFactor = Vector4(0.78, 0.78, 0.8, 1)
      ..metallicFactor = 1
      ..roughnessFactor = 0.35;
    final root = Node(name: name)
      ..add(Node(
        name: '${name}_pole',
        mesh: Mesh(
          CylinderGeometry(bottomRadius: 0.05, topRadius: 0.035, height: poleHeight, radialSegments: 10),
          metal,
        ),
      )..position = Vector3(0, poleHeight / 2, 0))
      ..add(Node(
        name: '${name}_ball',
        mesh: Mesh(SphereGeometry(radius: 0.07), metal),
      )..position = Vector3(0, poleHeight + 0.04, 0))
      ..add(Node(
        name: '${name}_flag',
        mesh: Mesh(flagGrid(length: flagLength, height: flagHeight), material),
      )
        ..position = Vector3(0, poleHeight - 0.06, 0)
        // The vertex stage turns and waves the flag far from the flat grid's
        // bounds, so the bounds would cull it wrongly.
        ..frustumCulled = false);
    return Flagpole._(root, material);
  }

  /// Flies the flag in [wind].
  void apply(Wind wind) => _material.parameters.setVec4('wind', wind.shaderParams);

  /// A flat cloth grid in the XY plane: x from 0 (the pole) to [length], y
  /// from 0 (top edge) down to -[height]; uv (0, 0) at the top of the hoist.
  static MeshGeometry flagGrid({
    required double length,
    required double height,
    int columns = 24,
    int rows = 10,
  }) {
    final builder = GeometryBuilder()..normal(Vector3(0, 0, 1));
    final index = <int>[];
    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= columns; c++) {
        final u = c / columns, v = r / rows;
        builder.texCoord(Vector2(u, v));
        index.add(builder.addVertex(Vector3(u * length, -v * height, 0)));
      }
    }
    int at(int r, int c) => index[r * (columns + 1) + c];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < columns; c++) {
        builder
          ..addTriangle(at(r, c), at(r + 1, c), at(r + 1, c + 1))
          ..addTriangle(at(r, c), at(r + 1, c + 1), at(r, c + 1));
      }
    }
    return builder.build();
  }
}
