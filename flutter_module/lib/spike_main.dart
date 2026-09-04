// Standalone entrypoint for the spike scene — 01-scene-spike.md.
//
// Kept deliberately: this is how you iterate on 3D work with hot reload,
// without Xcode or the host app. The simulator DOES run Impeller on Metal,
// so Flutter GPU works here:
//
//   fvm flutter run -t lib/spike_main.dart --enable-flutter-gpu
//
// ⚠️  READ THIS BEFORE YOU RUN THAT COMMAND ⚠️
//
// `flutter run -t <file>` writes FLUTTER_TARGET into the module's generated
// config (.ios/Flutter/Generated.xcconfig and flutter_export_environment.sh).
// cool-ios's Xcode build sources that file. So after running any alternate
// entrypoint, EVERY Flutter tab in the host app silently builds this file
// instead of lib/main.dart — tab 3 stops being Flappy Cat and becomes the 3D
// spike, with no error anywhere. It already happened once.
//
// Undo it before building the host app again:
//
//   cd flutter_module && fvm flutter build ios --config-only
//
// Then confirm:
//
//   grep FLUTTER_TARGET flutter_module/.ios/Flutter/Generated.xcconfig
//   # must read lib/main.dart
//
// Simulator and debug-mode results are fine for building. They are NOT
// evidence for any performance claim in the talk — that needs release mode
// on a physical device, through the host app.
import 'package:flutter/material.dart';
import 'package:flutter_module/spike_scene.dart';

void main() => runApp(const SpikeSceneApp());
