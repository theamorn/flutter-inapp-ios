import 'package:flutter/material.dart';

import 'liquid_glass.dart';
import 'package_liquid_glass.dart';

/// Supported glass render modes in Tab 4.
enum GlassRenderMode {
  customShader,
  packageRenderer,
}

/// Route entry point for the native host's `/glass` engine.
class LiquidGlassApp extends StatelessWidget {
  const LiquidGlassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Native dispatch already selected this app. Build a single home route.
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(builder: (_) => const _GlassDemoScreen()),
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        sliderTheme: const SliderThemeData(
          trackHeight: 3,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
        ),
      ),
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const _GlassDemoScreen(),
      ),
    );
  }
}

class _GlassDemoScreen extends StatefulWidget {
  const _GlassDemoScreen();

  @override
  State<_GlassDemoScreen> createState() => _GlassDemoScreenState();
}

class _GlassDemoScreenState extends State<_GlassDemoScreen> {
  GlassRenderMode _renderMode = GlassRenderMode.customShader;
  bool _showControls = true;
  double _dayNight = 0.2;
  double _refraction = 0.68;
  double _thickness = 0.58;

  @override
  Widget build(BuildContext context) {
    final topColor = Color.lerp(
      const Color(0xFF88D8F7),
      const Color(0xFF071227),
      _dayNight,
    )!;
    final bottomColor = Color.lerp(
      const Color(0xFFD9F4F0),
      const Color(0xFF21163D),
      _dayNight,
    )!;
    final foreground = Color.lerp(
      const Color(0xFF0B2940),
      const Color(0xFFF5F8FF),
      Curves.easeIn.transform(_dayNight),
    )!;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [topColor, bottomColor],
          ),
        ),
        child: Stack(
          children: [
            _AmbientOrbs(dayNight: _dayNight),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Atmosphere',
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(
                                      color: foreground,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1.1,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Live widgets, sampled through a touchable glass surface',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: foreground.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ControlsVisibilityToggle(
                          showControls: _showControls,
                          foregroundColor: foreground,
                          dayNight: _dayNight,
                          key: const ValueKey('toggle-controls-visibility'),
                          onToggle: () => setState(() => _showControls = !_showControls),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _GlassModeSelector(
                      selectedMode: _renderMode,
                      foregroundColor: foreground,
                      dayNight: _dayNight,
                      onModeSelected: (mode) => setState(() => _renderMode = mode),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: _renderMode == GlassRenderMode.customShader
                              ? LiquidGlass(
                                  dayNight: _dayNight,
                                  refractionStrength: _refraction,
                                  thickness: _thickness,
                                  overlay: _showControls
                                      ? Align(
                                          alignment: Alignment.bottomCenter,
                                          child: _GlassControls(
                                            dayNight: _dayNight,
                                            refraction: _refraction,
                                            thickness: _thickness,
                                            onDayNightChanged: (value) {
                                              setState(() => _dayNight = value);
                                            },
                                            onRefractionChanged: (value) {
                                              setState(() => _refraction = value);
                                            },
                                            onThicknessChanged: (value) {
                                              setState(() => _thickness = value);
                                            },
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                  child: _LiveBackdropFeed(dayNight: _dayNight),
                                )
                              : PackageLiquidGlassView(
                                  dayNight: _dayNight,
                                  showControls: _showControls,
                                  onDayNightChanged: (value) {
                                    setState(() => _dayNight = value);
                                  },
                                  child: _LiveBackdropFeed(dayNight: _dayNight),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientOrbs extends StatelessWidget {
  const _AmbientOrbs({required this.dayNight});

  final double dayNight;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -55,
            child: _Orb(
              size: 220,
              color: Color.lerp(
                const Color(0xA0FFF4A8),
                const Color(0x704D5FFF),
                dayNight,
              )!,
            ),
          ),
          Positioned(
            left: -90,
            bottom: 80,
            child: _Orb(
              size: 250,
              color: Color.lerp(
                const Color(0x8052E5D2),
                const Color(0x705E2B9D),
                dayNight,
              )!,
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _LiveBackdropFeed extends StatelessWidget {
  const _LiveBackdropFeed({required this.dayNight});

  final double dayNight;

  static const _items = [
    _FeedItem(
      Icons.wb_sunny_rounded,
      'Golden hour',
      '18 minutes remaining',
      '24°',
      Color(0xFFFFA928),
    ),
    _FeedItem(
      Icons.air_rounded,
      'West terrace',
      'Breeze from the river',
      '12 km/h',
      Color(0xFF25BFD4),
    ),
    _FeedItem(
      Icons.water_drop_rounded,
      'Humidity',
      'Comfortable and steady',
      '58%',
      Color(0xFF3977F6),
    ),
    _FeedItem(
      Icons.spa_rounded,
      'Garden room',
      'Plants watered today',
      '8 / 8',
      Color(0xFF25B66B),
    ),
    _FeedItem(
      Icons.lightbulb_rounded,
      'Living room',
      'Adaptive lighting active',
      '42%',
      Color(0xFFFFB526),
    ),
    _FeedItem(
      Icons.bedtime_rounded,
      'Evening scene',
      'Ready at sunset',
      '4 actions',
      Color(0xFF7856D8),
    ),
    _FeedItem(
      Icons.graphic_eq_rounded,
      'Now playing',
      'Low Tide · Cobalt Coast',
      '3:18',
      Color(0xFFEA567A),
    ),
    _FeedItem(
      Icons.battery_charging_full_rounded,
      'Energy',
      'Below weekly average',
      '−12%',
      Color(0xFF15A889),
    ),
    _FeedItem(
      Icons.calendar_month_rounded,
      'Tomorrow',
      'Clear skies until noon',
      '27°',
      Color(0xFFEE7048),
    ),
    _FeedItem(
      Icons.auto_awesome_rounded,
      'Night routine',
      'Six rooms prepared',
      'Ready',
      Color(0xFF526DDC),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final listBackground = Color.lerp(
      const Color(0xB7E5F5F4),
      const Color(0xC10B1530),
      dayNight,
    )!;
    final labelColor = Color.lerp(
      const Color(0xFF173649),
      const Color(0xFFF4F7FF),
      dayNight,
    )!;

    return ColoredBox(
      color: listBackground,
      child: ListView.builder(
        key: const PageStorageKey('liquid-glass-live-feed'),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(14, 62, 14, 250),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return _FeedCard(
            item: item,
            labelColor: labelColor,
            dayNight: dayNight,
            index: index,
          );
        },
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.item,
    required this.labelColor,
    required this.dayNight,
    required this.index,
  });

  final _FeedItem item;
  final Color labelColor;
  final double dayNight;
  final int index;

  @override
  Widget build(BuildContext context) {
    final cardColor = Color.lerp(
      Colors.white.withValues(alpha: 0.82),
      const Color(0xFF202A49).withValues(alpha: 0.88),
      dayNight,
    )!;

    return Container(
      height: index.isEven ? 96 : 82,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: item.color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(item.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor.withValues(alpha: 0.63),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            item.value,
            style: TextStyle(
              color: item.color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassControls extends StatelessWidget {
  const _GlassControls({
    required this.dayNight,
    required this.refraction,
    required this.thickness,
    required this.onDayNightChanged,
    required this.onRefractionChanged,
    required this.onThicknessChanged,
  });

  final double dayNight;
  final double refraction;
  final double thickness;
  final ValueChanged<double> onDayNightChanged;
  final ValueChanged<double> onRefractionChanged;
  final ValueChanged<double> onThicknessChanged;

  @override
  Widget build(BuildContext context) {
    final textColor = Color.lerp(
      const Color(0xFF102C42),
      const Color(0xFFF8FAFF),
      dayNight,
    )!;

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
          Row(
            children: [
              Icon(Icons.blur_on_rounded, color: textColor, size: 15),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'CONTROLS',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF30D985).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'RIPPLES',
                  style: TextStyle(
                    color: Color(0xFF17A866),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _ControlRow(
            label: 'DAY / NIGHT',
            valueLabel: dayNight < 0.5 ? 'DAY' : 'NIGHT',
            value: dayNight,
            icon: dayNight < 0.5
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            textColor: textColor,
            key: const ValueKey('glass-day-night'),
            onChanged: onDayNightChanged,
          ),
          _ControlRow(
            label: 'REFRACTION',
            valueLabel: '${(refraction * 100).round()}%',
            value: refraction,
            icon: Icons.waves_rounded,
            textColor: textColor,
            key: const ValueKey('glass-refraction'),
            onChanged: onRefractionChanged,
          ),
          _ControlRow(
            label: 'THICKNESS',
            valueLabel: '${(thickness * 100).round()}%',
            value: thickness,
            icon: Icons.layers_rounded,
            textColor: textColor,
            key: const ValueKey('glass-thickness'),
            onChanged: onThicknessChanged,
          ),
        ],
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
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

class _ControlsVisibilityToggle extends StatelessWidget {
  const _ControlsVisibilityToggle({
    required this.showControls,
    required this.foregroundColor,
    required this.dayNight,
    required this.onToggle,
    super.key,
  });

  final bool showControls;
  final Color foregroundColor;
  final double dayNight;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final activeBg = Color.lerp(
      Colors.white.withValues(alpha: 0.5),
      const Color(0xFF283556).withValues(alpha: 0.75),
      dayNight,
    )!;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: showControls ? activeBg : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: showControls
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              showControls
                  ? Icons.visibility_off_rounded
                  : Icons.tune_rounded,
              size: 15,
              color: foregroundColor,
            ),
            const SizedBox(width: 5),
            Text(
              showControls ? 'Hide Controls' : 'Show Controls',
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedItem {
  const _FeedItem(this.icon, this.title, this.subtitle, this.value, this.color);

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final Color color;
}

class _GlassModeSelector extends StatelessWidget {
  const _GlassModeSelector({
    required this.selectedMode,
    required this.foregroundColor,
    required this.dayNight,
    required this.onModeSelected,
  });

  final GlassRenderMode selectedMode;
  final Color foregroundColor;
  final double dayNight;
  final ValueChanged<GlassRenderMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    final containerBg = Color.lerp(
      Colors.white.withValues(alpha: 0.35),
      const Color(0xFF0F182B).withValues(alpha: 0.55),
      dayNight,
    )!;

    final borderColor = Color.lerp(
      Colors.white.withValues(alpha: 0.6),
      Colors.white.withValues(alpha: 0.15),
      dayNight,
    )!;

    return Container(
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _ModeTabButton(
              title: 'Custom Shader',
              badge: 'IN-HOUSE',
              icon: Icons.code_rounded,
              isSelected: selectedMode == GlassRenderMode.customShader,
              foregroundColor: foregroundColor,
              dayNight: dayNight,
              key: const ValueKey('tab-custom-shader'),
              onTap: () => onModeSelected(GlassRenderMode.customShader),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ModeTabButton(
              title: 'liquid_glass_renderer',
              badge: 'PACKAGE',
              icon: Icons.layers_rounded,
              isSelected: selectedMode == GlassRenderMode.packageRenderer,
              foregroundColor: foregroundColor,
              dayNight: dayNight,
              key: const ValueKey('tab-package-renderer'),
              onTap: () => onModeSelected(GlassRenderMode.packageRenderer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    required this.title,
    required this.badge,
    required this.icon,
    required this.isSelected,
    required this.foregroundColor,
    required this.dayNight,
    required this.onTap,
    super.key,
  });

  final String title;
  final String badge;
  final IconData icon;
  final bool isSelected;
  final Color foregroundColor;
  final double dayNight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeBg = Color.lerp(
      Colors.white.withValues(alpha: 0.85),
      const Color(0xFF283556).withValues(alpha: 0.95),
      dayNight,
    )!;

    final badgeColor = isSelected
        ? (dayNight < 0.5 ? const Color(0xFF0C5686) : const Color(0xFF75B8FF))
        : foregroundColor.withValues(alpha: 0.5);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? foregroundColor
                  : foregroundColor.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? foregroundColor
                      : foregroundColor.withValues(alpha: 0.65),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? badgeColor.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

