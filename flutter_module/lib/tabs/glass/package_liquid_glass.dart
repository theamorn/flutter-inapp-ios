import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart' as lgr;

/// View powered by the `liquid_glass_renderer` pub package.
///
/// Demonstrates the package's multi-pass SDF renderer, superellipse geometry,
/// background blur, light direction controls, and built-in `FakeGlass` fallback.
class PackageLiquidGlassView extends StatefulWidget {
  const PackageLiquidGlassView({
    required this.dayNight,
    required this.child,
    required this.onDayNightChanged,
    this.showControls = true,
    super.key,
  });

  final double dayNight;
  final Widget child;
  final ValueChanged<double> onDayNightChanged;
  final bool showControls;

  @override
  State<PackageLiquidGlassView> createState() => _PackageLiquidGlassViewState();
}

class _PackageLiquidGlassViewState extends State<PackageLiquidGlassView> {
  double _thickness = 0.55; // 0..1 -> 0..35 in settings
  double _blur = 10.0; // 0..24
  double _lightAngle = 0.75 * math.pi; // 0..2*pi
  bool _useFakeGlass = false;
  bool _showBlendGroup = false;

  @override
  Widget build(BuildContext context) {
    final textColor = Color.lerp(
      const Color(0xFF102C42),
      const Color(0xFFF8FAFF),
      widget.dayNight,
    )!;

    final glassColor = Color.lerp(
      Colors.white.withValues(alpha: 0.18),
      const Color(0xFF131D36).withValues(alpha: 0.38),
      widget.dayNight,
    )!;

    final settings = lgr.LiquidGlassSettings(
      thickness: _thickness * 35.0,
      blur: _blur,
      glassColor: glassColor,
      lightAngle: _lightAngle,
      lightIntensity: 1.45,
      ambientStrength: 0.3,
      chromaticAberration: 0.05,
      refractiveIndex: 1.25,
      saturation: 1.25,
    );

    final shadowColor = Color.lerp(
      const Color(0x420E4972),
      const Color(0xA8000618),
      widget.dayNight,
    )!;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 34,
            spreadRadius: -8,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.13),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Live background content beneath the glass layer
            widget.child,

            // 2. Liquid Glass Layer
            // If controls are hidden, wrap in IgnorePointer so 100% of gestures
            // scroll the list directly beneath the glass without any obstruction.
            IgnorePointer(
              ignoring: !widget.showControls,
              child: lgr.LiquidGlassLayer(
                fake: _useFakeGlass,
                settings: settings,
                child: _showBlendGroup
                    ? _buildBlendGroupDemo(textColor)
                    : _buildSinglePanel(textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSinglePanel(Color textColor) {
    return lgr.LiquidGlass(
      shape: const lgr.LiquidRoundedSuperellipse(borderRadius: 30),
      child: widget.showControls
          ? Align(
              alignment: Alignment.bottomCenter,
              child: _CompactPackageControls(
                dayNight: widget.dayNight,
                thickness: _thickness,
                blur: _blur,
                lightAngle: _lightAngle,
                useFakeGlass: _useFakeGlass,
                showBlendGroup: _showBlendGroup,
                textColor: textColor,
                onDayNightChanged: widget.onDayNightChanged,
                onThicknessChanged: (v) => setState(() => _thickness = v),
                onBlurChanged: (v) => setState(() => _blur = v),
                onLightAngleChanged: (v) => setState(() => _lightAngle = v),
                onFakeGlassToggled: (v) => setState(() => _useFakeGlass = v),
                onBlendGroupToggled: (v) => setState(() => _showBlendGroup = v),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildBlendGroupDemo(Color textColor) {
    return lgr.LiquidGlassBlendGroup(
      blend: 28.0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Floating metaball droplet 1
          Positioned(
            top: 70,
            left: 24,
            child: lgr.LiquidGlass.grouped(
              shape: const lgr.LiquidOval(),
              child: Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
          // Floating metaball droplet 2 (blends with droplet 1)
          Positioned(
            top: 86,
            left: 74,
            child: lgr.LiquidGlass.grouped(
              shape: const lgr.LiquidRoundedSuperellipse(borderRadius: 22),
              child: Container(
                width: 82,
                height: 82,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.bubble_chart_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          // Main control surface docked at the bottom
          if (widget.showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: lgr.LiquidGlass.grouped(
                shape: const lgr.LiquidRoundedSuperellipse(borderRadius: 30),
                child: _CompactPackageControls(
                  dayNight: widget.dayNight,
                  thickness: _thickness,
                  blur: _blur,
                  lightAngle: _lightAngle,
                  useFakeGlass: _useFakeGlass,
                  showBlendGroup: _showBlendGroup,
                  textColor: textColor,
                  onDayNightChanged: widget.onDayNightChanged,
                  onThicknessChanged: (v) => setState(() => _thickness = v),
                  onBlurChanged: (v) => setState(() => _blur = v),
                  onLightAngleChanged: (v) => setState(() => _lightAngle = v),
                  onFakeGlassToggled: (v) => setState(() => _useFakeGlass = v),
                  onBlendGroupToggled: (v) => setState(() => _showBlendGroup = v),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact bottom controls overlay that leaves the upper area free for scrolling.
class _CompactPackageControls extends StatelessWidget {
  const _CompactPackageControls({
    required this.dayNight,
    required this.thickness,
    required this.blur,
    required this.lightAngle,
    required this.useFakeGlass,
    required this.showBlendGroup,
    required this.textColor,
    required this.onDayNightChanged,
    required this.onThicknessChanged,
    required this.onBlurChanged,
    required this.onLightAngleChanged,
    required this.onFakeGlassToggled,
    required this.onBlendGroupToggled,
  });

  final double dayNight;
  final double thickness;
  final double blur;
  final double lightAngle;
  final bool useFakeGlass;
  final bool showBlendGroup;
  final Color textColor;
  final ValueChanged<double> onDayNightChanged;
  final ValueChanged<double> onThicknessChanged;
  final ValueChanged<double> onBlurChanged;
  final ValueChanged<double> onLightAngleChanged;
  final ValueChanged<bool> onFakeGlassToggled;
  final ValueChanged<bool> onBlendGroupToggled;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Color.lerp(
          Colors.white.withValues(alpha: 0.28),
          const Color(0xFF0F1A30).withValues(alpha: 0.65),
          dayNight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with status & toggles
          Row(
            children: [
              Icon(Icons.layers_rounded, color: textColor, size: 14),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: useFakeGlass
                      ? const Color(0xFFFFA028).withValues(alpha: 0.2)
                      : const Color(0xFF388BFD).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  useFakeGlass ? 'FALLBACK' : 'IMPELLER',
                  style: TextStyle(
                    color: useFakeGlass
                        ? const Color(0xFFFFA028)
                        : const Color(0xFF58A6FF),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              _FeatureChip(
                label: 'FakeGlass',
                active: useFakeGlass,
                textColor: textColor,
                key: const ValueKey('pkg-toggle-fake-glass'),
                onTap: () => onFakeGlassToggled(!useFakeGlass),
              ),
              const SizedBox(width: 5),
              _FeatureChip(
                label: 'Blend',
                active: showBlendGroup,
                textColor: textColor,
                key: const ValueKey('pkg-toggle-blend-group'),
                onTap: () => onBlendGroupToggled(!showBlendGroup),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Compact sliders
          _CompactSliderRow(
            label: 'DAY / NIGHT',
            valueLabel: dayNight < 0.5 ? 'DAY' : 'NIGHT',
            value: dayNight,
            icon: dayNight < 0.5
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            textColor: textColor,
            key: const ValueKey('pkg-day-night'),
            onChanged: onDayNightChanged,
          ),
          _CompactSliderRow(
            label: 'REFRACTION',
            valueLabel: '${(thickness * 100).round()}%',
            value: thickness,
            icon: Icons.blur_linear_rounded,
            textColor: textColor,
            key: const ValueKey('pkg-thickness'),
            onChanged: onThicknessChanged,
          ),
          _CompactSliderRow(
            label: 'BLUR',
            valueLabel: '${blur.round()}px',
            value: blur / 24.0,
            icon: Icons.blur_on_rounded,
            textColor: textColor,
            key: const ValueKey('pkg-blur'),
            onChanged: (v) => onBlurChanged(v * 24.0),
          ),
          _CompactSliderRow(
            label: 'LIGHT',
            valueLabel: '${(lightAngle * 180 / math.pi).round()}°',
            value: lightAngle / (2 * math.pi),
            icon: Icons.wb_twilight_rounded,
            textColor: textColor,
            key: const ValueKey('pkg-light-angle'),
            onChanged: (v) => onLightAngleChanged(v * 2 * math.pi),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.label,
    required this.active,
    required this.textColor,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool active;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: active
              ? textColor.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? textColor.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? textColor : textColor.withValues(alpha: 0.6),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _CompactSliderRow extends StatelessWidget {
  const _CompactSliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.icon,
    required this.textColor,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String valueLabel;
  final double value;
  final IconData icon;
  final Color textColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0.0, 1.0);
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Icon(icon, color: textColor.withValues(alpha: 0.72), size: 14),
          const SizedBox(width: 6),
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.76),
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: clampedValue,
              onChanged: onChanged,
              activeColor: textColor,
              inactiveColor: textColor.withValues(alpha: 0.2),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              valueLabel,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: textColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
