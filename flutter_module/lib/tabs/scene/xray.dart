/// The presenter's X-ray button: flutter_scene 0.24 surface debug views.
/// A wipe runs across the island with the lit image on one side and the
/// chosen channel (or a wireframe over the lit image) on the other, the
/// clearest live proof that this is a real scene graph.
library;

import 'dart:math' as math;

enum XrayMode {
  off('🔍 X-ray'),
  wireframe('🔍 Wireframe'),
  normals('🔍 Normals'),
  baseColor('🔍 Base colour');

  const XrayMode(this.label);

  final String label;

  XrayMode get next => XrayMode.values[(index + 1) % XrayMode.values.length];
}

/// Wipe position for `Scene.debug.split`: eases 0.15 → 0.85 → 0.15 every 4 s.
double xraySplit(double seconds) =>
    0.5 - 0.35 * math.cos(seconds * 2 * math.pi / 4.0);
