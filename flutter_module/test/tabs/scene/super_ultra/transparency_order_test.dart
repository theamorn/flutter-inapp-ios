import 'dart:io';

import 'package:flutter_module/tabs/scene/super_ultra/super_ultra_effects.dart';
import 'package:flutter_module/tabs/scene/super_ultra/transparency_order.dart';
import 'package:flutter_test/flutter_test.dart';

class _Item {
  _Item(this.name, this.order);
  final String name;
  double order;
}

void main() {
  group('TransparencyOrderValues', () {
    test('glow draws before the haze, the haze before the smoke', () {
      expect(TransparencyOrderValues.core, -20);
      expect(TransparencyOrderValues.haze, -10);
      expect(TransparencyOrderValues.smoke, 0);
      expect(TransparencyOrderValues.core, lessThan(TransparencyOrderValues.haze));
      expect(TransparencyOrderValues.haze, lessThan(TransparencyOrderValues.smoke));
    });

    test('no two layers of the fire stack share a rank', () {
      final ranks = TransparencyOrderValues.byLayer.values.toList();
      expect(ranks.toSet(), hasLength(ranks.length));
      expect(TransparencyOrderValues.byLayer.keys.toSet(), FireStackLayer.values.toSet());
    });
  });

  group('RenderOrderLedger', () {
    test('applies the ranks and restores the authored values once', () {
      final core = _Item('core', 0), haze = _Item('haze', 3), smoke = _Item('smoke', 0);
      final ledger = RenderOrderLedger<_Item>(
        read: (i) => i.order,
        write: (i, v) => i.order = v,
      );
      ledger.apply({core: -20, haze: -10, smoke: 0});
      expect([core.order, haze.order, smoke.order], [-20, -10, 0]);
      ledger.restore();
      expect([core.order, haze.order, smoke.order], [0, 3, 0]);
      haze.order = 7; // someone else's later change
      ledger.restore();
      expect(haze.order, 7, reason: 'restore runs once per apply');
    });

    test('a second apply keeps the first authored value', () {
      final haze = _Item('haze', 3);
      final ledger = RenderOrderLedger<_Item>(
        read: (i) => i.order,
        write: (i, v) => i.order = v,
      );
      ledger
        ..apply({haze: -10})
        ..apply({haze: -10});
      ledger.restore();
      expect(haze.order, 3);
    });

    test('a target dropped from the set is restored', () {
      final core = _Item('core', 0), card = _Item('card', 0);
      final ledger = RenderOrderLedger<_Item>(
        read: (i) => i.order,
        write: (i, v) => i.order = v,
      );
      ledger.apply({core: -20});
      ledger.apply({card: -20});
      expect(core.order, 0);
      expect(card.order, -20);
    });
  });

  group('comparisons', () {
    test('the core glow is the card or the sprite, never both', () {
      for (final mode in CoreGlowMode.values) {
        final shown = coreGlowVisibility(mode);
        expect(shown.card != shown.sprite, isTrue, reason: '$mode');
      }
      expect(CoreGlowMode.initial, CoreGlowMode.card);
      expect(coreGlowVisibility(CoreGlowMode.card).card, isTrue);
      expect(coreGlowVisibility(CoreGlowMode.sprite).sprite, isTrue);
    });

    test('the effects menu offers the glow comparison in scene content', () {
      expect(SuperUltraEffect.glowCard.group, SuperUltraEffectGroup.scene);
    });

    test('covered grass is not offered (engine cutout pre-draw has no UVs)', () {
      expect(SuperUltraEffect.values.map((e) => e.name), isNot(contains('grassCoverage')));
      expect(File('assets/materials/grass_coverage.fmat').existsSync(), isFalse);
    });
  });
}
