import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/painting.dart';

const _sparkleColors = [
  Color(0xFFFFFFFF),
  Color(0xFFB9F3FF),
  Color(0xFFFFD27A),
  Color(0xFFE3B8FF),
];

/// A burst of four-point stars from [at] that fall and fade; removes itself.
ParticleSystemComponent sparkleBurst({
  required Vector2 at,
  required int count,
  required double speed,
  required math.Random random,
}) {
  return ParticleSystemComponent(
    priority: 3,
    particle: Particle.generate(
      count: count,
      lifespan: 0.7,
      generator: (_) {
        final direction = random.nextDouble() * math.pi * 2;
        final velocity =
            Vector2(math.cos(direction), math.sin(direction)) *
            (speed * (0.35 + random.nextDouble() * 0.65));
        final color = _sparkleColors[random.nextInt(_sparkleColors.length)];
        final radius = 3 + random.nextDouble() * 4;
        final paint = Paint();
        return AcceleratedParticle(
          position: at.clone(),
          speed: velocity,
          acceleration: Vector2(0, 420),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              final fade = 1 - particle.progress;
              paint.color = color.withValues(alpha: fade);
              _drawStar(canvas, radius * (0.4 + 0.6 * fade), paint);
            },
          ),
        );
      },
    ),
  );
}

void _drawStar(Canvas canvas, double radius, Paint paint) {
  final waist = radius * 0.22;
  final path = Path()
    ..moveTo(0, -radius)
    ..lineTo(waist, -waist)
    ..lineTo(radius, 0)
    ..lineTo(waist, waist)
    ..lineTo(0, radius)
    ..lineTo(-waist, waist)
    ..lineTo(-radius, 0)
    ..lineTo(-waist, -waist)
    ..close();
  canvas.drawPath(path, paint);
}
