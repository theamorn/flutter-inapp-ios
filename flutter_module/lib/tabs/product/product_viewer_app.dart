import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:flutter_module/tabs/product/product_scene.dart';
import 'package:flutter_module/tabs/scene/render/prewarm.dart';
import 'package:flutter_module/tabs/shared/host_visibility_link.dart';

/// Route `/product`: the 3D header at the top of the native Shop page.
///
/// The host owns the page: the title, price, and scrolling around this view
/// are native. Flutter draws the headphones and owns every drag that starts
/// on the header (the host hands those over, see `ProductScrollView` on iOS
/// and the touch gate in `InlineFlutterTile.kt`).
class ProductViewerApp extends StatelessWidget {
  const ProductViewerApp({super.key});

  static const channelName = 'com.theamorn.hybrid/product';

  /// The native hero's gradient (systemIndigo → systemPurple), so swapping
  /// the SF Symbol for the model changes nothing else on the page.
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5856D6), Color(0xFFAF52DE)],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // One route only: a second initial route would mount a second scene.
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(builder: (_) => const ProductViewer()),
      ],
      // Without a route generator MaterialApp builds no Navigator at all.
      // Never reached in practice: nothing pushes a named route.
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

class ProductViewer extends StatefulWidget {
  const ProductViewer({super.key});

  @override
  State<ProductViewer> createState() => _ProductViewerState();
}

class _ProductViewerState extends State<ProductViewer>
    with WidgetsBindingObserver {
  final ProductScene _product = ProductScene();
  final HostVisibilityLink _host = HostVisibilityLink(
    ProductViewerApp.channelName,
  );
  bool _appActive = true;
  Object? _error;

  bool get _rendering => _host.visible.value && _appActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _host.visible.addListener(_onVisibilityChanged);
    _host.attach();
    _product.load().then(
      (_) {
        if (mounted) setState(() {});
      },
      onError: (Object error) {
        debugPrint('product scene: load failed: $error');
        if (mounted) setState(() => _error = error);
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _host.visible.removeListener(_onVisibilityChanged);
    _host.detach();
    _product.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (active == _appActive) return;
    _appActive = active;
    _onVisibilityChanged();
  }

  void _onVisibilityChanged() {
    // Logged, not just applied: the only proof the header stopped rendering
    // is from a moment it cannot be seen.
    debugPrint(
      'product scene: render loop ${_rendering ? "resumed" : "stopped"}',
    );
    if (!_rendering) releaseSceneTargets();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ProductViewerApp.gradient),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_error != null) return const _StaticFallback();
          if (!_product.loaded) return const SizedBox.expand();
          final height = constraints.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => _product.dragStart(),
            onPanUpdate: (details) =>
                _product.dragUpdate(details.delta, height),
            onPanEnd: (details) =>
                _product.dragEnd(details.velocity.pixelsPerSecond, height),
            onPanCancel: () => _product.dragEnd(Offset.zero, height),
            // TickerMode, not `SceneView(autoTick:)`: toggling autoTick
            // recreates the view's ticker and throws when the view returns
            // (FLUTTER-3D-PLAYBOOK.md §2).
            child: TickerMode(
              enabled: _rendering,
              child: SceneView(
                _product.scene,
                onTick: (_, dt) => _product.tick(dt),
                warmUp: true,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shown only if the model fails to load: the header the page had before.
class _StaticFallback extends StatelessWidget {
  const _StaticFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.headphones, size: 96, color: Colors.white),
    );
  }
}
