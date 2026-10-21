import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'holo_card_game.dart';
import 'promo_host_link.dart';

/// Route entry point for the host's `/promo` engine: the inline badge tile in
/// the middle of the native Shop page.
class HoloPromoApp extends StatefulWidget {
  const HoloPromoApp({super.key});

  @override
  State<HoloPromoApp> createState() => _HoloPromoAppState();
}

class _HoloPromoAppState extends State<HoloPromoApp> {
  late final HoloCardGame _game = HoloCardGame(
    onClaim: (code) => _link.claim(code),
    onBadgeBounds: (bounds, seconds) =>
        _link.reportBadgeBounds(bounds, seconds),
  );
  late final PromoHostLink _link = PromoHostLink(
    onVisibility: (visible) => _game.hostVisible = visible,
    onScroll: _game.hostScrolled,
  );

  @override
  void initState() {
    super.initState();
    _link.attach();
    _link.ready().then((state) {
      if (state == null || !mounted) return;
      _game.hostVisible = state.visible;
      _game.hostScrolled(state.progress, 0);
    });
  }

  @override
  void dispose() {
    _link.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Native dispatch already selected this app. Build a single home route.
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(builder: _buildHome),
      ],
      debugShowCheckedModeBanner: false,
      onGenerateRoute: (settings) =>
          MaterialPageRoute<void>(settings: settings, builder: _buildHome),
    );
  }

  Widget _buildHome(BuildContext context) {
    // The tile sits mid-page, so system insets never apply to it.
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      removeLeft: true,
      removeRight: true,
      child: ColoredBox(
        color: HoloCardGame.backdropColor,
        child: GameWidget<HoloCardGame>(game: _game),
      ),
    );
  }
}
