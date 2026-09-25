import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vector_math/vector_math_64.dart' as vm64;

import 'holo_card_game.dart';

/// The badge: drawn from the physics pose, with the spin and scroll lean
/// turned into a 3D perspective, and the foil face filled by the shader.
///
/// The component spans the whole tile so it can receive input, but it only
/// claims points that land on the card itself.
class HoloBadge extends PositionComponent
    with HasGameReference<HoloCardGame>, DragCallbacks, TapCallbacks {
  HoloBadge() : super(priority: 2);

  // Float indices into shaders/holo_foil.glsl, in its declaration order.
  static const _uSize = 0;
  static const _uTime = 2;
  static const _uTilt = 3;
  static const _uShine = 5;
  static const _uClaimed = 6;
  static const _uFace = 7;

  final Paint _foil = Paint();
  final Paint _shadow = Paint()
    ..color = const Color(0x73000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4;
  final Vector2 _finger = Vector2.zero();

  // A soft shadow keeps white type legible where the foil is brightest.
  static const _legible = [Shadow(color: Color(0x99000000), blurRadius: 8)];
  static const _small = TextStyle(
    color: Color(0xE6FFFFFF),
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.2,
    shadows: _legible,
  );
  static const _big = TextStyle(
    color: Color(0xFFFFFFFF),
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    shadows: _legible,
  );

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  bool containsLocalPoint(Vector2 point) =>
      game.physics.hitTest(vm.Vector2(point.x, point.y));

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _finger.setFrom(event.localPosition);
    game.grab(_finger);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _finger.add(event.localDelta);
    game.dragTo(_finger);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    game.release(event.velocity);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    game.release(Vector2.zero());
  }

  @override
  void onTapUp(TapUpEvent event) => game.tapBadge();

  @override
  void render(Canvas canvas) {
    final physics = game.physics;
    final pose = physics.pose;
    final width = physics.config.cardWidth;
    final height = physics.config.cardHeight;
    final yaw = game.spin.yaw;
    final lean = (game.scrollProgress * 0.25 + pose.angularVelocity * 0.04)
        .clamp(-0.6, 0.6);
    final backFacing = math.cos(yaw) < 0;
    final card = Rect.fromLTWH(0, 0, width, height);

    canvas.save();
    canvas.translate(pose.center.x, pose.center.y);
    canvas.rotate(pose.angle);

    // The shadow narrows as the badge turns edge-on. Narrow the rect, never
    // scale the canvas: a blur under a squashing scale becomes a blur many
    // times wider in local space, and costs ten times the raster time.
    final shadowWidth = width * math.max(math.cos(yaw).abs(), 0.04);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: const Offset(0, 12),
          width: shadowWidth,
          height: height,
        ),
        Radius.circular(math.min(height * 0.1, shadowWidth / 2)),
      ),
      _shadow,
    );

    canvas.transform(
      (vm64.Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateX(lean)
            ..rotateY(yaw))
          .storage,
    );
    // Seen from behind, mirror back so the back face reads correctly.
    if (backFacing) canvas.scale(-1, 1);
    canvas.translate(-width / 2, -height / 2);

    final shader = game.foilShader
      ..setFloat(_uSize, width)
      ..setFloat(_uSize + 1, height)
      ..setFloat(_uTime, game.elapsed)
      ..setFloat(_uTilt, math.sin(yaw))
      ..setFloat(_uTilt + 1, lean)
      ..setFloat(_uShine, game.shine)
      ..setFloat(_uClaimed, game.claimedAmount)
      ..setFloat(_uFace, backFacing ? 1 : 0);
    _foil.shader = shader;
    canvas.drawRect(card, _foil);
    _drawLabels(canvas, width, height, backFacing: backFacing);
    canvas.restore();

    // The metal ring through the hole sits on top of the card.
    _ring.color = Color.lerp(
      const Color(0xFFD9DCE6),
      const Color(0xFFFFD27A),
      game.claimedAmount,
    )!;
    canvas.drawCircle(Offset(pose.hole.x, pose.hole.y), 5.5, _ring);
  }

  void _drawLabels(
    Canvas canvas,
    double width,
    double height, {
    required bool backFacing,
  }) {
    const inset = 16.0;
    if (!backFacing) {
      _text(canvas, 'HOLO MEMBER', _small, const Offset(inset, 26));
      _text(canvas, '20% OFF', _big, const Offset(inset, 44));
      _text(
        canvas,
        game.claimed ? '✓ APPLIED TO YOUR PRICE' : 'TAP TO CLAIM',
        _small.copyWith(fontSize: 9, letterSpacing: 1.6),
        Offset(inset, height - 24),
      );
    } else if (game.claimed) {
      _text(canvas, 'CODE', _small, const Offset(inset, 26));
      _text(
        canvas,
        '${HoloCardGame.promoCode} ✓',
        _big,
        const Offset(inset, 44),
      );
    } else {
      _text(
        canvas,
        'NIMBUS',
        _big.copyWith(letterSpacing: 6),
        const Offset(inset, 38),
      );
      _text(canvas, 'MEMBER CARD', _small, Offset(inset, height - 28));
    }
  }

  void _text(Canvas canvas, String text, TextStyle style, Offset at) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
    painter.dispose();
  }
}
