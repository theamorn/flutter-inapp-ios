import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter vs Native Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const PerformanceComparisonPage(),
    );
  }
}

class PerformanceComparisonPage extends StatefulWidget {
  const PerformanceComparisonPage({super.key});

  @override
  State<PerformanceComparisonPage> createState() =>
      _PerformanceComparisonPageState();
}

class _PerformanceComparisonPageState extends State<PerformanceComparisonPage>
    with TickerProviderStateMixin {
  static const platform = MethodChannel('com.theamorn.camera');
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _performanceData = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _openFlutterCamera() async {
    setState(() => _isLoading = true);

    // Simulate performance measurement
    final stopwatch = Stopwatch()..start();

    // Navigate to Flutter camera page
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FlutterCameraPage()),
    );

    stopwatch.stop();
    setState(() {
      _isLoading = false;
      _performanceData =
          'Flutter Camera Launch: ${stopwatch.elapsedMilliseconds}ms';
    });
  }

  Future<void> _openNativeCamera() async {
    setState(() => _isLoading = true);

    try {
      final stopwatch = Stopwatch()..start();

      // Call native iOS camera
      await platform.invokeMethod('openNativeCamera');

      stopwatch.stop();
      setState(() {
        _isLoading = false;
        _performanceData =
            'Native Camera Launch: ${stopwatch.elapsedMilliseconds}ms';
      });
    } on PlatformException catch (e) {
      setState(() {
        _isLoading = false;
        _performanceData = "Failed to open native camera: '${e.message}'";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // Header Section
                    Icon(
                      Icons.speed,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Performance Comparison',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Compare camera performance between\nFlutter and Native iOS implementation',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 60),

                    // Comparison Cards
                    Column(
                      children: [
                        // Flutter Card
                        _buildComparisonCard(
                          context: context,
                          title: '📱 Flutter Camera',
                          subtitle: 'Cross-platform camera implementation',
                          description:
                              'Uses Flutter\'s camera plugin with Dart/Flutter rendering pipeline',
                          buttonText: 'Open Flutter Camera',
                          buttonColor: Colors.blue,
                          buttonIcon: Icons.flutter_dash,
                          onPressed: _openFlutterCamera,
                          pros: [
                            'Cross-platform',
                            'Consistent UI',
                            'Hot reload',
                          ],
                          cons: ['Bridge overhead', 'Plugin dependency'],
                        ),

                        const SizedBox(height: 24),

                        // VS Divider
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'VS',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Native Card
                        _buildComparisonCard(
                          context: context,
                          title: '🍎 Native iOS Camera',
                          subtitle: 'Pure UIKit implementation',
                          description:
                              'Uses native AVFoundation and UIKit for optimal performance',
                          buttonText: 'Open Native Camera',
                          buttonColor: Colors.orange,
                          buttonIcon: Icons.phone_iphone,
                          onPressed: _openNativeCamera,
                          pros: [
                            'Best performance',
                            'Native features',
                            'Direct APIs',
                          ],
                          cons: ['Platform specific', 'More complexity'],
                        ),
                      ],
                    ),

                    // Performance Results
                    if (_performanceData.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.analytics,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Performance Result',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _performanceData,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                    if (_isLoading)
                      Container(
                        margin: const EdgeInsets.only(top: 24),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Measuring performance...',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
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

  Widget _buildComparisonCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String description,
    required String buttonText,
    required Color buttonColor,
    required IconData buttonIcon,
    required VoidCallback onPressed,
    required List<String> pros,
    required List<String> cons,
  }) {
    return Card(
      elevation: 8,
      shadowColor: buttonColor.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),

            // Pros and Cons
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✅ Pros:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      ...pros.map(
                        (pro) => Text(
                          '• $pro',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚠️ Cons:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      ...cons.map(
                        (con) => Text(
                          '• $con',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPressed,
                icon: Icon(buttonIcon),
                label: Text(buttonText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Flutter Camera Page
class FlutterCameraPage extends StatelessWidget {
  const FlutterCameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Camera'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.withOpacity(0.1), Colors.white],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, size: 100, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                'Flutter Camera Implementation',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'This would use the camera plugin\nfor cross-platform camera access',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Comparison'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
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
    );
  }
}
