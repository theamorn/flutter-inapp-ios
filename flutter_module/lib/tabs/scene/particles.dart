/// The 2D particle layer composited over the 3D island — `06-island-scene.md`.
///
/// Deliberately 2D: a screen-space overlay is far cheaper than 3D particles and
/// at projector distance it reads better anyway. Daytime dust motes cross-fade
/// into nighttime fireflies as the day/night slider moves, so a mid-sweep frame
/// is never an abrupt swap.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// One mote. Positions are normalised (0..1) so the field survives a resize.
class Mote {
  Mote({
    required this.x,
    required this.y,
    required this.driftX,
    required this.driftY,
    required this.size,
    required this.phase,
    required this.blinkRate,
  });

  double x;
  double y;
  final double driftX;
  final double driftY;
  final double size;
  double phase;
  final double blinkRate;
}

/// A drifting field of motes, advanced by [advance].
///
/// Pure state with no Flutter or GPU dependency, so it is unit-testable.
class ParticleField {
  ParticleField({int count = 36, int seed = 0x15ea})
    : _random = math.Random(seed) {
    for (var i = 0; i < count; i++) {
      motes.add(_spawn(_random.nextDouble()));
    }
  }

  final math.Random _random;

  /// The live motes.
  final List<Mote> motes = <Mote>[];

  Mote _spawn(double y) => Mote(
    x: _random.nextDouble(),
    y: y,
    driftX: (_random.nextDouble() - 0.5) * 0.018,
    driftY: -0.006 - _random.nextDouble() * 0.018,
    size: 1.0 + _random.nextDouble() * 2.2,
    phase: _random.nextDouble() * math.pi * 2,
    blinkRate: 0.7 + _random.nextDouble() * 1.6,
  );

  /// Advances every mote by [deltaSeconds], wrapping them around the field.
  void advance(double deltaSeconds) {
    if (deltaSeconds <= 0) {
      return;
    }
    final dt = math.min(deltaSeconds, 0.1);
    for (var i = 0; i < motes.length; i++) {
      final mote = motes[i];
      mote.x += mote.driftX * dt;
      mote.y += mote.driftY * dt;
      mote.phase += mote.blinkRate * dt;
      if (mote.y < -0.05) {
        motes[i] = _spawn(1.05);
      } else if (mote.x < -0.05) {
        mote.x += 1.1;
      } else if (mote.x > 1.05) {
        mote.x -= 1.1;
      }
    }
  }
}

/// Paints [field] as dust motes, fireflies, or a blend of the two.
class ParticleOverlayPainter extends CustomPainter {
  ParticleOverlayPainter({
    required this.field,
    required this.nightBlend,
    required this.repaint,
  }) : super(repaint: repaint);

  final ParticleField field;

  /// 0 = full daylight (dust), 1 = full night (fireflies).
  final double nightBlend;

  final Listenable repaint;

  static const Color _dustColor = Color(0xFFFFF3D6);
  static const Color _fireflyColor = Color(0xFFB8FF6A);

  @override
  void paint(Canvas canvas, Size size) {
    final night = nightBlend.clamp(0.0, 1.0);
    final day = 1.0 - night;
    final dust = Paint()..color = _dustColor;
    final firefly = Paint()
      ..color = _fireflyColor
      ..maskFilter = night > 0.01
          ? const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.2)
          : null;

    for (final mote in field.motes) {
      final offset = Offset(mote.x * size.width, mote.y * size.height);
      if (day > 0.01) {
        dust.color = _dustColor.withValues(alpha: 0.28 * day);
        canvas.drawCircle(offset, mote.size * 0.6, dust);
      }
      if (night > 0.01) {
        // Fireflies blink; dust does not. The pulse is what sells the swap.
        final pulse = 0.5 + 0.5 * math.sin(mote.phase * 2.4);
        firefly.color = _fireflyColor.withValues(
          alpha: (0.15 + 0.75 * pulse) * night,
        );
        canvas.drawCircle(offset, mote.size * (0.9 + 0.5 * pulse), firefly);
      }
    }
  }

  @override
  bool shouldRepaint(ParticleOverlayPainter oldDelegate) =>
      oldDelegate.nightBlend != nightBlend || oldDelegate.field != field;
}

/// The overlay widget. [nightBlend] is 0 by day and 1 at night.
class ParticleOverlay extends StatelessWidget {
  const ParticleOverlay({
    required this.field,
    required this.nightBlend,
    required this.repaint,
    super.key,
  });

  final ParticleField field;
  final double nightBlend;
  final Listenable repaint;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: ParticleOverlayPainter(
            field: field,
            nightBlend: nightBlend,
            repaint: repaint,
          ),
        ),
      ),
    );
  }
}
