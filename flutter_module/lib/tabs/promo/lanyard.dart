import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'holo_card_game.dart';

/// A soft spotlight behind the badge, so the dark tile has depth.
class PromoBackdrop extends Component with HasGameReference<HoloCardGame> {
  PromoBackdrop() : super(priority: 0);

  final Paint _paint = Paint();
  Vector2 _paintedFor = Vector2.zero();

  @override
  void render(Canvas canvas) {
    final size = game.size;
    if (_paintedFor != size) {
      _paintedFor = size.clone();
      _paint.shader = RadialGradient(
        center: const Alignment(0, -0.1),
        radius: 0.85,
        colors: const [Color(0xFF2A1F5C), HoloCardGame.backdropColor],
      ).createShader(Offset.zero & size.toSize());
    }
    canvas.drawRect(Offset.zero & size.toSize(), _paint);
  }
}

/// The strap and its clip, drawn through the physics rope points.
class LanyardStrap extends Component with HasGameReference<HoloCardGame> {
  LanyardStrap() : super(priority: 1);

  final Paint _strap = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 11
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFF6B47F5);
  final Paint _stitch = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = const Color(0x80FFFFFF);
  final Paint _clip = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF2F4F8), Color(0xFF8C92A6)],
    ).createShader(const Rect.fromLTWH(-10, -8, 20, 16));

  @override
  void render(Canvas canvas) {
    final points = game.physics.ropePoints;
    // Smooth the polyline through segment midpoints so the strap curves.
    final path = Path()..moveTo(points.first.x, points.first.y);
    for (var i = 1; i < points.length - 1; i++) {
      final mid = (points[i] + points[i + 1])..scale(0.5);
      path.quadraticBezierTo(points[i].x, points[i].y, mid.x, mid.y);
    }
    path.lineTo(points.last.x, points.last.y);
    canvas
      ..drawPath(path, _strap)
      ..drawPath(path, _stitch);

    final anchor = points.first;
    canvas.save();
    canvas.translate(anchor.x, anchor.y);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, -8, 20, 16),
        const Radius.circular(4),
      ),
      _clip,
    );
    canvas.restore();
  }
}
