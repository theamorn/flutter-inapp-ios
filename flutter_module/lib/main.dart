import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_module/app_screen.dart';
import 'package:flutter_module/game_screen.dart';
import 'package:flutter_module/shader_screen.dart';
import 'package:flutter_module/tabs/game/game_app.dart';
import 'package:flutter_module/tabs/promo/promo_app.dart';
import 'package:flutter_module/tabs/scene/scene_app.dart';
import 'package:flutter_module/tabs/glass/glass_app.dart';
import 'package:flutter_module/telemetry/frame_telemetry.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final route = PlatformDispatcher.instance.defaultRouteName;
  if (route == '/game' ||
      route == '/glass' ||
      route == '/promo' ||
      route == '/scene') {
    FrameTelemetryReporter(route).start();
  }

  runApp(switch (route) {
    '/game' => const FlappyCatApp(),
    '/glass' => const LiquidGlassApp(),
    '/promo' => const HoloPromoApp(),
    '/scene' => const IslandSceneApp(),
    _ => const MyApp(),
  });
}

class HybridFeaturePlaceholderApp extends StatelessWidget {
  const HybridFeaturePlaceholderApp({
    required this.title,
    required this.icon,
    super.key,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72),
              const SizedBox(height: 20),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('Feature module coming next'),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static bool _showPerformanceOverlay = false;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      showPerformanceOverlay: _showPerformanceOverlay,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      ),
      home: MyHomePage(
        title: 'Flutter Effects Demo',
        onTogglePerformanceOverlay: () {
          setState(() {
            _showPerformanceOverlay = !_showPerformanceOverlay;
          });
        },
        showPerformanceOverlay: _showPerformanceOverlay,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.onTogglePerformanceOverlay,
    required this.showPerformanceOverlay,
  });

  final String title;
  final VoidCallback onTogglePerformanceOverlay;
  final bool showPerformanceOverlay;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const platform = MethodChannel('com.theamorn.flutter');

  @override
  void initState() {
    super.initState();
    _receiveDataFromNative();
  }

  int _counter = 0;
  String dataFromNative = "";

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  Future<void> _receiveDataFromNative() async {
    try {
      // Listening for data passed from the native side
      platform.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'passValueFromNative':
            final data = call.arguments as String;
            setState(() {
              dataFromNative = data;
            });
            break;
          default:
            break;
        }
      });
    } on PlatformException catch (e) {
      setState(() {
        dataFromNative = "Failed to receive data: '${e.message}'";
      });
    }
  }

  Future<void> _sendDataToNative(int value) async {
    try {
      await platform.invokeMethod('getValueFromFlutter', value);
    } catch (e) {
      debugPrint("Failed to get value: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: widget.onTogglePerformanceOverlay,
            icon: Icon(
              widget.showPerformanceOverlay
                  ? Icons.speed
                  : Icons.speed_outlined,
              color: widget.showPerformanceOverlay ? Colors.green : null,
            ),
            tooltip: widget.showPerformanceOverlay
                ? 'Hide Performance Overlay'
                : 'Show Performance Overlay',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Counter Section
                Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.touch_app,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Counter',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_counter',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            debugPrint(
                              "Button pressed and send data to native: $_counter",
                            );
                            _sendDataToNative(_counter);
                          },
                          icon: const Icon(Icons.send),
                          label: const Text("Send to Native"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Navigation Section
                Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          '🎨 Visual Effects',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),

                        // Shader Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ShaderScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.water_drop),
                            label: const Text("Water & Sky Shaders"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Game Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const GameScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.games),
                            label: const Text("Rain Effects & Game"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // App Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AppScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.animation),
                            label: const Text("Animated Lists"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Native Communication Section
                if (dataFromNative.isNotEmpty)
                  Card(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.phone_android,
                            size: 48,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Native Communication',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dataFromNative,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontFamily: 'monospace'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _incrementCounter,
        tooltip: 'Increment Counter',
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}
