import 'package:flutter/material.dart';
import 'package:flutter_module/tabs/glass/glass_app.dart';
import 'package:flutter_module/tabs/glass/liquid_glass.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('liquid glass renders its live sampler and controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await ShaderBuilder.precacheShader('shaders/liquid_glass.glsl');
    await tester.pumpWidget(const LiquidGlassApp());
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byType(LiquidGlass), findsOneWidget);
    expect(find.byType(AnimatedSampler), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));
    expect(find.byKey(const ValueKey('glass-day-night')), findsOneWidget);
    expect(find.byKey(const ValueKey('glass-refraction')), findsOneWidget);
    expect(find.byKey(const ValueKey('glass-thickness')), findsOneWidget);

    final before = tester
        .widget<Slider>(
          find.descendant(
            of: find.byKey(const ValueKey('glass-refraction')),
            matching: find.byType(Slider),
          ),
        )
        .value;
    await tester.drag(
      find.descendant(
        of: find.byKey(const ValueKey('glass-refraction')),
        matching: find.byType(Slider),
      ),
      const Offset(-80, 0),
    );
    await tester.pump(const Duration(milliseconds: 20));

    final after = tester
        .widget<Slider>(
          find.descendant(
            of: find.byKey(const ValueKey('glass-refraction')),
            matching: find.byType(Slider),
          ),
        )
        .value;
    expect(after, lessThan(before));
    expect(tester.takeException(), isNull);
  });
}
