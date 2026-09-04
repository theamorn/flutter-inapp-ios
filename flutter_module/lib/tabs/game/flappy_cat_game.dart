import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors, FontWeight, TextStyle;

import 'cat_player.dart';
import 'ground.dart';
import 'pipe_pair.dart';

enum FlappyCatPhase { ready, playing, dying, gameOver }

/// The Flame game used by the native `/game` engine.
class FlappyCatGame extends FlameGame with HasCollisionDetection, TapCallbacks {
  FlappyCatGame() {
    // Flame receives lifecycle events from GameWidget. Keeping this enabled
    // preserves the exact round while the native tab is not visible.
    pauseWhenBackgrounded = true;
  }

  static const int _poolSize = 8;
  static const double _spawnInterval = 1.58;
  static const double _deathDuration = 0.62;

  final Random _random = Random();
  final ValueNotifier<double> deathEffect = ValueNotifier<double>(0);

  late final CatPlayer player;
  late final Ground ground;
  late final List<PipePair> _pipePool;
  late final TextComponent<TextPaint> _scoreLabel;
  late final _MessagePanel _messagePanel;

  FlappyCatPhase phase = FlappyCatPhase.ready;
  int score = 0;
  double _spawnElapsed = 0;
  double _deathElapsed = 0;
  bool _contentLoaded = false;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final loadedImages = await images.loadAll([
      'cat_sprite_long.png',
      'street.jpg',
    ]);
    final catSheet = SpriteSheet(
      image: loadedImages[0],
      srcSize: Vector2.all(50),
    );
    final catAnimation = catSheet.createAnimation(
      row: 0,
      from: 10,
      to: 18,
      stepTime: 0.075,
    );

    ground = Ground(image: loadedImages[1]);
    player = CatPlayer(animation: catAnimation, onHit: _onPlayerHit);
    _scoreLabel = TextComponent<TextPaint>(
      text: '0',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.w900,
        ),
      ),
      anchor: Anchor.topCenter,
      priority: 100,
    );
    _messagePanel = _MessagePanel();
    _pipePool = List<PipePair>.generate(
      _poolSize,
      (_) =>
          PipePair(onPassed: _onPipePassed, playerX: () => player.position.x),
      growable: false,
    );

    await world.add(ground);
    for (final pipe in _pipePool) {
      await world.add(pipe);
    }
    await world.add(player);
    await world.add(_scoreLabel);
    await world.add(_messagePanel);

    _contentLoaded = true;
    _layoutGame();
    _showReadyState();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_contentLoaded) {
      _layoutGame();
    }
  }

  void _layoutGame() {
    ground.layoutFor(size);
    ground.scrollSpeed = max(82, size.x * 0.21);
    _scoreLabel.position.setValues(size.x / 2, 24);
    _messagePanel.layoutFor(size);

    if (phase == FlappyCatPhase.ready || phase == FlappyCatPhase.gameOver) {
      player.reset(size);
    } else {
      player.position.x = size.x * 0.27;
      player.position.y = player.position.y.clamp(30, ground.top - 30);
    }

    final pipeSpeed = max(158.0, size.x * 0.39);
    for (final pipe in _pipePool) {
      pipe
        ..speed = pipeSpeed
        ..relayout(playHeight: ground.top);
    }
  }

  void _showReadyState() {
    phase = FlappyCatPhase.ready;
    score = 0;
    _scoreLabel.text = '0';
    _messagePanel
      ..setContent('FLAPPY CAT', 'Tap anywhere to flap')
      ..isVisible = true;
    ground.scrolling = true;
    for (final pipe in _pipePool) {
      pipe.deactivate();
    }
    player.reset(size);
    deathEffect.value = 0;
  }

  void _startRound() {
    phase = FlappyCatPhase.playing;
    score = 0;
    _scoreLabel.text = '0';
    _spawnElapsed = 0.68;
    _deathElapsed = 0;
    _messagePanel.isVisible = false;
    ground.scrolling = true;
    deathEffect.value = 0;
    for (final pipe in _pipePool) {
      pipe.deactivate();
    }
    player
      ..reset(size)
      ..flap();
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    switch (phase) {
      case FlappyCatPhase.ready:
      case FlappyCatPhase.gameOver:
        _startRound();
      case FlappyCatPhase.playing:
        player.flap();
      case FlappyCatPhase.dying:
        break;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (phase == FlappyCatPhase.playing) {
      _spawnElapsed += dt;
      if (_spawnElapsed >= _spawnInterval) {
        _spawnElapsed -= _spawnInterval;
        _spawnPipe();
      }
      if (player.position.y + player.size.y / 2 < -18) {
        _onPlayerHit();
      }
    } else if (phase == FlappyCatPhase.dying) {
      _deathElapsed += dt;
      deathEffect.value = (_deathElapsed / _deathDuration)
          .clamp(0, 1)
          .toDouble();
      if (_deathElapsed >= _deathDuration) {
        _finishDeath();
      }
    }
  }

  void _spawnPipe() {
    PipePair? available;
    for (final pipe in _pipePool) {
      if (!pipe.active) {
        available = pipe;
        break;
      }
    }
    if (available == null) {
      return;
    }

    available.activate(
      x: size.x + 18,
      playHeight: ground.top,
      gapFactor: 0.18 + _random.nextDouble() * 0.64,
    );
  }

  void _onPipePassed() {
    if (phase != FlappyCatPhase.playing) {
      return;
    }
    score += 1;
    _scoreLabel.text = '$score';
  }

  void _onPlayerHit() {
    if (phase != FlappyCatPhase.playing) {
      return;
    }
    phase = FlappyCatPhase.dying;
    _deathElapsed = 0;
    deathEffect.value = 0.001;
    player.beginDeathFall();
  }

  void _finishDeath() {
    phase = FlappyCatPhase.gameOver;
    deathEffect.value = 0;
    ground.scrolling = false;
    player.freeze();
    for (final pipe in _pipePool) {
      pipe.moving = false;
    }
    _messagePanel
      ..setContent('GAME OVER', 'Score $score  •  Tap to restart')
      ..isVisible = true;
  }

  @override
  void onDispose() {
    deathEffect.dispose();
    super.onDispose();
  }
}

class _MessagePanel extends PositionComponent with HasVisibility {
  _MessagePanel()
    : _title = TextComponent<TextPaint>(
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        anchor: Anchor.topCenter,
      ),
      _hint = TextComponent<TextPaint>(
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFD9F4FF),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        anchor: Anchor.topCenter,
      ),
      super(priority: 90);

  final TextComponent<TextPaint> _title;
  final TextComponent<TextPaint> _hint;
  final Paint _panelPaint = Paint()..color = const Color(0x9A10243D);
  RRect _panel = RRect.zero;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await addAll([_title, _hint]);
  }

  void layoutFor(Vector2 gameSize) {
    final width = min(330, gameSize.x - 36).toDouble();
    size.setValues(width, 126);
    position.setValues((gameSize.x - width) / 2, gameSize.y * 0.2);
    _title.position.setValues(width / 2, 25);
    _hint.position.setValues(width / 2, 78);
    _panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, size.y),
      const Radius.circular(22),
    );
  }

  void setContent(String title, String hint) {
    _title.text = title;
    _hint.text = hint;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(_panel, _panelPaint);
    super.render(canvas);
  }
}
