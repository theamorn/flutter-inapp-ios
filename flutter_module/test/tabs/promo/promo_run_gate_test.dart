import 'dart:ui';

import 'package:flutter_module/tabs/promo/promo_run_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PromoRunGate', () {
    late List<bool> changes;
    late PromoRunGate gate;

    setUp(() {
      changes = [];
      gate = PromoRunGate(onChanged: changes.add);
    });

    test('starts running without announcing it', () {
      expect(gate.shouldRun, isTrue);
      expect(changes, isEmpty);
    });

    test('pauses when the host scrolls the tile away', () {
      gate.hostVisible = false;

      expect(gate.shouldRun, isFalse);
      expect(changes, [false]);
    });

    test('pauses when the app leaves the foreground', () {
      gate.lifecycle = AppLifecycleState.paused;

      expect(changes, [false]);
    });

    test('treats inactive as still in the foreground', () {
      gate.lifecycle = AppLifecycleState.inactive;

      expect(gate.shouldRun, isTrue);
      expect(changes, isEmpty);
    });

    test('treats hidden as background', () {
      gate.lifecycle = AppLifecycleState.hidden;

      expect(gate.shouldRun, isFalse);
    });

    test('stays paused on resume while the tile is off screen', () {
      gate.hostVisible = false;
      gate.lifecycle = AppLifecycleState.paused;
      gate.lifecycle = AppLifecycleState.resumed;

      expect(gate.shouldRun, isFalse);
      expect(changes, [false]);
    });

    test('runs again only when both allow it', () {
      gate.hostVisible = false;
      gate.lifecycle = AppLifecycleState.paused;
      gate.hostVisible = true;
      gate.lifecycle = AppLifecycleState.resumed;

      expect(gate.shouldRun, isTrue);
      expect(changes, [false, true]);
    });

    test('does not repeat itself', () {
      gate.hostVisible = true;
      gate.lifecycle = AppLifecycleState.resumed;
      gate.hostVisible = false;
      gate.hostVisible = false;

      expect(changes, [false]);
    });
  });
}
