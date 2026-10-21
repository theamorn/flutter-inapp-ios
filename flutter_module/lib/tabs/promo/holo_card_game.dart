import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:vector_math/vector_math.dart' as vm;

import 'badge_spin.dart';
import 'holo_badge.dart';
import 'lanyard.dart';
import 'lanyard_physics.dart';
import 'promo_run_gate.dart';
import 'scroll_push.dart';
import 'sparkles.dart';

/// The Flame game behind the native Shop page's inline promo tile: a holo
/// member badge on a lanyard that the user can grab, throw, and spin.
///
/// It talks to the host only through callbacks and the setters below, so it
/// knows nothing about method channels; `promo_app.dart` wires those.
class HoloCardGame extends FlameGame {
  HoloCardGame({this.onClaim, this.onBadgeBounds}) {
    // PromoRunGate owns pausing: Flame's own background handling would resume
    // on return even while the host has the tile scrolled off screen.
    pauseWhenBackgrounded = false;
  }

  static const promoCode = 'HOLO20';
  static const backdropColor = Color(0xFF0C0A1C);

  final void Function(String code)? onClaim;
  final void Function(vm.Aabb2 bounds, double seconds)? onBadgeBounds;

  late final LanyardWorld physics;
  late final ui.FragmentShader foilShader;
  final BadgeSpin spin = BadgeSpin();
  final ScrollPush _push = ScrollPush();
  late final PromoRunGate _gate = PromoRunGate(
    onChanged: (running) => running ? resumeEngine() : pauseEngine(),
  );
  final Stopwatch _clock = Stopwatch()..start();
  final math.Random _random = math.Random();
  bool _loaded = false;

  /// Where the tile sits in the host viewport; see [PromoHostLink.onScroll].
  double scrollProgress = 0;
  bool claimed = false;

  /// 0 -> 1 after the claim, for the foil's shift to gold.
  double claimedAmount = 0;

  /// 0 -> 1 once per claim tap, for the shine sweep; 1 means idle.
  double shine = 1;
  double elapsed = 0;
  double _lastHapticAt = double.negativeInfinity;

  double get _seconds => _clock.elapsedMicroseconds / 1e6;

  @override
  Color backgroundColor() => backdropColor;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/holo_foil.glsl',
    );
    foilShader = program.fragmentShader();
    physics = LanyardWorld(width: size.x, height: size.y);
    _loaded = true;
    await world.addAll([PromoBackdrop(), LanyardStrap(), HoloBadge()]);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_loaded) physics.resize(size.x, size.y);
  }

  set hostVisible(bool visible) => _gate.hostVisible = visible;

  void hostScrolled(double progress, double velocity) {
    scrollProgress = progress;
    _push.addSample(velocity, _seconds);
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    super.lifecycleStateChange(state);
    _gate.lifecycle = state;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_loaded) return;
    elapsed += dt;
    final push = vm.Vector2(0, _push.accelerationAt(_seconds));
    final impacts = physics.step(dt, externalAcceleration: push);
    spin.step(dt);
    if (claimed) claimedAmount = math.min(1, claimedAmount + dt / 0.8);
    if (shine < 1) shine = math.min(1, shine + dt / 0.6);

    for (final impact in impacts) {
      world.add(
        sparkleBurst(
          at: Vector2(impact.position.x, impact.position.y),
          count: 8,
          speed: 160,
          random: _random,
        ),
      );
      if (_seconds - _lastHapticAt > 0.09) {
        _lastHapticAt = _seconds;
        HapticFeedback.lightImpact();
      }
    }
    onBadgeBounds?.call(physics.cardBounds, _seconds);
  }

  bool grab(Vector2 point) => physics.grab(vm.Vector2(point.x, point.y));

  void dragTo(Vector2 point) => physics.dragTo(vm.Vector2(point.x, point.y));

  /// A sideways throw also spins the badge around its strap.
  void release(Vector2 velocity) {
    physics.release();
    spin.flick(velocity.x * 0.012);
  }

  /// First tap claims the promo and turns the badge to show the code; later
  /// taps turn it back and forth.
  void tapBadge() {
    final center = physics.pose.center;
    if (!claimed) {
      claimed = true;
      shine = 0;
      onClaim?.call(promoCode);
    } else {
      HapticFeedback.selectionClick();
    }
    spin.flip();
    world.add(
      sparkleBurst(
        at: Vector2(center.x, center.y),
        count: claimedAmount == 0 ? 40 : 14,
        speed: 280,
        random: _random,
      ),
    );
  }
}
