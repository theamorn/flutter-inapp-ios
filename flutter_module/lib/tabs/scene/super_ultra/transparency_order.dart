/// Draw order for the campfire's translucent stack, and the glow-card
/// comparison that comes with it.
///
/// flutter_scene 0.24 sorts translucent draws by `Node.renderOrder`
/// (ascending) within a pass, then by depth. The order only holds inside one
/// pass: it cannot move a draw into another pass. Here the core glow draws
/// first so the heat haze's scene-colour snapshot already holds it (the haze
/// then shimmers the glow), and the smoke last. The smoke keeps depth
/// testing, so foreground geometry still hides it; ordering never forces it
/// on top of everything.
///
/// Pure (no GPU): unit-tested.
library;

/// The layers of the campfire's translucent stack that get an explicit rank.
enum FireStackLayer { core, haze, smoke }

abstract final class TransparencyOrderValues {
  static const double core = -20;
  static const double haze = -10;
  static const double smoke = 0;

  static const Map<FireStackLayer, double> byLayer = {
    FireStackLayer.core: core,
    FireStackLayer.haze: haze,
    FireStackLayer.smoke: smoke,
  };
}

/// Sets render orders on targets and puts each authored value back once.
class RenderOrderLedger<T extends Object> {
  RenderOrderLedger({required this.read, required this.write});

  final double Function(T target) read;
  final void Function(T target, double order) write;
  final Map<T, double> _authored = {};

  /// Gives each target its rank. A target applied earlier keeps its first
  /// authored value; one no longer in [ranks] gets its authored value back.
  void apply(Map<T, double> ranks) {
    for (final target in _authored.keys.toList()) {
      if (!ranks.containsKey(target)) write(target, _authored.remove(target)!);
    }
    ranks.forEach((target, rank) {
      _authored.putIfAbsent(target, () => read(target));
      write(target, rank);
    });
  }

  /// Every target back to its authored value; the ledger is empty after.
  void restore() => apply(const {});
}

/// The fire's core glow: the camera-facing additive card, or the previous
/// additive sprite emitter.
enum CoreGlowMode {
  card,
  sprite;

  static const CoreGlowMode initial = CoreGlowMode.card;
}

/// Which of the two core glows show for [mode]: exactly one, never both.
({bool card, bool sprite}) coreGlowVisibility(CoreGlowMode mode) =>
    (card: mode == CoreGlowMode.card, sprite: mode == CoreGlowMode.sprite);
