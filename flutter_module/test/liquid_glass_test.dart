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

  testWidgets('can toggle between custom shader and liquid_glass_renderer tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 750);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await ShaderBuilder.precacheShader('shaders/liquid_glass.glsl');
    await tester.pumpWidget(const LiquidGlassApp());
    await tester.pump(const Duration(milliseconds: 20));

    // Initially custom shader tab is selected
    expect(find.byKey(const ValueKey('tab-custom-shader')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-package-renderer')), findsOneWidget);
    expect(find.byType(LiquidGlass), findsOneWidget);

    // Tap to switch to liquid_glass_renderer package tab
    await tester.tap(find.byKey(const ValueKey('tab-package-renderer')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // Package view controls should now be visible
    expect(find.byKey(const ValueKey('pkg-day-night')), findsOneWidget);
    expect(find.byKey(const ValueKey('pkg-thickness')), findsOneWidget);
    expect(find.byKey(const ValueKey('pkg-blur')), findsOneWidget);
    expect(find.byKey(const ValueKey('pkg-light-angle')), findsOneWidget);
    expect(find.byKey(const ValueKey('pkg-toggle-fake-glass')), findsOneWidget);
    expect(find.byKey(const ValueKey('pkg-toggle-blend-group')), findsOneWidget);

    // Toggle FakeGlass fallback switch
    await tester.tap(find.byKey(const ValueKey('pkg-toggle-fake-glass')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('FALLBACK'), findsOneWidget);

    // Toggle Metaball Blend switch
    await tester.tap(find.byKey(const ValueKey('pkg-toggle-blend-group')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byIcon(Icons.bubble_chart_rounded), findsOneWidget);

    // Tap back to custom shader tab
    await tester.tap(find.byKey(const ValueKey('tab-custom-shader')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(LiquidGlass), findsOneWidget);
    expect(find.byType(AnimatedSampler), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('can hide and show controls using visibility toggle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 750);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await ShaderBuilder.precacheShader('shaders/liquid_glass.glsl');
    await tester.pumpWidget(const LiquidGlassApp());
    await tester.pump(const Duration(milliseconds: 20));

    // Initially controls are visible
    expect(find.byKey(const ValueKey('toggle-controls-visibility')), findsOneWidget);
    expect(find.text('Hide Controls'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));

    // Tap toggle to hide controls
    await tester.tap(find.byKey(const ValueKey('toggle-controls-visibility')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // Controls should now be hidden
    expect(find.text('Show Controls'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);

    // Tap toggle again to restore controls
    await tester.tap(find.byKey(const ValueKey('toggle-controls-visibility')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Hide Controls'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
