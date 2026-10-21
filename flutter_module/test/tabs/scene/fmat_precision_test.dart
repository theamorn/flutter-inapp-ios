import 'dart:io';

// The engine's own .fmat compiler (pure Dart, no GPU).
// ignore: implementation_imports
import 'package:flutter_scene/src/fmat/fmat.dart';
import 'package:flutter_test/flutter_test.dart';

/// flutter_scene 0.24 compiles material fragments at mediump; on Mali, Adreno
/// and the web that is half precision. Our materials compute positions,
/// phases and hashes, so every body opts back into float32
/// (shaders/PRECISION.md in the package).
void main() {
  final files = Directory('assets/materials')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.fmat'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('there are materials to check', () => expect(files, isNotEmpty));

  for (final file in files) {
    test('${file.path} opts its body into highp and still compiles', () {
      final source = file.readAsStringSync();
      // The material's own source, not the compiled GLSL: engine includes may
      // carry their own precision lines and would pass this vacuously.
      final body = source.substring(
        source.indexOf(RegExp(r'^(fragment|sky) \{', multiLine: true)),
      );
      expect(body, contains('precision highp float;'));
      final compiled = compileFmat(source, fileName: file.path);
      expect(compiled.glsl, contains('precision highp float;'));
    });
  }
}
