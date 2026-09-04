// THROWAWAY SPIKE CODE — 01-scene-spike.md
//
// Purpose: prove flutter_scene renders inside an add-to-app engine spawned
// from a FlutterEngineGroup, in release, on a physical device.
//
// DO NOT import this from tab code. 06-island-scene.md rewrites this from
// scratch. Delete this file once the spike's findings are recorded.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

class SpikeSceneApp extends StatelessWidget {
  const SpikeSceneApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SpikeSceneScreen(),
      );
}

class SpikeSceneScreen extends StatefulWidget {
  const SpikeSceneScreen({super.key});

  @override
  State<SpikeSceneScreen> createState() => _SpikeSceneScreenState();
}

class _SpikeSceneScreenState extends State<SpikeSceneScreen>
    with SingleTickerProviderStateMixin {
  final Scene scene = Scene();
  late final Ticker _ticker;
  final PhysicalSkySource _sky = PhysicalSkySource();

  double _elapsed = 0;
  // 0 = built-in geometry only, 1 = imported .glb also on screen.
  String _status = 'initializing';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      setState(() => _elapsed = d.inMicroseconds / 1e6);
    })
      ..start();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await Scene.initializeStaticResources();

      // Built-in geometry: exercises the Flutter GPU path with no assets.
      scene.add(
        Node(
          mesh: Mesh(
            CuboidGeometry(vm.Vector3(1, 1, 1)),
            PhysicallyBasedMaterial(),
          ),
        )..position = vm.Vector3(-1.2, 0, 0),
      );

      // Sun + sky + IBL, all driven off one sky source. This is the exact
      // arrangement 06 needs for day->night; the spike proves it links up.
      scene.skybox = Skybox(_sky);
      scene.skyEnvironment = SkyEnvironment(_sky);
      scene.sunLight = SunLight(_sky, castsShadow: true);

      setState(() {
        _ready = true;
        _status = 'built-in geometry ok';
      });

      // Asset pipeline: the build hook converted assets/models/spike_box.glb
      // into flutter_scene_generated/ at build time. Loaded by source path.
      final model = await loadScene('assets/models/spike_box.glb');
      scene.add(model..position = vm.Vector3(1.2, 0, 0));
      setState(() => _status = 'built-in geometry + imported .glb ok');
    } catch (e) {
      setState(() => _status = 'FAILED: $e');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sweep the sun so the day->night claim is visible, not inferred.
    final t = _elapsed * 0.4;
    _sky.sunDirection = vm.Vector3(math.cos(t), math.sin(t) * 0.8 + 0.15, 0.4)
      ..normalize();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_ready)
            SceneView(
              scene,
              camera: PerspectiveCamera(position: vm.Vector3(0, 1.5, -5)),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'SPIKE 01\n$_status',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Menlo',
                  shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
