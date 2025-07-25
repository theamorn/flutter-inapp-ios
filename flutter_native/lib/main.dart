import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

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

    // Navigate to Flutter camera page and get the actual timing result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FlutterCameraPage()),
    );

    setState(() {
      _isLoading = false;
      if (result != null && result is Map<String, dynamic>) {
        _performanceData = 'Flutter Camera: ${result['firstFrameTime']}ms (First Frame)';
      } else {
        _performanceData = 'Flutter Camera: Navigation completed';
      }
    });
  }

  Future<void> _openNativeCamera() async {
    setState(() => _isLoading = true);

    try {
      // Call native iOS camera and get the actual timing result
      final result = await platform.invokeMethod('openNativeCamera');

      setState(() {
        _isLoading = false;
        if (result != null && result is Map<Object?, Object?>) {
          final firstFrameTime = result['firstFrameTime'] as int?;
          if (firstFrameTime != null) {
            _performanceData = 'Native Camera: ${firstFrameTime}ms (First Frame)';
          } else {
            _performanceData = 'Native Camera: Completed';
          }
        } else {
          _performanceData = 'Native Camera: Completed';
        }
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
class FlutterCameraPage extends StatefulWidget {
  const FlutterCameraPage({super.key});

  @override
  State<FlutterCameraPage> createState() => _FlutterCameraPageState();
}

class _FlutterCameraPageState extends State<FlutterCameraPage> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isLoading = true;
  String? _error;
  DateTime? _startTime;
  bool _isFirstFrameRendered = false;
  int? _firstFrameTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera permission
      final status = await Permission.camera.request();
      print('Camera permission status: $status');
      
      if (status == PermissionStatus.denied) {
        setState(() {
          _error = 'Camera permission denied. Please enable camera access in Settings.';
          _isLoading = false;
        });
        return;
      }
      
      if (status == PermissionStatus.permanentlyDenied) {
        setState(() {
          _error = 'Camera permission permanently denied. Please enable camera access in Settings > Privacy & Security > Camera.';
          _isLoading = false;
        });
        return;
      }
      
      if (status != PermissionStatus.granted) {
        setState(() {
          _error = 'Camera permission not granted. Status: $status';
          _isLoading = false;
        });
        return;
      }

      // Get available cameras
      cameras = await availableCameras();
      print('Available cameras: ${cameras?.length ?? 0}');
      
      if (cameras == null || cameras!.isEmpty) {
        setState(() {
          _error = 'No cameras found';
          _isLoading = false;
        });
        return;
      }

      // Initialize camera controller
      _controller = CameraController(
        cameras![0], // Use first camera (usually back camera)
        ResolutionPreset.max,
        enableAudio: false,
      );

      await _controller!.initialize();
      print('Camera initialized successfully');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Use post frame callback to ensure the camera preview is actually rendered
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isFirstFrameRendered) {
            // Add a small delay to ensure the preview is actually showing
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && !_isFirstFrameRendered) {
                setState(() {
                  _isFirstFrameRendered = true;
                });
                final elapsed = DateTime.now().difference(_startTime!).inMilliseconds;
                _firstFrameTime = elapsed;
                print('Flutter Camera First Frame: ${elapsed}ms');
              }
            });
          }
        });
      }
    } catch (e) {
      print('Camera initialization error: $e');
      setState(() {
        _error = 'Failed to initialize camera: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Picture saved: ${image.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking picture: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    if (cameras == null || cameras!.length < 2) return;

    try {
      final currentCameraIndex = cameras!.indexOf(_controller!.description);
      final newCameraIndex = (currentCameraIndex + 1) % cameras!.length;
      
      await _controller!.dispose();
      
      _controller = CameraController(
        cameras![newCameraIndex],
        ResolutionPreset.ultraHigh,
        enableAudio: false,
      );

      await _controller!.initialize();
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching camera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Flutter Camera'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, {
              'firstFrameTime': _firstFrameTime,
              'isFirstFrameRendered': _isFirstFrameRendered,
            });
          },
        ),
        actions: [
          if (cameras != null && cameras!.length > 1)
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(Icons.flip_camera_ios),
              tooltip: 'Switch Camera',
            ),
        ],
      ),
      body: _buildCameraBody(),
    );
  }

  Widget _buildCameraBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _initializeCamera,
                    child: const Text('Retry'),
                  ),
                  if (_error!.contains('permission'))
                    const SizedBox(width: 16),
                  if (_error!.contains('permission'))
                    ElevatedButton(
                      onPressed: () => openAppSettings(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      child: const Text('Open Settings'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera not ready',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Stack(
      children: [
        // Camera Preview
        Positioned.fill(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: CameraPreview(_controller!),
          ),
        ),
        
        // Camera Controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery button placeholder
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.photo_library,
                      color: Colors.white,
                    ),
                  ),
                  
                  // Capture button
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.blue,
                          width: 4,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.blue,
                        size: 32,
                      ),
                    ),
                  ),
                  
                  // Settings button placeholder
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.settings,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Camera info overlay
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _isFirstFrameRendered 
                ? 'Flutter Camera Preview\nFirst Frame: ${_firstFrameTime}ms\nResolution: ${_controller!.value.previewSize?.width.toInt() ?? 'Unknown'}x${_controller!.value.previewSize?.height.toInt() ?? 'Unknown'}'
                : 'Flutter Camera Preview\nInitializing camera preview...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
