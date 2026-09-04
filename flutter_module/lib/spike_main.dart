// Standalone entrypoint for the spike scene — 01-scene-spike.md.
//
// Kept deliberately: this is how you iterate on 3D work with hot reload,
// without Xcode or the host app. The simulator DOES run Impeller on Metal,
// so Flutter GPU works here:
//
//   fvm flutter run -t lib/spike_main.dart --enable-flutter-gpu
//
// Simulator and debug-mode results are fine for building. They are NOT
// evidence for any performance claim in the talk — that needs release mode
// on a physical device, through the host app.
import 'package:flutter/material.dart';
import 'package:flutter_module/spike_scene.dart';

void main() => runApp(const SpikeSceneApp());
