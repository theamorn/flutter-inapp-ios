import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

/// A pooled pair of obstacles. Instances stay mounted and are moved back to
/// the right edge, avoiding asset/component allocation during play.
class PipePair extends PositionComponent {
  PipePair({required this.onPassed, required this.playerX})
    : super(priority: 10);

  static const double pipeWidth = 72;

  final void Function() onPassed;
  final double Function() playerX;

  late final PipeSegment _topPipe;
  late final PipeSegment _bottomPipe;

  bool active = false;
  bool moving = true;
  bool _scored = false;
  double speed = 160;
  double _gapFactor = 0.5;
  double _playHeight = 700;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _topPipe = PipeSegment(isTop: true);
    _bottomPipe = PipeSegment(isTop: false);
    await addAll([_topPipe, _bottomPipe]);
    deactivate();
  }

  void activate({
    required double x,
    required double playHeight,
    required double gapFactor,
  }) {
    position.setValues(x, 0);
    _playHeight = playHeight;
    _gapFactor = gapFactor;
    _scored = false;
    active = true;
    moving = true;
    _layoutSegments();
    _topPipe.setCollidable(true);
    _bottomPipe.setCollidable(true);
  }

  void relayout({required double playHeight}) {
    _playHeight = playHeight;
    _layoutSegments();
  }

  void deactivate() {
    active = false;
    moving = false;
    position.setValues(-10000, 0);
    if (isLoaded) {
      _topPipe.setCollidable(false);
      _bottomPipe.setCollidable(false);
    }
  }

  void _layoutSegments() {
    final gapHeight = (_playHeight * 0.245).clamp(154, 205).toDouble();
    const topMargin = 68.0;
    const bottomMargin = 72.0;
    final available = (_playHeight - topMargin - bottomMargin - gapHeight)
        .clamp(20, 10000);
    final gapTop = topMargin + available * _gapFactor;

    _topPipe
      ..position.setValues(0, 0)
      ..setGeometry(pipeWidth, gapTop);
    _bottomPipe
      ..position.setValues(0, gapTop + gapHeight)
      ..setGeometry(pipeWidth, _playHeight - gapTop - gapHeight);
    size.setValues(pipeWidth, _playHeight);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!active || !moving) {
      return;
    }

    position.x -= speed * dt;
    if (!_scored && position.x + pipeWidth < playerX()) {
      _scored = true;
      onPassed();
    }
    if (position.x + pipeWidth < -8) {
      deactivate();
    }
  }
}

/// One collidable half of a pipe pair.
class PipeSegment extends PositionComponent {
  PipeSegment({required this.isTop}) : super(priority: 10);

  final bool isTop;

  final Paint _bodyPaint = Paint()..color = const Color(0xFF28A84F);
  final Paint _darkPaint = Paint()..color = const Color(0xFF127438);
  final Paint _shinePaint = Paint()..color = const Color(0xFF71DD77);

  late final RectangleHitbox _hitbox;
  RRect _body = RRect.zero;
  RRect _lip = RRect.zero;
  Rect _shadow = Rect.zero;
  Rect _shine = Rect.zero;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _hitbox = RectangleHitbox(collisionType: CollisionType.inactive);
    await add(_hitbox);
  }

  void setGeometry(double width, double height) {
    size.setValues(width, height);
    const lipHeight = 22.0;
    final lipY = isTop ? height - lipHeight : 0.0;
    final bodyTop = isTop ? 0.0 : lipHeight - 3;
    final bodyBottom = isTop ? lipY + 3 : height;
    final radius = const Radius.circular(7);

    _body = RRect.fromRectAndRadius(
      Rect.fromLTRB(6, bodyTop, width - 6, bodyBottom),
      radius,
    );
    _lip = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, lipY, width, lipHeight),
      radius,
    );
    _shadow = Rect.fromLTWH(width - 13, bodyTop, 7, bodyBottom - bodyTop);
    _shine = Rect.fromLTWH(13, bodyTop + 4, 6, bodyBottom - bodyTop - 8);
  }

  void setCollidable(bool value) {
    _hitbox.collisionType = value
        ? CollisionType.passive
        : CollisionType.inactive;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(_body, _bodyPaint);
    canvas.drawRect(_shadow, _darkPaint);
    canvas.drawRect(_shine, _shinePaint);
    canvas.drawRRect(_lip, _bodyPaint);
    super.render(canvas);
  }
}
