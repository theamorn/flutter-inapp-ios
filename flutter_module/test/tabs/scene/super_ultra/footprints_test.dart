import 'package:flutter_module/tabs/scene/super_ultra/footprints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standing still lays nothing', () {
    final t = FootprintTrail();
    for (var i = 0; i < 100; i++) {
      t.update(1 / 60, 0, 0, 0);
    }
    expect(t.prints, isEmpty);
  });

  test('one print per stride, alternating feet', () {
    final t = FootprintTrail(stride: 0.5);
    for (var i = 1; i <= 60; i++) {
      t.update(1 / 60, i * 0.05, 0, 0); // 3 m in a straight line
    }
    expect(t.prints.length, 6);
    for (var i = 1; i < t.prints.length; i++) {
      expect(t.prints[i].left, isNot(t.prints[i - 1].left));
    }
  });

  test('never more than capacity; the oldest goes first', () {
    final t = FootprintTrail(capacity: 12, stride: 0.5);
    for (var i = 1; i <= 600; i++) {
      t.update(1 / 60, i * 0.05, 0, 0); // 30 m
    }
    expect(t.prints.length, 12);
    expect(t.prints.first.x, lessThan(t.prints.last.x));
  });

  test('prints fade out over their lifetime and are dropped', () {
    final t = FootprintTrail(lifetime: 2);
    t.update(1 / 60, 0.0, 0, 0);
    t.update(1 / 60, 1.0, 0, 0);
    expect(t.prints, isNotEmpty);
    expect(t.prints.first.fade, closeTo(1, 0.05));
    for (var i = 0; i < 180; i++) {
      t.update(1 / 60, 1.0, 0, 0);
    }
    expect(t.prints, isEmpty);
  });
}
