import 'package:flutter_scene/build_hooks.dart';
// `hooks` is a dev_dependency: this file runs at build time, never at
// runtime. The lint does not recognise hook/ as a dev directory yet.
// ignore: depend_on_referenced_packages
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
// flutter_scene:init:start
    // Import .glb and .fscene sources under assets/, loadable by source path
    // with loadScene (and hot-reloadable). A no-op when there are no scenes.
    buildScenes(buildInput: input, buildOutput: output);
    // Compile .fmat materials under assets/, loadable by source path with
    // loadFmatMaterial (and hot-reloadable). A no-op when there are none.
    await buildMaterials(buildInput: input, buildOutput: output);
// flutter_scene:init:end
  });
}
