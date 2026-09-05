/// Route `/scene` — tab 5, the island. See `docs/hybrid-demo/06-island-scene.md`.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_module/tabs/scene/island_scene.dart';
import 'package:flutter_module/tabs/scene/particles.dart';

/// Off in every shipped build. Enable with
/// `--dart-define=SCENE_AUTO_DEMO=true` to drive taps from a timer (there is
/// no way to tap a simulator programmatically) and to overlay the unprojection
/// check described in `06-island-scene.md`.
const bool kSceneAutoDemo = bool.fromEnvironment('SCENE_AUTO_DEMO');

class IslandSceneApp extends StatelessWidget {
  const IslandSceneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3DA35D),
          brightness: Brightness.dark,
        ),
      ),
      // The engine boots this app with defaultRouteName '/scene', which a
      // bare `home:` cannot satisfy — the Navigator logs "Could not navigate
      // to initial route" and silently falls back to '/'.
      //
      // `onGenerateRoute` alone is NOT the fix. Navigator's default initial
      // route handling splits '/scene' into ['/', '/scene'] and pushes both
      // when both resolve — which would mount TWO IslandSceneScreens, two
      // Scenes and two render loops, one of them invisible underneath. On a
      // tab whose entire purpose is an honest performance number, that is the
      // worst possible bug. Pinning the initial stack to exactly one route is
      // what prevents it.
      onGenerateInitialRoutes: (_) => <Route<void>>[
        MaterialPageRoute<void>(builder: (_) => const IslandSceneScreen()),
      ],
      onGenerateRoute: (RouteSettings settings) =>
          MaterialPageRoute<void>(builder: (_) => const IslandSceneScreen()),
    );
  }
}

class IslandSceneScreen extends StatefulWidget {
  const IslandSceneScreen({super.key});

  @override
  State<IslandSceneScreen> createState() => _IslandSceneScreenState();
}

class _IslandSceneScreenState extends State<IslandSceneScreen>
    with WidgetsBindingObserver {
  final IslandScene _island = IslandScene();
  final ParticleField _particles = ParticleField();
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  final GlobalKey _viewKey = GlobalKey();

  bool _ready = false;
  String? _error;

  /// Whether the render loop runs. The engine stays alive when the host hides
  /// this tab, so a 3D scene left ticking behind tabs 1-4 would burn GPU and
  /// skew every other tab's HUD numbers — which is the demo's whole evidence
  /// base. Fails *open*: only an explicit paused/hidden/detached stops it, so
  /// an embedder that never reports `resumed` still renders.
  bool _renderLoopActive = true;

  double _timeOfDay = 10.5;
  double _nightBlend = 0;

  ui.Offset? _pointerDownAt;
  Duration _pointerDownStamp = Duration.zero;
  final Stopwatch _pointerClock = Stopwatch()..start();

  Timer? _autoDemoTimer;
  int _autoDemoStep = 0;
  ui.Offset? _debugTapScreenPoint;
  ui.Offset? _debugPickedScreenPoint;

  static const List<ui.Offset> _autoDemoTargets = <ui.Offset>[
    ui.Offset(0.5, 0.52),
    ui.Offset(0.16, 0.40),
    ui.Offset(0.84, 0.40),
    ui.Offset(0.18, 0.72),
    ui.Offset(0.82, 0.72),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      await _island.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _ready = true;
        _timeOfDay = _island.timeOfDay;
      });
      if (kSceneAutoDemo) {
        _autoDemoTimer = Timer.periodic(
          const Duration(milliseconds: 2600),
          (_) => _runAutoDemoStep(),
        );
      }
    } catch (error, stack) {
      debugPrint('island scene failed to load: $error\n$stack');
      if (mounted) {
        setState(() => _error = '$error');
      }
    }
  }

  @override
  void dispose() {
    _autoDemoTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _frame.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active =
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden &&
        state != AppLifecycleState.detached;
    if (active != _renderLoopActive) {
      // Logged, not just rendered: this is the only way to confirm the tab
      // actually stopped rendering when the host hid it, since the HUD line
      // saying so is off-screen exactly when it is true.
      debugPrint(
        'island scene: render loop ${active ? "resumed" : "stopped"} ($state)',
      );
      setState(() => _renderLoopActive = active);
    }
  }

  void _onTick(Duration elapsed, double deltaSeconds) {
    _island.tick(deltaSeconds);
    _particles.advance(deltaSeconds);
    _frame.value = _frame.value + 1;

    final night = _island.nightBlend;
    if ((night - _nightBlend).abs() > 0.004) {
      setState(() => _nightBlend = night);
    }
  }

  ui.Size? get _viewSize {
    final box = _viewKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size : null;
  }

  ui.Offset? _toLocal(ui.Offset globalPosition) {
    final box = _viewKey.currentContext?.findRenderObject();
    return box is RenderBox ? box.globalToLocal(globalPosition) : null;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownAt = event.position;
    _pointerDownStamp = _pointerClock.elapsed;
  }

  void _onPointerUp(PointerUpEvent event) {
    final downAt = _pointerDownAt;
    _pointerDownAt = null;
    if (downAt == null) {
      return;
    }
    // Discriminated by hand rather than with a TapGestureRecognizer: the
    // orbit controller owns a ScaleGestureRecognizer, and putting a tap
    // recognizer in the same arena makes taps and orbits fight.
    final travel = (event.position - downAt).distance;
    final held = _pointerClock.elapsed - _pointerDownStamp;
    if (travel > 12 || held > const Duration(milliseconds: 400)) {
      return;
    }
    final local = _toLocal(event.position);
    final size = _viewSize;
    if (local == null || size == null) {
      return;
    }
    _island.tapAt(local, size);
  }

  void _runAutoDemoStep() {
    final size = _viewSize;
    if (size == null || !_ready) {
      return;
    }
    final fraction = _autoDemoTargets[_autoDemoStep % _autoDemoTargets.length];
    _autoDemoStep += 1;
    final local = ui.Offset(
      fraction.dx * size.width,
      fraction.dy * size.height,
    );
    _island.tapAt(local, size);
    // Sweep the clock too, so one screenshot pass covers day, sunset and
    // night without anyone touching the slider. Debug-only: this lives in the
    // auto-demo step, never in the real tap handler.
    _onTimeChanged((_timeOfDay + 1.25) % 24.0);
    // Project the UNCLAMPED ground hit: the clamp deliberately moves a target
    // that landed in the sea, so probing the clamped point would show a false
    // mismatch near the horizon.
    final hit = _island.groundPointAt(local, size);
    setState(() {
      _debugTapScreenPoint = local;
      _debugPickedScreenPoint = hit == null
          ? null
          : _island.camera.worldToScreen(hit, size);
    });
  }

  void _onTimeChanged(double value) {
    setState(() {
      _timeOfDay = value;
      _island.timeOfDay = value;
      _nightBlend = _island.nightBlend;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07131F),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (_error != null)
            _ErrorPanel(message: _error!)
          else if (!_ready)
            const _LoadingPanel()
          else ...<Widget>[
            Listener(
              behavior: HitTestBehavior.deferToChild,
              onPointerDown: _onPointerDown,
              onPointerUp: _onPointerUp,
              child: SizedBox.expand(
                key: _viewKey,
                // TickerMode, NOT `SceneView(autoTick: _renderLoopActive)`.
                // _SceneViewState is a SingleTickerProviderStateMixin and
                // recreates its ticker when autoTick changes; that mixin never
                // releases its one ticker slot, so the first time the tab came
                // back it threw "multiple tickers were created" and the whole
                // scene turned into a red error screen. Muting the ticker it
                // already has does the same job and keeps the view alive, so
                // returning to the tab costs nothing.
                child: TickerMode(
                  enabled: _renderLoopActive,
                  child: CameraControls(
                    controller: _island.orbit,
                    enabled: _renderLoopActive,
                    autofocus: false,
                    child: SceneView(
                      _island.scene,
                      camera: _island.camera,
                      onTick: _onTick,
                      warmUp: true,
                    ),
                  ),
                ),
              ),
            ),
            ParticleOverlay(
              field: _particles,
              nightBlend: _nightBlend,
              repaint: _frame,
            ),
            if (kSceneAutoDemo)
              IgnorePointer(
                child: CustomPaint(
                  painter: _UnprojectionProbePainter(
                    tapPoint: _debugTapScreenPoint,
                    pickedPoint: _debugPickedScreenPoint,
                  ),
                ),
              ),
            _Readout(
              triangles: _island.triangleCount,
              drawCalls: _island.drawCallCount,
              timeOfDay: _timeOfDay,
              renderLoopActive: _renderLoopActive,
            ),
            _DayNightSlider(
              value: _timeOfDay,
              nightBlend: _nightBlend,
              onChanged: _onTimeChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(height: 16),
          Text('Building the island…'),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.warning_amber_rounded, size: 44),
            const SizedBox(height: 12),
            const Text('The island scene could not be built'),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontFamily: 'Menlo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Triangle count and draw calls, next to the clock. Real geometry, real
/// numbers, still pinned at full refresh rate — that juxtaposition with the
/// native HUD is the argument the tab exists to make.
class _Readout extends StatelessWidget {
  const _Readout({
    required this.triangles,
    required this.drawCalls,
    required this.timeOfDay,
    required this.renderLoopActive,
  });

  final int triangles;
  final int drawCalls;
  final double timeOfDay;
  final bool renderLoopActive;

  static String _clock(double hours) {
    final total = (hours * 60).round() % (24 * 60);
    final h = (total ~/ 60).toString().padLeft(2, '0');
    final m = (total % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _grouped(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 12,
                  height: 1.45,
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${_grouped(triangles)} tris',
                      style: const TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text('$drawCalls draw calls'),
                    Text('${_clock(timeOfDay)}  local'),
                    if (!renderLoopActive)
                      const Text(
                        'render loop stopped',
                        style: TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 12,
                          color: Color(0xFFFFC46B),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayNightSlider extends StatelessWidget {
  const _DayNightSlider({
    required this.value,
    required this.nightBlend,
    required this.onChanged,
  });

  final double value;
  final double nightBlend;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              // A Slider takes the FULL height of any bounded constraint it is
              // given. Without this SizedBox it stretches to the whole safe
              // area and drags its translucent panel with it, greying out the
              // entire scene — which looks like a rendering bug, not a layout
              // one. See 06-island-scene.md.
              child: SizedBox(
                height: 52,
                child: Row(
                  children: <Widget>[
                    // 0 and 24 are both midnight, so a moon-at-one-end,
                    // sun-at-the-other pair of icons would be a lie. The icon
                    // reports the CURRENT state and the clock is the scale.
                    Icon(
                      nightBlend > 0.5
                          ? Icons.nightlight_round
                          : Icons.wb_sunny_rounded,
                      size: 18,
                    ),
                    Expanded(
                      child: Slider(
                        value: value,
                        min: 0,
                        max: 24,
                        onChanged: onChanged,
                      ),
                    ),
                    SizedBox(
                      width: 46,
                      child: Text(
                        _Readout._clock(value),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Debug-only overlay for the auto-demo: a hollow ring at the synthetic tap
/// position and a filled dot where the picked world point projects back to.
/// They coincide when the unprojection is right — including at the corners,
/// which is where a device-pixel-ratio mistake shows up first.
class _UnprojectionProbePainter extends CustomPainter {
  _UnprojectionProbePainter({
    required this.tapPoint,
    required this.pickedPoint,
  });

  final ui.Offset? tapPoint;
  final ui.Offset? pickedPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final tap = tapPoint;
    if (tap != null) {
      canvas.drawCircle(
        tap,
        16,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFF3B6B),
      );
    }
    final picked = pickedPoint;
    if (picked != null) {
      canvas.drawCircle(picked, 5, Paint()..color = const Color(0xFF33E0FF));
    }
  }

  @override
  bool shouldRepaint(_UnprojectionProbePainter oldDelegate) =>
      oldDelegate.tapPoint != tapPoint ||
      oldDelegate.pickedPoint != pickedPoint;
}
