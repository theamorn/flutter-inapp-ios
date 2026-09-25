/// Route `/scene` — tab 5, the island. See `docs/hybrid-demo/06-island-scene.md`.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:flutter_module/tabs/scene/island_scene.dart';
import 'package:flutter_module/tabs/scene/particles.dart';
import 'package:flutter_module/tabs/scene/super_ultra/super_ultra_effects.dart';

/// Off in every shipped build. Enable with
/// `--dart-define=SCENE_AUTO_DEMO=true` to drive taps from a timer (there is
/// no way to tap a simulator programmatically) and to overlay the unprojection
/// check described in `06-island-scene.md`.
const bool kSceneAutoDemo = bool.fromEnvironment('SCENE_AUTO_DEMO');

/// Off in every shipped build. `--dart-define=SCENE_QUALITY=superUltra` (or
/// `ultra`, `normal`) switches the island to that mode as soon as it loads,
/// and `--dart-define=SCENE_TOUR=true` then steps the clock through a fixed
/// set of times, holding each long enough to screenshot, and logs each stop.
/// The simulator cannot be tapped from a script; this is how the
/// verification loop reaches every mode and every light.
const String kSceneStartQuality = String.fromEnvironment('SCENE_QUALITY');
const bool kSceneTour = bool.fromEnvironment('SCENE_TOUR');

/// Off in every shipped build. With `SCENE_TOUR`, also switches the mode at
/// every stop (Normal, Ultra, Super Ultra and back), to exercise each
/// transition, including the first Super Ultra build, without a finger.
const bool kSceneTourModes = bool.fromEnvironment('SCENE_TOUR_MODES');

/// Off in every shipped build. `--dart-define=SCENE_RAIN=true` switches the
/// rain on after load (it falls once Super Ultra is active).
const bool kSceneRain = bool.fromEnvironment('SCENE_RAIN');

/// Off in every shipped build. `--dart-define=SCENE_LIGHTNING_HOLD=2` holds
/// each lightning strike at its peak for two seconds, so a screenshot taken
/// after the `island lightning: strike` log line catches it.
const String kSceneLightningHold = String.fromEnvironment('SCENE_LIGHTNING_HOLD');

/// Off in every shipped build. `--dart-define=SCENE_FRAME_STATS=true` logs
/// UI-thread (build) and raster time every five seconds from `FrameTiming`,
/// the same numbers DevTools charts, so a before/after comparison needs no
/// DevTools session. Only meaningful in profile or release builds.
const bool kSceneFrameStats = bool.fromEnvironment('SCENE_FRAME_STATS');

/// Off in every shipped build. `--dart-define=SCENE_ABLATION=true`, with
/// `SCENE_QUALITY=superUltra` in a profile build, takes Super Ultra's
/// features away one at a time (`IslandScene.debugAblationSteps`) and logs
/// what each costs on the UI and raster threads. Each step settles for 4 s
/// and is measured for 5 s, over three rounds, so slow drift in the device's
/// speed lands on every step alike. About 10 minutes; ends with a table.
const bool kSceneAblation = bool.fromEnvironment('SCENE_ABLATION');

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
  bool _uiVisible = true;

  double _timeOfDay = 10.5;
  double _nightBlend = 0;

  ui.Offset? _pointerDownAt;
  Duration _pointerDownStamp = Duration.zero;
  final Stopwatch _pointerClock = Stopwatch()..start();

  Timer? _autoDemoTimer;
  int _autoDemoStep = 0;
  Timer? _tourTimer;
  int _tourStep = 0;

  static const List<double> _tourTimes = <double>[10.5, 17.4, 18.4, 21.5, 1.5, 6.4];
  static const List<IslandQuality> _tourModes = <IslandQuality>[
    IslandQuality.normal,
    IslandQuality.ultra,
    IslandQuality.superUltra,
    IslandQuality.ultra,
    IslandQuality.normal,
    IslandQuality.superUltra,
  ];
  ui.Offset? _debugTapScreenPoint;
  ui.Offset? _debugPickedScreenPoint;

  static const List<ui.Offset> _autoDemoTargets = <ui.Offset>[
    ui.Offset(0.5, 0.52),
    ui.Offset(0.16, 0.40),
    ui.Offset(0.84, 0.40),
    ui.Offset(0.18, 0.72),
    ui.Offset(0.82, 0.72),
  ];

  final List<int> _uiMicros = <int>[];
  final List<int> _rasterMicros = <int>[];
  Timer? _statsTimer;

  void _onFrameTimings(List<ui.FrameTiming> timings) {
    for (final timing in timings) {
      _uiMicros.add(timing.buildDuration.inMicroseconds);
      _rasterMicros.add(timing.rasterDuration.inMicroseconds);
      if (_ablationRecording) {
        _ablationUi.add(timing.buildDuration.inMicroseconds);
        _ablationRaster.add(timing.rasterDuration.inMicroseconds);
      }
    }
    if (!kSceneFrameStats) {
      _uiMicros.clear();
      _rasterMicros.clear();
    }
  }

  bool _ablationRecording = false;
  final List<int> _ablationUi = <int>[];
  final List<int> _ablationRaster = <int>[];

  Future<void> _runAblation() async {
    const rounds = 3;
    const settle = Duration(seconds: 4);
    const measure = Duration(seconds: 5);
    double mean(List<int> micros) => micros.isEmpty
        ? double.nan
        : micros.reduce((a, b) => a + b) / micros.length / 1000.0;
    double median(List<double> values) {
      final sorted = List<double>.of(values)..sort();
      return sorted[sorted.length ~/ 2];
    }

    final steps = IslandScene.debugAblationSteps;
    final ui = <String, List<double>>{};
    final raster = <String, List<double>>{};
    final fps = <String, List<double>>{};
    debugPrint('island ablation: ${steps.length} steps x $rounds rounds');
    for (var round = 1; round <= rounds; round++) {
      for (final step in steps) {
        if (!mounted) {
          return;
        }
        await _island.debugAblate(step);
        await Future<void>.delayed(settle);
        _ablationUi.clear();
        _ablationRaster.clear();
        _ablationRecording = true;
        await Future<void>.delayed(measure);
        _ablationRecording = false;
        final u = mean(_ablationUi);
        final r = mean(_ablationRaster);
        final f = _ablationUi.length / measure.inSeconds;
        (ui[step] ??= <double>[]).add(u);
        (raster[step] ??= <double>[]).add(r);
        (fps[step] ??= <double>[]).add(f);
        debugPrint(
          'island ablation: round $round | $step | ui ${u.toStringAsFixed(2)} '
          '| raster ${r.toStringAsFixed(2)} ms | ${f.toStringAsFixed(1)} fps',
        );
      }
    }
    await _island.debugAblate('all on');

    final baseUi = median(ui[steps.first]!);
    final baseRaster = median(raster[steps.first]!);
    debugPrint('island ablation: median of $rounds rounds '
        '(delta vs all on; negative = saves time)');
    for (final step in steps) {
      final u = median(ui[step]!);
      final r = median(raster[step]!);
      String delta(double value, double base) {
        final d = value - base;
        return '${d >= 0 ? '+' : ''}${d.toStringAsFixed(2)}';
      }

      debugPrint(
        'island ablation: ${step.padRight(32)} ui ${u.toStringAsFixed(2)} '
        '(${delta(u, baseUi)}) | raster ${r.toStringAsFixed(2)} '
        '(${delta(r, baseRaster)}) ms | '
        '${median(fps[step]!).toStringAsFixed(1)} fps',
      );
    }
    debugPrint('island ablation: done');
  }

  void _logFrameStats() {
    if (_uiMicros.isEmpty) {
      return;
    }
    String summary(List<int> micros) {
      final sorted = List<int>.of(micros)..sort();
      final avg = sorted.reduce((a, b) => a + b) / sorted.length / 1000.0;
      final p90 = sorted[(sorted.length * 0.9).floor().clamp(0, sorted.length - 1)] / 1000.0;
      final max = sorted.last / 1000.0;
      return 'avg ${avg.toStringAsFixed(2)} p90 ${p90.toStringAsFixed(2)} '
          'max ${max.toStringAsFixed(2)} ms';
    }

    debugPrint(
      'island frames: n=${_uiMicros.length} '
      'ui ${summary(_uiMicros)} | raster ${summary(_rasterMicros)} '
      '| ${_island.quality.name}${_island.isRaining ? ' rain' : ''}'
      '${_island.isRaining && _island.isStorm ? ' storm' : ''}',
    );
    _uiMicros.clear();
    _rasterMicros.clear();
  }

  @override
  void initState() {
    super.initState();
    if (kSceneFrameStats || kSceneAblation) {
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    }
    if (kSceneFrameStats) {
      _statsTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _logFrameStats(),
      );
    }
    WidgetsBinding.instance.addObserver(this);
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      _island.debugLightningHoldSeconds =
          double.tryParse(kSceneLightningHold) ?? 0.0;
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
      final startQuality =
          IslandQuality.values.asNameMap()[kSceneStartQuality];
      if (startQuality != null) {
        await _onQualityChanged(startQuality);
      }
      if (kSceneRain) {
        await _onRainChanged(true);
      }
      if (kSceneAblation) {
        unawaited(_runAblation());
      }
      if (kSceneTour) {
        unawaited(_runTourStep());
        _tourTimer = Timer.periodic(
          const Duration(seconds: 9),
          (_) => unawaited(_runTourStep()),
        );
      }
    } catch (error, stack) {
      debugPrint('island scene failed to load: $error\n$stack');
      if (mounted) {
        setState(() => _error = '$error');
      }
    }
  }

  Future<void> _runTourStep() async {
    final time = _tourTimes[_tourStep % _tourTimes.length];
    final mode = _tourModes[_tourStep % _tourModes.length];
    _tourStep += 1;
    _onTimeChanged(time);
    if (kSceneTourModes) {
      await _onQualityChanged(mode);
    }
    _island.debugFaceKeyLight();
    setState(() {});
    debugPrint('island tour: ${_island.quality.name} at $time h');
  }

  @override
  void dispose() {
    if (kSceneFrameStats || kSceneAblation) {
      SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    }
    _statsTimer?.cancel();
    _autoDemoTimer?.cancel();
    _tourTimer?.cancel();
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
    _island.tick(deltaSeconds, viewportSize: _viewSize);
    _particles.advance(deltaSeconds);
    _frame.value = _frame.value + 1;

    final night = _island.nightBlend;
    if ((night - _nightBlend).abs() > 0.004) {
      setState(() => _nightBlend = night);
    }
  }

  void _openEffectsPanel() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Keep the scene visible and unshaded: the point is to watch it change.
      barrierColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scroll) => _EffectsPanel(
          island: _island,
          scrollController: scroll,
          onChanged: () => setState(() {}),
        ),
      ),
    );
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

  void _onPointerMove(PointerMoveEvent event) {
    if (_island.cameraMode == IslandCameraMode.overTheShoulder &&
        _pointerDownAt != null) {
      _island.rotateOtsCamera(event.delta.dx, event.delta.dy);
    }
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
    setState(() {});
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

  Future<void> _onQualityChanged(IslandQuality quality) async {
    final pending = _island.setQuality(quality);
    // Rebuild now for the Ultra-while-building state, and again when done.
    setState(() {});
    try {
      await pending;
    } catch (error, stack) {
      debugPrint('island scene: could not switch to $quality: $error\n$stack');
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _onRainChanged(bool on) async {
    final pending = _island.setRain(on);
    setState(() {});
    try {
      await pending;
    } catch (error, stack) {
      debugPrint('island scene: could not switch rain $on: $error\n$stack');
    }
    if (mounted) {
      setState(() {});
    }
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
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
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
                    enabled: _renderLoopActive &&
                        _island.cameraMode == IslandCameraMode.orbit,
                    autofocus: false,
                    child: SceneView(
                      _island.scene,
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
            AnimatedOpacity(
              opacity: _uiVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !_uiVisible,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              AnimatedBuilder(
                                animation: _frame,
                                builder: (context, _) {
                                  return _Readout(
                                    triangles: _island.triangleCount,
                                    meshes: _island.meshCount,
                                    timeOfDay: _timeOfDay,
                                    renderLoopActive: _renderLoopActive,
                                    quality: _island.quality,
                                    buildingSuperUltra:
                                        _island.isBuildingSuperUltra,
                                    grassTufts: _island.grassTufts,
                                    rainDrops: _island.rainDrops,
                                    rainHitsPerSecond:
                                        _island.rainHitsPerSecond,
                                    lightningStrikes: _island.lightningStrikes,
                                    campfireLit: _island.campfireLit,
                                    cameraMode: _island.cameraMode,
                                    culledMeshes: _island.culledMeshCount,
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  _ModeSelector(
                                    quality: _island.quality,
                                    building: _island.isBuildingSuperUltra,
                                    onModeChanged: _onQualityChanged,
                                  ),
                                  if (_island.isSuperUltra)
                                    _RainToggle(
                                      raining: _island.isRaining,
                                      preparing: _island.isPreparingRain,
                                      onTap: () => _onRainChanged(
                                        !_island.isRaining,
                                      ),
                                    ),
                                  if (_island.isSuperUltra && _island.isRaining)
                                    _StormToggle(
                                      storm: _island.isStorm,
                                      onTap: () => setState(() {
                                        _island.setStorm(!_island.isStorm);
                                      }),
                                    ),
                                  if (_island.isSuperUltra)
                                    _EffectsButton(
                                      changes: _island.effectsMenuChanges,
                                      onTap: _openEffectsPanel,
                                    ),
                                  _CameraSelector(
                                    cameraMode: _island.cameraMode,
                                    onCameraChanged: (mode) {
                                      setState(() {
                                        _island.setCameraMode(mode);
                                      });
                                    },
                                  ),
                                  _FullscreenButton(
                                    onTap: () {
                                      setState(() {
                                        _uiVisible = false;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _ActionButtons(
                      cameraMode: _island.cameraMode,
                      onToggleCamera: () {
                        setState(() {
                          _island.toggleCameraMode();
                        });
                      },
                      onPunch: () {
                        _island.punch();
                        setState(() {});
                      },
                      onJump: () {
                        _island.jump();
                      },
                      onResetBalls: () {
                        _island.resetBalls();
                        setState(() {});
                      },
                    ),
                    _DayNightSlider(
                      value: _timeOfDay,
                      nightBlend: _nightBlend,
                      onChanged: _onTimeChanged,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _uiVisible ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: _uiVisible,
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: _ExitFullscreenButton(
                        onTap: () {
                          setState(() {
                            _uiVisible = true;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
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

/// Triangle count and mesh count, next to the clock. Real geometry, real
/// numbers, still pinned at full refresh rate — that juxtaposition with the
/// native HUD is the argument the tab exists to make.
class _Readout extends StatelessWidget {
  const _Readout({
    required this.triangles,
    required this.meshes,
    required this.timeOfDay,
    required this.renderLoopActive,
    required this.quality,
    required this.buildingSuperUltra,
    required this.grassTufts,
    required this.rainDrops,
    required this.rainHitsPerSecond,
    required this.lightningStrikes,
    required this.campfireLit,
    required this.cameraMode,
    required this.culledMeshes,
  });

  final int triangles;
  final int meshes;
  final double timeOfDay;
  final bool renderLoopActive;
  final IslandQuality quality;
  final bool buildingSuperUltra;
  final int grassTufts;
  final int rainDrops;
  final double rainHitsPerSecond;
  final int lightningStrikes;
  final bool campfireLit;
  final IslandCameraMode cameraMode;
  final int culledMeshes;

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 10,
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
              Text('$meshes meshes'),
              Text('${_clock(timeOfDay)}  local'),
              const SizedBox(height: 3),
              Text(
                campfireLit
                    ? '🔥 Fire: ON (PointLight)'
                    : '💨 Fire: OFF (tap center)',
                style: TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 11,
                  color: campfireLit
                      ? const Color(0xFFFFB74D)
                      : const Color(0xFF90A4AE),
                ),
              ),
              Text(
                switch (quality) {
                  IslandQuality.normal => '⚡ Mode: Normal (1 ball)',
                  IslandQuality.ultra => buildingSuperUltra
                      ? '💎 Building Super Ultra…'
                      : '🔥 Mode: Ultra (8 balls, extra props)',
                  IslandQuality.superUltra =>
                    '💎 Mode: Super Ultra (${_grouped(grassTufts)} grass)',
                },
                style: TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: switch (quality) {
                    IslandQuality.normal => const Color(0xFF81C784),
                    IslandQuality.ultra => const Color(0xFFFF7043),
                    IslandQuality.superUltra => const Color(0xFF80D8FF),
                  },
                ),
              ),
              if (quality == IslandQuality.superUltra)
                const Text(
                  '   planar sea · god rays · GTAO',
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 11,
                    color: Color(0xFF80D8FF),
                  ),
                ),
              if (quality == IslandQuality.superUltra && rainDrops > 0)
                Text(
                  '🌧 Rain: ${_grouped(rainDrops)} drops · '
                  '${rainHitsPerSecond.round()} hits/s'
                  '${lightningStrikes > 0 ? ' · ⚡$lightningStrikes' : ''}',
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 11,
                    color: Color(0xFFB3E5FC),
                  ),
                ),
              Text(
                cameraMode == IslandCameraMode.overTheShoulder
                    ? '👤 Cam: Shoulder (OTS)'
                    : '🌐 Cam: Orbit (Overview)',
                style: TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 11,
                  color: cameraMode == IslandCameraMode.overTheShoulder
                      ? const Color(0xFFCE93D8)
                      : const Color(0xFF90CAF9),
                ),
              ),
              if (cameraMode == IslandCameraMode.overTheShoulder)
                Text(
                  '👁️ View culling: $culledMeshes off-screen',
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 11,
                    color: Color(0xFF80DEEA),
                  ),
                ),
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
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.quality,
    required this.building,
    required this.onModeChanged,
  });

  final IslandQuality quality;
  final bool building;
  final ValueChanged<IslandQuality> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _PillTab(
              label: '⚡ Normal',
              active: quality == IslandQuality.normal,
              activeColor: const Color(0xFF2E7D32),
              onTap: () => onModeChanged(IslandQuality.normal),
            ),
            const SizedBox(width: 4),
            _PillTab(
              label: '🔥 Ultra',
              active: quality == IslandQuality.ultra && !building,
              activeColor: const Color(0xFFE65100),
              onTap: () => onModeChanged(IslandQuality.ultra),
            ),
            const SizedBox(width: 4),
            _PillTab(
              label: building ? '💎 Super…' : '💎 Super',
              active: quality == IslandQuality.superUltra || building,
              activeColor: const Color(0xFF0277BD),
              onTap: () => onModeChanged(IslandQuality.superUltra),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  const _PillTab({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.88)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Menlo',
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraSelector extends StatelessWidget {
  const _CameraSelector({
    required this.cameraMode,
    required this.onCameraChanged,
  });

  final IslandCameraMode cameraMode;
  final ValueChanged<IslandCameraMode> onCameraChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _PillTab(
              label: '🌐 Orbit',
              active: cameraMode == IslandCameraMode.orbit,
              activeColor: const Color(0xFF1565C0),
              onTap: () => onCameraChanged(IslandCameraMode.orbit),
            ),
            const SizedBox(width: 4),
            _PillTab(
              label: '👤 Shoulder',
              active: cameraMode == IslandCameraMode.overTheShoulder,
              activeColor: const Color(0xFF6A1B9A),
              onTap: () => onCameraChanged(IslandCameraMode.overTheShoulder),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rain on/off, shown only in Super Ultra. Off unmounts the whole effect, so
/// it doubles as the way to take rain out of a performance reading.
class _RainToggle extends StatelessWidget {
  const _RainToggle({
    required this.raining,
    required this.preparing,
    required this.onTap,
  });

  final bool raining;
  final bool preparing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: _PillTab(
          label: preparing ? '🌧 Rain…' : (raining ? '🌧 Rain: on' : '🌧 Rain: off'),
          active: raining,
          activeColor: const Color(0xFF455A64),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Lightning on/off while it rains. Off keeps the rain and removes all
/// flashing.
class _StormToggle extends StatelessWidget {
  const _StormToggle({required this.storm, required this.onTap});

  final bool storm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: _PillTab(
          label: storm ? '⚡ Storm: on' : '⚡ Storm: off',
          active: storm,
          activeColor: const Color(0xFF5E35B1),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Opens the Super Ultra effects menu; shows how many entries differ from
/// their default.
class _EffectsButton extends StatelessWidget {
  const _EffectsButton({required this.changes, required this.onTap});

  final int changes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: _PillTab(
          label: changes == 0 ? '🎛 Effects' : '🎛 Effects: $changes changed',
          active: changes > 0,
          activeColor: const Color(0xFFBF360C),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Switches for every Super Ultra effect, with the live frame times above
/// them, so each effect's cost can be read off the device as it is toggled.
class _EffectsPanel extends StatefulWidget {
  const _EffectsPanel({
    required this.island,
    required this.scrollController,
    required this.onChanged,
  });

  final IslandScene island;
  final ScrollController scrollController;
  final VoidCallback onChanged;

  @override
  State<_EffectsPanel> createState() => _EffectsPanelState();
}

class _EffectsPanelState extends State<_EffectsPanel> {
  /// (vsync start, UI, raster) per frame, in microseconds.
  final List<(int, int, int)> _frames = <(int, int, int)>[];
  Timer? _refresh;
  String _readout = 'measuring…';

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _refresh = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _updateReadout(),
    );
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _refresh?.cancel();
    super.dispose();
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    for (final timing in timings) {
      _frames.add((
        timing.timestampInMicroseconds(ui.FramePhase.vsyncStart),
        timing.buildDuration.inMicroseconds,
        timing.rasterDuration.inMicroseconds,
      ));
    }
  }

  /// Averages over the last two seconds of frames.
  void _updateReadout() {
    if (_frames.isEmpty) {
      return;
    }
    final newest = _frames.last.$1;
    _frames.removeWhere((frame) => frame.$1 < newest - 2000000);
    final count = _frames.length;
    final span = (newest - _frames.first.$1) / 1e6;
    final uiMs =
        _frames.fold<int>(0, (sum, frame) => sum + frame.$2) / count / 1000;
    final rasterMs =
        _frames.fold<int>(0, (sum, frame) => sum + frame.$3) / count / 1000;
    final fps = span > 0 ? (count - 1) / span : 0.0;
    setState(() {
      _readout = 'UI ${uiMs.toStringAsFixed(1)} ms · '
          'raster ${rasterMs.toStringAsFixed(1)} ms · '
          '${fps.toStringAsFixed(0)} fps';
    });
  }

  /// Applies [change] to the island, then repaints the panel and the HUD.
  void _change(VoidCallback change) {
    setState(change);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final island = widget.island;
    const white = TextStyle(color: Colors.white);
    Widget header(String label) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 2),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
        );
    // A Material, not a DecoratedBox: the switch rows paint their ink on the
    // nearest Material, which a coloured DecoratedBox would cover.
    return Material(
      color: Colors.black.withValues(alpha: 0.82),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: <Widget>[
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Super Ultra effects',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _change(island.resetEffects),
                child: const Text('Reset'),
              ),
            ],
          ),
          Text(
            _readout,
            style: const TextStyle(
              color: Color(0xFF80CBC4),
              fontFamily: 'monospace',
              fontSize: 15,
            ),
          ),
          Text(
            !kDebugMode
                ? 'Last 2 s. Give each switch a few seconds to settle.'
                : 'Debug build: these times are not representative. '
                      'Run with --profile.',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          header('Image quality'),
          _EffectsPicker<SuperUltraAntiAliasing>(
            title: 'Anti-aliasing',
            options: SuperUltraAntiAliasing.values,
            selected: island.antiAliasing,
            label: (aa) => aa.label,
            cost: (aa) => aa.cost,
            onSelected: (aa) => _change(() => island.setAntiAliasing(aa)),
          ),
          _EffectsPicker<SuperUltraRenderScale>(
            title: 'Render scale',
            options: SuperUltraRenderScale.values,
            selected: island.renderScale,
            label: (scale) => scale.label,
            cost: (scale) => scale.cost,
            onSelected: (scale) => _change(() => island.setRenderScale(scale)),
          ),
          for (final group in SuperUltraEffectGroup.values) ...<Widget>[
            header(group.label),
            for (final effect in SuperUltraEffect.values)
              if (effect.group == group)
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: island.isEffectOn(effect),
                  // Greyed out while the effect it needs is off.
                  onChanged: effect.needs == null ||
                          island.isEffectOn(effect.needs!)
                      ? (on) => _change(() => island.setEffect(effect, on))
                      : null,
                  title: Text(effect.label, style: white),
                  subtitle: Text(
                    effect.cost,
                    style: const TextStyle(color: Colors.white60),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

/// One row of exclusive picks in the effects menu, with the picked option's
/// cost under it.
class _EffectsPicker<T> extends StatelessWidget {
  const _EffectsPicker({
    required this.title,
    required this.options,
    required this.selected,
    required this.label,
    required this.cost,
    required this.onSelected,
  });

  final String title;
  final List<T> options;
  final T selected;
  final String Function(T option) label;
  final String Function(T option) cost;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: <Widget>[
                  for (final option in options)
                    _PillTab(
                      label: label(option),
                      active: option == selected,
                      activeColor: const Color(0xFF00897B),
                      onTap: () => onSelected(option),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            cost(selected),
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FullscreenButton extends StatelessWidget {
  const _FullscreenButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: _PillTab(
          label: '🎬 Fullscreen',
          active: false,
          activeColor: const Color(0xFF37474F),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _ExitFullscreenButton extends StatelessWidget {
  const _ExitFullscreenButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: _PillTab(
          label: '👁️ Show UI',
          active: true,
          activeColor: const Color(0xFF0288D1),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.cameraMode,
    required this.onToggleCamera,
    required this.onPunch,
    required this.onJump,
    required this.onResetBalls,
  });

  final IslandCameraMode cameraMode;
  final VoidCallback onToggleCamera;
  final VoidCallback onPunch;
  final VoidCallback onJump;
  final VoidCallback onResetBalls;

  @override
  Widget build(BuildContext context) {
    final isOts = cameraMode == IslandCameraMode.overTheShoulder;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 18, 76),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _ActionButton(
                label: isOts ? '🌐 Orbit' : '👤 Cam',
                color: isOts
                    ? const Color(0xFF1565C0)
                    : const Color(0xFF6A1B9A),
                onTap: onToggleCamera,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                label: '⚽ Reset',
                color: const Color(0xFF37474F),
                onTap: onResetBalls,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                label: '🦘 Jump',
                color: const Color(0xFF00695C),
                onTap: onJump,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                label: '🥊 Punch',
                color: const Color(0xFFC2185B),
                onTap: onPunch,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
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
