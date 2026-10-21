import 'package:flutter_module/tabs/scene/xray.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('modes cycle off → wireframe → normals → base colour → off', () {
    var m = XrayMode.off;
    final seen = <XrayMode>[];
    for (var i = 0; i < 4; i++) {
      m = m.next;
      seen.add(m);
    }
    expect(seen, [
      XrayMode.wireframe,
      XrayMode.normals,
      XrayMode.baseColor,
      XrayMode.off,
    ]);
  });

  test('the wipe sweeps 0.15..0.85 and back every 4 s', () {
    expect(xraySplit(0), closeTo(0.15, 1e-9));
    expect(xraySplit(2), closeTo(0.85, 1e-9));
    expect(xraySplit(4), closeTo(0.15, 1e-9));
    for (var t = 0.0; t < 8; t += 0.1) {
      expect(xraySplit(t), inInclusiveRange(0.15, 0.85));
    }
  });
}
