/// Per-node [Component]s for the island scene. Engine-ticked; keep game-wide
/// simulation (walker, physics) in [IslandScene.tick].
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_module/tabs/scene/ball_physics.dart';
import 'package:flutter_module/tabs/scene/tap_to_move.dart';
import 'package:flutter_scene/kit.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Flickers the campfire light, emissive sphere, and particle emitters.
///
/// In Super Ultra the visible fire belongs to `SuperUltraFire`, which reads
/// [intensity]; this component then only drives the light and hides its own
/// sphere and emitters.
class CampfireFlickerComponent extends Component {
  CampfireFlickerComponent({
    required this.light,
    required this.flameNode,
    required this.flameMaterial,
    required this.isLit,
    required this.isUltra,
    required this.isSuperUltra,
    this.flameEmitter,
    this.flameEmitterNode,
    this.smokeEmitter,
    this.smokeEmitterNode,
    this.sparkEmitter,
    this.sparkEmitterNode,
  });

  final PointLight light;
  final Node flameNode;
  final PhysicallyBasedMaterial flameMaterial;
  final bool Function() isLit;
  final bool Function() isUltra;
  final bool Function() isSuperUltra;
  final ParticleEmitterComponent? flameEmitter;
  final Node? flameEmitterNode;
  final ParticleEmitterComponent? smokeEmitter;
  final Node? smokeEmitterNode;
  final ParticleEmitterComponent? sparkEmitter;
  final Node? sparkEmitterNode;

  double intensity = 1.0;
  double _phase = 0.0;

  @override
  void update(double deltaSeconds) {
    _phase += deltaSeconds;
    final target = isLit() ? 1.0 : 0.0;
    intensity += (target - intensity) * math.min(1.0, deltaSeconds * 6.0);

    if (intensity > 0.01 && isSuperUltra()) {
      // Irregular rather than periodic: incommensurate rates plus a slow
      // swell, so the light breathes like a fire instead of pulsing.
      final flicker = 1.0 +
          0.13 * math.sin(_phase * 11.3) +
          0.08 * math.sin(_phase * 23.7 + 1.3) +
          0.06 * math.sin(_phase * 37.1 + 0.4) +
          0.1 * math.sin(_phase * 1.7);
      light.intensity = 6.0 * intensity * flicker;
      flameNode.visible = false;
      flameEmitter?.paused = true;
      flameEmitterNode?.visible = false;
      smokeEmitter?.paused = true;
      smokeEmitterNode?.visible = false;
      sparkEmitter?.paused = true;
      sparkEmitterNode?.visible = false;
    } else if (intensity > 0.01) {
      final flicker = 1.0 +
          0.20 * math.sin(_phase * 15.0) +
          0.10 * math.cos(_phase * 27.0);
      light.intensity = 5.5 * intensity * flicker;
      final useParticles = isUltra();
      flameNode.visible = !useParticles;
      flameEmitter?.paused = !useParticles;
      flameEmitterNode?.visible = useParticles;
      smokeEmitter?.paused = !useParticles;
      smokeEmitterNode?.visible = useParticles;
      sparkEmitter?.paused = !useParticles;
      sparkEmitterNode?.visible = useParticles;
      if (!useParticles) {
        // Uniform only: non-uniform scale silently breaks lighting on PBR.
        flameNode.scale = vm.Vector3.all(0.22 * intensity * flicker);
        flameMaterial.emissiveStrength = 5.0 * intensity * flicker;
      }
    } else {
      flameNode.visible = false;
      flameEmitter?.paused = true;
      flameEmitterNode?.visible = false;
      smokeEmitter?.paused = true;
      smokeEmitterNode?.visible = false;
      sparkEmitter?.paused = true;
      sparkEmitterNode?.visible = false;
      light.intensity = 0.0;
    }
  }
}

/// NPC wander + kit [Steering], writing the node the component is attached to.
class NpcWanderComponent extends Component {
  NpcWanderComponent({
    required this.motion,
    required this.playerPosition,
    required this.isActive,
    required this.pickTarget,
    required this.walkableRadius,
    required this.campfire,
    required this.campfireAvoidRadius,
    this.idleClip,
    this.walkClip,
  });

  final NpcSteeringMotion motion;
  final vm.Vector3 Function() playerPosition;
  final bool Function() isActive;
  final void Function() pickTarget;
  final double walkableRadius;
  final vm.Vector3 campfire;
  final double campfireAvoidRadius;
  final AnimationClip? idleClip;
  final AnimationClip? walkClip;

  double wanderTimer = 0.0;
  double _walkBlend = 0.0;

  void stopAndHide() {
    motion.stop();
    wanderTimer = 0.0;
    if (isAttached) {
      node.visible = false;
    }
  }

  void activate() {
    if (isAttached) {
      node.visible = true;
    }
    pickTarget();
  }

  @override
  void update(double deltaSeconds) {
    if (!isActive()) {
      return;
    }
    wanderTimer -= deltaSeconds;
    if (!motion.isMoving || wanderTimer <= 0) {
      pickTarget();
    }
    final target = motion.target ?? motion.position;
    var force = Steering.arrive(
      motion.position,
      motion.velocity,
      target,
      slowingRadius: motion.slowingRadius,
      maxSpeed: motion.maxSpeed,
      maxForce: motion.maxForce,
    );
    force += Steering.separation(
      motion.position,
      motion.velocity,
      <vm.Vector3>[playerPosition()],
      desiredDistance: motion.separationDistance,
      maxSpeed: motion.maxSpeed,
      maxForce: motion.maxForce * 0.65,
    );
    motion.integrate(
      force,
      deltaSeconds,
      walkableRadius: walkableRadius,
      campfire: campfire,
      campfireAvoidRadius: campfireAvoidRadius,
    );
    node.position = vm.Vector3(
      motion.position.x,
      motion.position.y,
      motion.position.z,
    );
    node.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), motion.yaw);

    final wanted = motion.isMoving ? 1.0 : 0.0;
    final rate = math.min(1.0, deltaSeconds * 8.0);
    _walkBlend += (wanted - _walkBlend) * rate;
    walkClip?.weight = _walkBlend;
    idleClip?.weight = 1.0 - _walkBlend;
  }
}

/// The seagull flock: moves each bird's node along its [FlockBirdMotion] and
/// keeps its wingbeat going.
///
/// Each bird is its own skinned model (`assets/models/seagull.glb`) playing
/// its flight clip; this only sets where it is and which way it faces, and
/// speeds the wingbeat up while it climbs.
class SeagullFlockComponent extends Component {
  SeagullFlockComponent({
    required this.nodes,
    required this.birds,
    required this.wingbeats,
  }) : _baseRates = <double>[
         for (final clip in wingbeats) clip?.playbackTimeScale ?? 1.0,
       ];

  final List<Node> nodes;
  final List<FlockBirdMotion> birds;

  /// Each bird's flight clip, or null if the model had none.
  final List<AnimationClip?> wingbeats;
  final List<double> _baseRates;

  @override
  void update(double deltaSeconds) {
    if (birds.isEmpty) {
      return;
    }
    final positions = <vm.Vector3>[
      for (final bird in birds) bird.position.clone(),
    ];
    final velocities = <vm.Vector3>[
      for (final bird in birds) bird.velocity.clone(),
    ];
    for (var i = 0; i < birds.length; i++) {
      final bird = birds[i];
      bird.advance(
        deltaSeconds,
        neighborPositions: <vm.Vector3>[
          for (var j = 0; j < positions.length; j++)
            if (j != i) positions[j],
        ],
        neighborVelocities: <vm.Vector3>[
          for (var j = 0; j < velocities.length; j++)
            if (j != i) velocities[j],
        ],
      );
      nodes[i]
        ..position = bird.position
        ..rotation = bird.attitude;
      // Work harder climbing, ease off descending.
      wingbeats[i]?.playbackTimeScale =
          _baseRates[i] * (1.0 + 1.2 * bird.pitch).clamp(0.75, 1.5);
    }
  }
}

/// Advances pooled punch-debris chips and returns them when dead.
class DebrisSimComponent extends Component {
  DebrisSimComponent({
    required this.debris,
    required this.pool,
    required this.groundY,
  });

  final Map<Node, DebrisChipMotion> debris;
  final NodePool? Function() pool;
  final double groundY;

  @override
  void update(double deltaSeconds) {
    if (debris.isEmpty) {
      return;
    }
    final dead = <Node>[];
    debris.forEach((chip, motion) {
      motion.advance(deltaSeconds, groundY: groundY);
      chip.position = motion.position;
      if (motion.isDead) {
        dead.add(chip);
      }
    });
    final livePool = pool();
    for (final chip in dead) {
      debris.remove(chip);
      chip.visible = false;
      livePool?.despawn(chip);
    }
  }
}

/// Over-the-shoulder chase camera, writing [lookAtFrom] on the camera node.
class OtsCameraComponent extends Component {
  OtsCameraComponent({
    required this.rig,
    required this.characterPosition,
    required this.characterYaw,
    required this.isMoving,
    required this.orbitAngle,
    required this.pitch,
    required this.setOrbitAngle,
    required this.setPitch,
    required this.groundY,
  });

  final OtsCameraRig rig;
  final vm.Vector3 Function() characterPosition;
  final double Function() characterYaw;
  final bool Function() isMoving;
  final double Function() orbitAngle;
  final double Function() pitch;
  final void Function(double value) setOrbitAngle;
  final void Function(double value) setPitch;
  final double groundY;

  vm.Vector3? _eye;
  vm.Vector3? _target;

  void resetSmoothing() {
    _eye = null;
    _target = null;
  }

  @override
  void update(double deltaSeconds) {
    var yawOffset = orbitAngle();
    var pitchOffset = pitch();
    if (isMoving()) {
      final recenterRate = math.min(1.0, deltaSeconds * 3.5);
      yawOffset += (0.0 - yawOffset) * recenterRate;
      pitchOffset += (0.0 - pitchOffset) * recenterRate;
      setOrbitAngle(yawOffset);
      setPitch(pitchOffset);
    }

    final totalYaw = characterYaw() + yawOffset;
    final (targetEye, targetLookAt) = rig.compute(
      characterPosition: characterPosition(),
      yaw: totalYaw,
      pitchOffset: pitchOffset,
      groundY: groundY,
    );

    if (_eye == null || _target == null) {
      _eye = targetEye.clone();
      _target = targetLookAt.clone();
    } else {
      final eyeSpeed = math.min(1.0, deltaSeconds * 12.0);
      final targetSpeed = math.min(1.0, deltaSeconds * 16.0);
      _eye!.x += (targetEye.x - _eye!.x) * eyeSpeed;
      _eye!.y += (targetEye.y - _eye!.y) * eyeSpeed;
      _eye!.z += (targetEye.z - _eye!.z) * eyeSpeed;
      _target!.x += (targetLookAt.x - _target!.x) * targetSpeed;
      _target!.y += (targetLookAt.y - _target!.y) * targetSpeed;
      _target!.z += (targetLookAt.z - _target!.z) * targetSpeed;
    }

    node.lookAtFrom(_eye!, _target!);
  }
}

/// Samples [WaterSurfaceComponent] onto an updatable sea grid so Gerstner
/// displacement is actually visible (the kit component is evaluateAt-only).
class GerstnerDisplaceComponent extends Component {
  GerstnerDisplaceComponent({
    required this.geometry,
    required this.restPositions,
    required this.livePositions,
    required this.liveNormals,
  });

  final MeshGeometry geometry;
  final Float32List restPositions;
  final Float32List livePositions;
  final Float32List liveNormals;
  double _time = 0.0;

  @override
  void update(double deltaSeconds) {
    final water = node.getComponent<WaterSurfaceComponent>();
    // Super Ultra hides this sea and draws its own on the GPU; do not keep
    // re-uploading a grid nobody sees.
    if (water == null || deltaSeconds <= 0.0 || !node.visible) {
      return;
    }
    _time += deltaSeconds;
    final waves = water.waves;
    final waveCount = math.max(1, waves.length);
    final count = restPositions.length ~/ 3;
    for (var i = 0; i < count; i++) {
      final x = restPositions[i * 3];
      final z = restPositions[i * 3 + 2];
      var dx = 0.0;
      var dy = 0.0;
      var dz = 0.0;
      var txx = 1.0;
      var txy = 0.0;
      var txz = 0.0;
      var bxx = 0.0;
      var bxy = 0.0;
      var bxz = 1.0;
      for (final wave in waves) {
        if (wave.amplitude <= 0.0 || wave.wavelength <= 0.0) {
          continue;
        }
        final k = 2 * math.pi / wave.wavelength;
        final c = math.sqrt(9.81 / k);
        final phase = k * (wave.direction.x * x + wave.direction.y * z) -
            (wave.speed * c * k) * _time;
        final cosP = math.cos(phase);
        final sinP = math.sin(phase);
        final q = wave.steepness / (k * wave.amplitude * waveCount);
        final amp = wave.amplitude;
        final dirX = wave.direction.x;
        final dirY = wave.direction.y;
        dx += q * amp * dirX * cosP;
        dy += amp * sinP;
        dz += q * amp * dirY * cosP;
        final kAmpSin = k * amp * sinP;
        final kAmpCos = k * amp * cosP;
        txx += -q * dirX * dirX * kAmpSin;
        txy += dirX * kAmpCos;
        txz += -q * dirX * dirY * kAmpSin;
        bxx += -q * dirX * dirY * kAmpSin;
        bxy += dirY * kAmpCos;
        bxz += -q * dirY * dirY * kAmpSin;
      }
      final nx = bxy * txz - bxz * txy;
      final ny = bxz * txx - bxx * txz;
      final nz = bxx * txy - bxy * txx;
      final len = math.sqrt(nx * nx + ny * ny + nz * nz);
      final inv = len > 1e-8 ? 1.0 / len : 1.0;
      livePositions[i * 3] = x + dx;
      livePositions[i * 3 + 1] = dy;
      livePositions[i * 3 + 2] = z + dz;
      liveNormals[i * 3] = nx * inv;
      liveNormals[i * 3 + 1] = ny * inv;
      liveNormals[i * 3 + 2] = nz * inv;
    }
    geometry.updatePositions(livePositions);
    geometry.updateNormals(liveNormals);
  }
}

/// Keeps floating crates on the sampled water surface.
class BuoyFloatComponent extends Component {
  BuoyFloatComponent({
    required this.sampleWater,
    required this.x,
    required this.z,
    required this.seaY,
  });

  /// The visible sea at a point, or null when there is none to sit on.
  final ({vm.Vector3 displacement, vm.Vector3 normal})? Function(vm.Vector2)
      sampleWater;

  /// Where the crate floats. Mutable: Super Ultra moves crates off its beach.
  double x;
  double z;
  final double seaY;

  @override
  void update(double deltaSeconds) {
    final sample = sampleWater(vm.Vector2(x, z));
    if (sample == null) {
      return;
    }
    node.position = vm.Vector3(x, seaY + sample.displacement.y + 0.16, z);
  }
}

/// Expanding tap ring. Uniform scale only.
class TapMarkerComponent extends Component {
  TapMarkerComponent(this.material);

  final UnlitMaterial material;
  static const double lifetime = 0.85;
  double _age = lifetime;

  void pingAt(vm.Vector3 point, {required double groundY}) {
    _age = 0;
    node.visible = true;
    node.position = vm.Vector3(point.x, groundY + 0.03, point.z);
    node.scale = vm.Vector3.all(1.0);
  }

  @override
  void update(double deltaSeconds) {
    if (_age >= lifetime) {
      return;
    }
    _age += deltaSeconds;
    final t = (_age / lifetime).clamp(0.0, 1.0);
    if (t >= 1.0) {
      node.visible = false;
      return;
    }
    final alpha = (1.0 - t) * (1.0 - t);
    material.baseColorFactor = vm.Vector4(1.0, 0.95, 0.55, alpha * 0.95);
    node.scale = vm.Vector3.all(1.0 + t * 0.45);
  }
}

/// Writes physics-ball instance transforms after [BallPhysicsWorld] steps.
class PhysicsBallVisualComponent extends Component {
  PhysicsBallVisualComponent({
    required this.world,
    required this.batch,
  });

  final BallPhysicsWorld world;
  final InstancedMesh batch;

  @override
  void update(double deltaSeconds) {
    final count = math.min(world.balls.length, batch.instanceCount);
    for (var i = 0; i < count; i++) {
      final ball = world.balls[i];
      batch.setInstanceTransform(
        i,
        vm.Matrix4.compose(
          ball.position,
          ball.rotation,
          vm.Vector3.all(1.0),
        ),
      );
    }
  }
}

/// Builds an updatable XZ sea grid. Front faces wind CCW so they point +Y.
({MeshGeometry geometry, Float32List rest, Float32List live, Float32List normals})
    buildSeaGrid({
  double size = 180.0,
  int segments = 40,
}) {
  final cols = segments + 1;
  final rows = segments + 1;
  final rest = Float32List(cols * rows * 3);
  final tex = Float32List(cols * rows * 2);
  final indices = <int>[];
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      final i = r * cols + c;
      final x = (c / segments - 0.5) * size;
      final z = (r / segments - 0.5) * size;
      rest[i * 3] = x;
      rest[i * 3 + 1] = 0.0;
      rest[i * 3 + 2] = z;
      tex[i * 2] = c / segments;
      tex[i * 2 + 1] = r / segments;
    }
  }
  for (var r = 0; r < segments; r++) {
    for (var c = 0; c < segments; c++) {
      final v00 = r * cols + c;
      final v10 = v00 + 1;
      final v01 = v00 + cols;
      final v11 = v01 + 1;
      indices
        ..add(v00)
        ..add(v01)
        ..add(v10)
        ..add(v10)
        ..add(v01)
        ..add(v11);
    }
  }
  final geometry = MeshGeometry.fromArrays(
    positions: Float32List.fromList(rest),
    texCoords: tex,
    indices: indices,
    storage: GeometryStorage.updatable,
  );
  return (
    geometry: geometry,
    rest: rest,
    live: Float32List.fromList(rest),
    normals: Float32List(rest.length),
  );
}
