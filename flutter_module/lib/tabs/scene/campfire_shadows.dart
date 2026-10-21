/// The campfire's point-light shadow (flutter_scene 0.24 point shadows: six
/// cube faces in the shared shadow atlas). Only Ultra and Super Ultra pay
/// for it; Super Ultra's effects menu can switch it off to price it.
library;

/// Physical size of the fire, so glints on the props widen to the flames and
/// the shadow edge softens.
const double kCampfireLightRadius = 0.25;

/// Per cube face. The fire lights a 14 m circle; 512 keeps its shadows soft
/// and cheap.
const int kCampfireShadowResolution = 512;

/// The fire sits 0.45 m up in a ring of stones; start the shadow frustum
/// just outside the flame.
const double kCampfireShadowNear = 0.1;

/// Whether the campfire casts its point-light shadow. Never while
/// [godRaysOn]: flutter_scene 0.24's god-ray pass reads the shared shadow
/// atlas as if it held only the sun's cascades, so the fire's two cube tiles
/// shift every lookup it makes and the march finds sunlight everywhere (a
/// flat glow around the sun, no shafts).
bool campfireCastsShadow({
  required bool ultraOrAbove,
  required bool effectOn,
  bool godRaysOn = false,
}) =>
    ultraOrAbove && effectOn && !godRaysOn;
