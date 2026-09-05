import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_module/tabs/scene/particles.dart';

void main() {
  test('spawns the requested number of motes inside the field', () {
    final field = ParticleField(count: 40);
    expect(field.motes, hasLength(40));
    for (final mote in field.motes) {
      expect(mote.x, inInclusiveRange(0, 1));
      expect(mote.y, inInclusiveRange(0, 1));
    }
  });

  test('motes stay in the field however long it runs', () {
    final field = ParticleField(count: 40);
    for (var i = 0; i < 4000; i++) {
      field.advance(1 / 60);
    }
    expect(field.motes, hasLength(40));
    for (final mote in field.motes) {
      expect(mote.x, inInclusiveRange(-0.06, 1.06));
      expect(mote.y, inInclusiveRange(-0.06, 1.06));
    }
  });

  test('a long stall does not fling the field apart', () {
    final field = ParticleField(count: 20);
    final before = field.motes.map((m) => m.y).toList();
    // 30 seconds of stopped render loop arriving as one delta: clamped to
    // 100ms, so at most 0.1 * maxDrift of movement.
    field.advance(30);
    for (var i = 0; i < before.length; i++) {
      expect((field.motes[i].y - before[i]).abs(), lessThan(0.01));
    }
  });

  test('a zero or negative delta is a no-op', () {
    final field = ParticleField(count: 5);
    final before = field.motes.map((m) => m.y).toList();
    field.advance(0);
    field.advance(-1);
    for (var i = 0; i < before.length; i++) {
      expect(field.motes[i].y, before[i]);
    }
  });

  test('the same seed gives the same field', () {
    final a = ParticleField(count: 12, seed: 7);
    final b = ParticleField(count: 12, seed: 7);
    for (var i = 0; i < 12; i++) {
      expect(a.motes[i].x, b.motes[i].x);
      expect(a.motes[i].size, b.motes[i].size);
    }
  });
}
