import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// The Nimbus One headphones, built in code rather than loaded from a file.
///
/// Every part is a smooth surface of revolution or a swept tube, so curved
/// metal reflects the park as a continuous image instead of breaking into
/// facets. Units are scene units; the whole set is about 1.65 wide and
/// 1.58 tall, centred on the origin. Y is up, the cups sit on ±X, and the
/// front of the headband faces -Z.
///
/// Midnight colourway: satin-silver headband, midnight anodized cups,
/// spun-metal cap plates, polished chrome rings and sliders, and leather
/// cushions.
Future<Node> buildNimbusHeadphones() async {
  final m = await _NimbusMaterials.load();
  final root = Node(name: 'nimbus_one');
  // The parts below are laid out with the band's arc centre at y = 0.12 and
  // the cups at y = -0.42; shift so the bounding box centres on the origin.
  final body = Node(
    name: 'nimbus_body',
    localTransform: _pose(vm.Vector3(0, -0.065, 0)),
  );
  root.add(body);

  body
    ..add(_headband(m))
    ..add(_cup(m, side: 1))
    ..add(_cup(m, side: -1));
  return root;
}

// Layout, in the body node's space.
const double _bandCenterY = 0.12;
const double _bandRadius = 0.71;
const double _cupX = 0.62;
const double _cupY = -0.42;
const double _yokeRadius = 0.345;
const double _yokeOffset = 0.09; // along the cup axis, outward

/// The metal shader: see `assets/materials/nimbus_metal.fmat` for why the
/// metals do not use [PhysicallyBasedMaterial].
const String kNimbusMetalFmat = 'assets/materials/nimbus_metal.fmat';

class _NimbusMaterials {
  _NimbusMaterials._(this.band, this.cup, this.plate, this.chrome);

  static Future<_NimbusMaterials> load() async {
    // The park, pre-blurred at three sizes (tool/bake_park_reflections.py).
    // One mip each, no mipmaps: the test phone samples only base mips.
    Future<Texture2D> level(int index, int width) async {
      final bytes = await rootBundle.load(
        'assets/environments/park_reflection_$index.rgbm',
      );
      return Texture2D.fromPixels(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        width,
        width ~/ 2,
        content: TextureContent.data,
        sampling: const TextureSampling(mipmaps: false),
      );
    }

    final reflections = [
      await level(0, 512),
      await level(1, 128),
      await level(2, 32),
    ];

    Future<Material> metal(
      vm.Vector4 color,
      double roughness, {
      double coat = 0,
      double coatRoughness = 0.08,
    }) async {
      final m = await loadFmatMaterial(kNimbusMetalFmat);
      m.parameters
        ..setVec4('base_color', color)
        ..setVec4('surface', vm.Vector4(roughness, coat, coatRoughness, 0));
      for (final (i, name) in const [
        'reflection_sharp',
        'reflection_soft',
        'reflection_blurred',
      ].indexed) {
        m.parameters.setTexture(
          name,
          reflections[i].gpuTexture,
          sampler: reflections[i].sampledSampler,
        );
      }
      return m;
    }

    return _NimbusMaterials._(
      // Satin aluminium.
      await metal(vm.Vector4(0.91, 0.92, 0.94, 1), 0.22),
      // Midnight anodized aluminium under a clear lacquer: dark, but its
      // lacquer mirrors the park.
      await metal(vm.Vector4(0.10, 0.12, 0.20, 1), 0.30, coat: 0.8),
      // Spun metal cap plates, a little brighter and smoother than the band.
      await metal(vm.Vector4(0.86, 0.87, 0.90, 1), 0.16),
      // Polished chrome: a near-perfect mirror.
      await metal(vm.Vector4(0.96, 0.96, 0.97, 1), 0.05),
    );
  }

  final Material band, cup, plate, chrome;

  /// Protein leather: near black, with a faint sheen at grazing angles and
  /// a soft gloss.
  final leather = PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(0.012, 0.013, 0.018, 1)
    ..metallicFactor = 0.0
    ..roughnessFactor = 0.45
    ..sheenColor = vm.Vector4(0.05, 0.05, 0.065, 1)
    ..sheenRoughness = 0.35
    ..clearcoat = 0.3
    ..clearcoatRoughness = 0.3;

  /// The acoustic fabric inside the cushion and the cup's inner baffle.
  final fabric = PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(0.02, 0.022, 0.03, 1)
    ..metallicFactor = 0.0
    ..roughnessFactor = 0.95
    ..sheenColor = vm.Vector4(0.05, 0.05, 0.06, 1)
    ..sheenRoughness = 0.7;
}

Node _headband(_NimbusMaterials m) {
  // The band sweeps around the world Z axis. revolve() turns around local Y,
  // and rotating +90° about X maps local Y onto world Z, local (x, z) onto
  // world (x, -y). So a world arc angle φ is the local angle -φ.
  const overshoot = 0.06;
  final band = revolve(
    superellipse(
      center: vm.Vector2(_bandRadius, 0),
      radius: vm.Vector2(0.022, 0.075),
      exponent: 6,
    ),
    closed: true,
    caps: true,
    start: -math.pi - overshoot,
    sweep: math.pi + 2 * overshoot,
    segments: 128,
  );
  const padInset = 0.45;
  final pad = revolve(
    superellipse(
      center: vm.Vector2(0.668, 0),
      radius: vm.Vector2(0.026, 0.06),
      exponent: 3,
    ),
    closed: true,
    caps: true,
    start: -math.pi + padInset,
    sweep: math.pi - 2 * padInset,
    segments: 96,
  );
  return Node(
      name: 'headband',
      localTransform: _pose(
        vm.Vector3(0, _bandCenterY, 0),
        vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2),
      ),
    )
    ..add(Node(name: 'band', mesh: Mesh(band, m.band)))
    ..add(Node(name: 'band_pad', mesh: Mesh(pad, m.leather)));
}

/// One ear cup with its yoke and sliders. [side] is +1 for the right cup
/// (on +X) and -1 for the left.
Node _cup(_NimbusMaterials m, {required int side}) {
  final group = Node(name: side > 0 ? 'cup_right' : 'cup_left');

  // The cup is built around local +Y (its outward axis), then turned so that
  // axis points along ±X. h = 0 is where the cushion meets the shell.
  final cup = Node(
    name: 'cup_body',
    localTransform: _pose(
      vm.Vector3(side * _cupX, _cupY, 0),
      vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), -side * math.pi / 2),
    ),
  );
  group.add(cup);

  // Shell: the outer quadrant of a rounded dome, from the cushion seam up
  // to the cap plate.
  const shellRadius = 0.30, shellDepth = 0.20, shellExponent = 3.5;
  const plateRadius = 0.236;
  final plateT = math.acos(
    math.pow(plateRadius / shellRadius, shellExponent / 2).toDouble(),
  );
  final plateH =
      shellDepth * math.pow(math.sin(plateT), 2 / shellExponent).toDouble();
  final shell = <vm.Vector2>[
    for (var i = 0; i <= 40; i++)
      _superellipsePoint(
        vm.Vector2.zero(),
        vm.Vector2(shellRadius, shellDepth),
        shellExponent,
        plateT * i / 40,
      ),
  ];
  cup.add(Node(name: 'shell', mesh: Mesh(revolve(shell), m.cup)));

  // Cap plate: a shallow dome inside a chrome ring.
  final plate = <vm.Vector2>[
    for (var i = 0; i <= 24; i++)
      () {
        final r = plateRadius * (1 - i / 24);
        final f = r / plateRadius;
        return vm.Vector2(r, plateH - 0.002 + 0.014 * (1 - f * f));
      }(),
  ];
  cup
    ..add(
      Node(
        name: 'cap_plate',
        mesh: Mesh(revolve(plate, segments: 128), m.plate),
      ),
    )
    ..add(
      Node(
        name: 'cap_ring',
        localTransform: _pose(vm.Vector3(0, plateH, 0)),
        mesh: Mesh(
          TorusGeometry(
            radius: 0.238,
            tubeRadius: 0.009,
            radialSegments: 128,
            tubularSegments: 16,
          ),
          m.chrome,
        ),
      ),
    );

  // Cushion: a soft pillow ring on the head side (h < 0).
  cup.add(
    Node(
      name: 'cushion',
      mesh: Mesh(
        revolve(
          superellipse(
            center: vm.Vector2(0.215, -0.048),
            radius: vm.Vector2(0.09, 0.052),
            exponent: 3,
          ),
          closed: true,
        ),
        m.leather,
      ),
    ),
  );
  // Fabric inside the cushion, and a baffle that closes the shell so no
  // angle looks into an empty cup.
  cup
    ..add(
      Node(
        name: 'driver_cloth',
        mesh: Mesh(
          revolve([vm.Vector2(0, -0.03), vm.Vector2(0.16, -0.03)]),
          m.fabric,
        ),
      ),
    )
    ..add(
      Node(
        name: 'baffle',
        mesh: Mesh(
          revolve([vm.Vector2(0, 0.004), vm.Vector2(0.30, 0.004)]),
          m.fabric,
        ),
      ),
    );

  // Yoke: a polished arc over the cup, from its front pivot to its back one.
  final yokeX = side * (_cupX + _yokeOffset);
  final yoke = TubeGeometry(
    PolylinePath([
      for (var i = 0; i <= 64; i++)
        vm.Vector3(
          yokeX,
          _cupY + _yokeRadius * math.sin(math.pi * i / 64),
          _yokeRadius * math.cos(math.pi * i / 64),
        ),
    ]),
    radius: 0.016,
    radialSegments: 24,
    stations: 96,
  );
  group.add(Node(name: 'yoke', mesh: Mesh(yoke, m.chrome)));
  // Pivot pins from the yoke's ends into the shell.
  for (final z in [1.0, -1.0]) {
    group.add(
      Node(
        name: 'pivot',
        localTransform: _pose(
          vm.Vector3(yokeX, _cupY, z * (_yokeRadius - 0.03)),
          vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2),
        ),
        mesh: Mesh(
          CylinderGeometry(
            bottomRadius: 0.024,
            topRadius: 0.024,
            height: 0.07,
            radialSegments: 32,
          ),
          m.chrome,
        ),
      ),
    );
  }

  // Sliders: two chrome rods from the yoke's crown into the band's end,
  // under a small anodized hinge block.
  final crownY = _cupY + _yokeRadius;
  final bandEndY = _bandCenterY - _bandRadius * math.sin(0.06);
  group.add(
    Node(
      name: 'hinge',
      localTransform: _pose(
        vm.Vector3(yokeX, crownY + 0.01, 0),
        vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2),
      ),
      mesh: Mesh(
        CapsuleGeometry(radius: 0.026, height: 0.075, radialSegments: 32),
        m.cup,
      ),
    ),
  );
  for (final z in [0.032, -0.032]) {
    final length = bandEndY + 0.02 - crownY;
    group.add(
      Node(
        name: 'slider',
        localTransform: _pose(vm.Vector3(yokeX, crownY + length / 2, z)),
        mesh: Mesh(
          CylinderGeometry(
            bottomRadius: 0.011,
            topRadius: 0.011,
            height: length,
            radialSegments: 24,
          ),
          m.chrome,
        ),
      ),
    );
  }
  return group;
}

vm.Matrix4 _pose(vm.Vector3 position, [vm.Quaternion? rotation]) =>
    vm.Matrix4.compose(
      position,
      rotation ?? vm.Quaternion.identity(),
      vm.Vector3.all(1),
    );

/// Points of a superellipse `|x/a|^n + |y/b|^n = 1`, counter-clockwise from
/// angle 0: a rounded rectangle for large [exponent], an ellipse at 2.
List<vm.Vector2> superellipse({
  required vm.Vector2 center,
  required vm.Vector2 radius,
  double exponent = 4,
  int points = 48,
}) => [
  for (var i = 0; i < points; i++)
    _superellipsePoint(center, radius, exponent, 2 * math.pi * i / points),
];

vm.Vector2 _superellipsePoint(vm.Vector2 c, vm.Vector2 r, double n, double t) {
  double f(double v) => v.sign * math.pow(v.abs(), 2 / n).toDouble();
  return vm.Vector2(c.x + r.x * f(math.cos(t)), c.y + r.y * f(math.sin(t)));
}

/// Revolves [profile], a polyline in the (radius, height) plane, around the
/// local Y axis, from angle [start] through [sweep] radians.
///
/// The surface faces the right-hand side of the profile's direction of
/// travel (radius to the right, height up): list a closed outline
/// counter-clockwise and it faces out. [closed] joins the last point back
/// to the first. [caps] closes the two ends of a partial sweep, which needs
/// a closed, convex profile.
///
/// Normals come from the profile, so the surface is smooth around and
/// along it. Tangents run around the axis, the direction anisotropic
/// materials streak along.
MeshGeometry revolve(
  List<vm.Vector2> profile, {
  double start = 0,
  double sweep = 2 * math.pi,
  int segments = 96,
  bool closed = false,
  bool caps = false,
}) {
  final rows = profile.length;
  final positions = <double>[];
  final normals = <double>[];
  final tangents = <double>[];
  final uvs = <double>[];
  final indices = <int>[];

  vm.Vector2 profileNormal(int i) {
    final prev = closed
        ? profile[(i - 1 + rows) % rows]
        : profile[math.max(i - 1, 0)];
    final next = closed
        ? profile[(i + 1) % rows]
        : profile[math.min(i + 1, rows - 1)];
    final t = (next - prev)..normalize();
    return vm.Vector2(t.y, -t.x);
  }

  final columns = segments + 1;
  for (var i = 0; i < rows; i++) {
    final p = profile[i];
    final n = profileNormal(i);
    for (var j = 0; j < columns; j++) {
      final a = start + sweep * j / segments;
      final c = math.cos(a), s = math.sin(a);
      positions.addAll([p.x * c, p.y, p.x * s]);
      normals.addAll([n.x * c, n.y, n.x * s]);
      tangents.addAll([-s, 0, c, 1]);
      uvs.addAll([j / segments, i / (rows - 1)]);
    }
  }
  final bands = closed ? rows : rows - 1;
  for (var i = 0; i < bands; i++) {
    final i1 = (i + 1) % rows;
    for (var j = 0; j < segments; j++) {
      final a = i * columns + j, b = a + 1;
      final c = i1 * columns + j, d = c + 1;
      indices.addAll([a, c, b, b, c, d]);
    }
  }

  if (caps) {
    final centroid = vm.Vector2.zero();
    for (final p in profile) {
      centroid.add(p);
    }
    centroid.scale(1 / rows);
    for (final end in [0, 1]) {
      final a = start + sweep * end;
      final c = math.cos(a), s = math.sin(a);
      // The start cap faces back along the sweep, the end cap forward.
      final facing = vm.Vector3(-s, 0, c)..scale(end == 0 ? -1.0 : 1.0);
      vm.Vector3 at(vm.Vector2 p) => vm.Vector3(p.x * c, p.y, p.x * s);
      final base = positions.length ~/ 3;
      for (final p in [centroid, ...profile]) {
        final v = at(p);
        positions.addAll([v.x, v.y, v.z]);
        normals.addAll([facing.x, facing.y, facing.z]);
        tangents.addAll([c, 0, s, 1]);
        uvs.addAll([0.5, 0.5]);
      }
      for (var k = 0; k < rows; k++) {
        final p0 = at(profile[k]), p1 = at(profile[(k + 1) % rows]);
        final winding = (p0 - at(centroid))
            .cross(p1 - at(centroid))
            .dot(facing);
        final v0 = base + 1 + k, v1 = base + 1 + (k + 1) % rows;
        indices.addAll(winding >= 0 ? [base, v0, v1] : [base, v1, v0]);
      }
    }
  }

  return MeshGeometry.fromArrays(
    positions: Float32List.fromList(positions),
    normals: Float32List.fromList(normals),
    tangents: Float32List.fromList(tangents),
    texCoords: Float32List.fromList(uvs),
    indices: indices,
  );
}
