import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_module/tabs/reviews/reviews_data.dart';
import 'package:flutter_module/tabs/shared/host_visibility_link.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// Route `/reviews`: the "Review Details" tab of the native Shop page, drawn
/// entirely by Flutter with iOS 27 Liquid Glass from `liquid_glass_renderer`.
///
/// The same pixels on Android: that is the point. Review cards scroll in
/// Flutter under one glass layer that holds the rating summary, the filter
/// chips, and the "Write a review" button. The host pins its native tab bar
/// above this view and owns the page scroll; this view owns its own list.
class ReviewDetailsApp extends StatelessWidget {
  const ReviewDetailsApp({super.key});

  static const channelName = 'com.theamorn.hybrid/reviews';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: _Palette.blue),
        scaffoldBackgroundColor: _Palette.groupedBackground,
      ),
      // Native dispatch already chose this app: one route, whatever its name.
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(builder: (_) => const ReviewDetailsScreen()),
      ],
      // Without a route generator MaterialApp builds no Navigator at all.
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const ReviewDetailsScreen(),
      ),
    );
  }
}

/// iOS system colors, so the Flutter tab sits seamlessly on the native page.
abstract final class _Palette {
  static const groupedBackground = Color(0xFFF2F2F7);
  static const label = Color(0xFF1C1C1E);
  static const secondaryLabel = Color(0x993C3C43);
  static const separator = Color(0x333C3C43);
  static const blue = Color(0xFF0A84FF);
  static const orange = Color(0xFFFF9500);
  static const indigo = Color(0xFF5856D6);
  static const purple = Color(0xFFAF52DE);
  static const pink = Color(0xFFFF2D55);
  static const teal = Color(0xFF30B0C7);
}

enum ReviewFilter {
  all('All'),
  five('5 ★'),
  four('4 ★'),
  three('3 ★'),
  low('≤ 2 ★'),
  photos('With photos'),
  verified('Verified'),
  helpful('Most helpful');

  const ReviewFilter(this.label);
  final String label;

  bool matches(Review review) => switch (this) {
    ReviewFilter.all || ReviewFilter.helpful => true,
    ReviewFilter.five => review.stars == 5,
    ReviewFilter.four => review.stars == 4,
    ReviewFilter.three => review.stars == 3,
    ReviewFilter.low => review.stars <= 2,
    ReviewFilter.photos => review.photo != null,
    ReviewFilter.verified => review.verified,
  };

  /// The reviews this chip shows, in the order it shows them.
  List<Review> apply(List<Review> reviews) {
    final shown = reviews.where(matches).toList();
    if (this == ReviewFilter.helpful) {
      shown.sort((a, b) => b.helpful.compareTo(a.helpful));
    }
    return shown;
  }
}

class ReviewDetailsScreen extends StatefulWidget {
  const ReviewDetailsScreen({super.key});

  @override
  State<ReviewDetailsScreen> createState() => _ReviewDetailsScreenState();
}

class _ReviewDetailsScreenState extends State<ReviewDetailsScreen> {
  // Space the floating glass covers, so the first card starts below it and
  // every card can still scroll all the way under it.
  static const double _summaryHeight = 128;
  static const double _chipsHeight = 44;
  static const double _gap = 12;
  static const double _edge = 16;
  static const double _listTop =
      _edge + _summaryHeight + _gap + _chipsHeight + _gap;
  static const double _buttonHeight = 56;
  static const double _listBottom = _edge + _buttonHeight + _edge;

  final HostVisibilityLink _host = HostVisibilityLink(
    ReviewDetailsApp.channelName,
  );
  final ScrollController _scroll = ScrollController();
  ReviewFilter _filter = ReviewFilter.all;

  @override
  void initState() {
    super.initState();
    _host.visible.addListener(_onVisibilityChanged);
    _host.attach();
  }

  @override
  void dispose() {
    _host.visible.removeListener(_onVisibilityChanged);
    _host.detach();
    _scroll.dispose();
    super.dispose();
  }

  void _onVisibilityChanged() {
    debugPrint('reviews: ${_host.visible.value ? "shown" : "hidden"}');
    if (mounted) setState(() {});
  }

  void _select(ReviewFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _writeReview(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Reviews open once your Nimbus One arrives.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final reviews = _filter.apply(kReviews);
    final settings = LiquidGlassSettings.ios27Regular(
      brightness: Brightness.light,
    );
    final appearance = LiquidGlassAppearance.ios27Regular(
      brightness: Brightness.light,
    );

    // Hidden by the host (Overview tab, another app tab, scrolled away):
    // mute every ticker below, so nothing animates off screen.
    return TickerMode(
      enabled: _host.visible.value,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Colour for the glass to bend: soft light behind everything.
            const _Backdrop(),
            // 2. The review cards, each a pane of glass over that colour,
            // scrolling in Flutter's own list. A sheen sweeps across each
            // card as it moves, like light on a tilted phone.
            LiquidGlassLayer(
              settings: settings,
              defaultAppearance: appearance,
              child: LayoutBuilder(
                builder: (context, constraints) => ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                    _edge,
                    _listTop,
                    _edge,
                    _listBottom,
                  ),
                  itemCount: reviews.length,
                  separatorBuilder: (_, _) => const SizedBox(height: _gap),
                  itemBuilder: (_, index) => _ScrollSheen(
                    scroll: _scroll,
                    viewportHeight: constraints.maxHeight,
                    child: _ReviewCard(review: reviews[index]),
                  ),
                ),
              ),
            ),
            // 3. The floating controls, glass over the glass cards.
            LiquidGlassLayer(
              settings: settings,
              defaultAppearance: appearance,
              child: Stack(
                children: [
                  Positioned(
                    left: _edge,
                    right: _edge,
                    top: _edge,
                    height: _summaryHeight,
                    child: const _RatingSummary(),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _edge + _summaryHeight + _gap,
                    height: _chipsHeight,
                    child: _FilterChips(selected: _filter, onSelect: _select),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _edge,
                    height: _buttonHeight,
                    child: Center(
                      child: Builder(
                        builder: (context) => _GlassButton(
                          label: 'Write a review',
                          icon: Icons.edit_rounded,
                          onTap: () => _writeReview(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The soft drop shadow iOS gives floating glass.
const _glassShadows = [
  BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8)),
];

/// Glass content gets the package's touch glow, which follows the finger.
class _Glow extends StatelessWidget {
  const _Glow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassGlowLayer(
      child: GlassGlow(glowColor: const Color(0x29FFFFFF), child: child),
    );
  }
}

class _RatingSummary extends StatelessWidget {
  const _RatingSummary();

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      shape: const LiquidRoundedSuperellipse(borderRadius: 28),
      shadows: _glassShadows,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kAverageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 48,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.5,
                    color: _Palette.label,
                  ),
                ),
                const SizedBox(height: 4),
                const _Stars(count: 5, size: 15),
                const SizedBox(height: 4),
                Text(
                  '${_thousands(kReviewCount)} ratings',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _Palette.secondaryLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            const Expanded(child: _Histogram()),
          ],
        ),
      ),
    );
  }
}

class _Histogram extends StatelessWidget {
  const _Histogram();

  @override
  Widget build(BuildContext context) {
    final most = kStarCounts.values.reduce((a, b) => a > b ? a : b);
    // Rows share the card's height, so no font size can overflow it.
    return Column(
      children: [
        for (final stars in [5, 4, 3, 2, 1])
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  child: Text(
                    '$stars',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1,
                      color: _Palette.secondaryLabel,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: kStarCounts[stars]! / most,
                      minHeight: 6,
                      color: _Palette.label.withValues(alpha: 0.75),
                      backgroundColor: _Palette.separator,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelect});

  final ReviewFilter selected;
  final ValueChanged<ReviewFilter> onSelect;

  static const _others = [
    ReviewFilter.photos,
    ReviewFilter.verified,
    ReviewFilter.helpful,
  ];

  @override
  Widget build(BuildContext context) {
    // The rating chips merge and split as one group; the rest stay separate
    // pills with clear gaps. The row scrolls sideways under the page edges,
    // and does not clip, so the chips' shadows show.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _RatingChips(selected: selected, onSelect: onSelect),
          for (final filter in _others) ...[
            const SizedBox(width: _chipGap),
            _Chip(
              label: filter.label,
              selected: filter == selected,
              onTap: () => onSelect(filter),
            ),
          ],
        ],
      ),
    );
  }
}

const double _chipGap = 12;
const double _chipHeight = 44;

/// "All" and the star chips. Tapping "All" flies the star chips left into it,
/// where they melt together like drops of water and leave one wide "All ★"
/// pill; tapping that pill splits them back out. iOS 27's
/// GlassEffectContainer morph, done with a [LiquidGlassBlendGroup].
///
/// The group's blend distance is zero while the chips are apart, so they sit
/// as separate pills, and swells as they fly in, so they stretch liquid
/// bridges and fuse into "All" without a seam.
class _RatingChips extends StatefulWidget {
  const _RatingChips({required this.selected, required this.onSelect});

  final ReviewFilter selected;
  final ValueChanged<ReviewFilter> onSelect;

  @override
  State<_RatingChips> createState() => _RatingChipsState();
}

class _RatingChipsState extends State<_RatingChips>
    with SingleTickerProviderStateMixin {
  static const _stars = [
    ReviewFilter.five,
    ReviewFilter.four,
    ReviewFilter.three,
    ReviewFilter.low,
  ];
  static const double _allWidth = 58;
  static const double _mergedWidth = 96;
  static const double _starWidth = 64;
  static const double _lowWidth = 74;
  static const double _maxBlend = 22;

  /// 0: every chip apart. 1: merged into "All".
  late final AnimationController _merge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
    reverseDuration: const Duration(milliseconds: 620),
  );

  @override
  void dispose() {
    _merge.dispose();
    super.dispose();
  }

  bool get _merged => _merge.value > 0.5;

  void _tapAll() {
    if (_merged) {
      _merge.reverse();
      return;
    }
    widget.onSelect(ReviewFilter.all);
    _merge.forward();
  }

  static double _width(ReviewFilter filter) =>
      filter == ReviewFilter.low ? _lowWidth : _starWidth;

  /// Each chip's own progress: the nearest arrives first, the farthest a
  /// beat later, like a row of drops running into one. Overshoots a little,
  /// so each lands with a small splash.
  double _progress(int index) {
    final start = index * 0.08;
    final t = ((_merge.value - start) / (1 - 3 * 0.08)).clamp(0.0, 1.0);
    return _merge.status == AnimationStatus.reverse
        ? Curves.easeOutBack.flipped.transform(t)
        : Curves.easeOutBack.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _merge,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_merge.value);
        final allWidth = _allWidth + (_mergedWidth - _allWidth) * t;
        var spread = _allWidth + _chipGap;
        final apart = <double>[];
        for (final star in _stars) {
          apart.add(spread);
          spread += _width(star) + _chipGap;
        }
        // Where each star chip is now, flying between its own slot and the
        // middle of the merged pill.
        final lefts = [
          for (final (i, star) in _stars.indexed)
            apart[i] +
                ((_mergedWidth - _width(star)) / 2 - apart[i]) * _progress(i),
        ];
        // The group is as wide as its chips reach, so the chips after it
        // move aside in step and a flying chip never covers one. (Glass
        // outside the group's box would also draw unrounded.)
        var width = allWidth;
        for (final (i, star) in _stars.indexed) {
          width = math.max(width, lefts[i] + _width(star));
        }
        // Apart, no blend, so the chips sit as separate pills. Past halfway
        // and merged, full blend, so the hidden chips fuse into "All"
        // without a seam. Splitting stretches bridges until they snap.
        final v = _merge.value;
        final blend = _maxBlend * (v < 0.5 ? math.sin(math.pi * v) : 1.0);

        return SizedBox(
          width: width,
          height: _chipHeight,
          child: LiquidGlassBlendGroup(
            blend: blend,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final (i, star) in _stars.indexed.toList().reversed)
                  () {
                    final p = _progress(i);
                    final w = _width(star);
                    return Positioned(
                      left: lefts[i],
                      top: 0,
                      width: w,
                      height: _chipHeight,
                      child: IgnorePointer(
                        ignoring: _merged,
                        child: Opacity(
                          opacity: (1 - p * 1.6).clamp(0.0, 1.0),
                          child: _Chip(
                            label: star.label,
                            // Absorbed into a selected "All", a chip takes
                            // its tint, so the merged pill stays one blue.
                            selected:
                                star == widget.selected ||
                                (widget.selected == ReviewFilter.all &&
                                    p > 0.5),
                            grouped: true,
                            onTap: () => widget.onSelect(star),
                          ),
                        ),
                      ),
                    );
                  }(),
                Positioned(
                  left: 0,
                  top: 0,
                  width: allWidth,
                  height: _chipHeight,
                  child: _Chip(
                    label: ReviewFilter.all.label,
                    selected: widget.selected == ReviewFilter.all,
                    grouped: true,
                    // The merged pill says what it holds: every star.
                    trailing: t > 0.01
                        ? Opacity(
                            opacity: t,
                            child: const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.star_rounded, size: 16),
                            ),
                          )
                        : null,
                    onTap: _tapAll,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.grouped = false,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Whether the chip belongs to the enclosing [LiquidGlassBlendGroup].
  final bool grouped;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // The selected chip is tinted glass, like a prominent iOS button.
    const shape = LiquidRoundedSuperellipse(borderRadius: _chipHeight / 2);
    final appearance = selected
        ? const LiquidGlassAppearance.ios27RegularLight(tint: _Palette.blue)
        : null;
    final color = selected ? Colors.white : _Palette.label;
    final content = _Glow(
      child: SizedBox(
        height: _chipHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            widthFactor: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: IconTheme(
                data: IconThemeData(color: color),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        letterSpacing: -0.2,
                        color: color,
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: LiquidStretch(
        child: grouped
            ? LiquidGlass.grouped(
                shape: shape,
                shadows: _glassShadows,
                appearance: appearance,
                child: content,
              )
            : LiquidGlass(
                shape: shape,
                shadows: _glassShadows,
                appearance: appearance,
                child: content,
              ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidStretch(
        child: LiquidGlass(
          shape: const LiquidRoundedSuperellipse(borderRadius: 28),
          shadows: _glassShadows,
          child: _Glow(
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: _Palette.blue),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: _Palette.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final photo = review.photo;
    return LiquidGlass(
      shape: const LiquidRoundedSuperellipse(borderRadius: _cardRadius),
      shadows: _cardShadows,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: review.avatar,
                  child: Text(
                    review.name.characters.first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _Palette.label,
                        ),
                      ),
                      Text(
                        review.when,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _Palette.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                _Stars(count: review.stars, size: 13),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              review.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _Palette.label,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              review.text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                color: _Palette.label,
              ),
            ),
            if (photo != null) ...[
              const SizedBox(height: 12),
              _PhotoTile(colors: photo),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (review.verified) ...[
                  const Icon(
                    Icons.verified_rounded,
                    size: 15,
                    color: _Palette.blue,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Verified purchase',
                    style: TextStyle(
                      fontSize: 13,
                      color: _Palette.secondaryLabel,
                    ),
                  ),
                ],
                const Spacer(),
                const Icon(
                  Icons.thumb_up_alt_outlined,
                  size: 15,
                  color: _Palette.secondaryLabel,
                ),
                const SizedBox(width: 4),
                Text(
                  '${review.helpful}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _Palette.secondaryLabel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const double _cardRadius = 24;

/// Lighter than the floating glass: the cards rest on the page.
const _cardShadows = [
  BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
];

/// What the glass cards bend: soft pools of the product's colours on the
/// grouped background. Static, so the glass only re-renders on scroll.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    Widget pool(Alignment at, Color color, double radius) => Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: at,
            radius: radius,
            colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _Palette.groupedBackground),
        pool(const Alignment(-1.1, -0.7), _Palette.indigo, 0.9),
        pool(const Alignment(1.2, -0.1), _Palette.purple, 0.85),
        pool(const Alignment(-0.9, 0.55), _Palette.teal, 0.8),
        pool(const Alignment(1.0, 1.0), _Palette.pink, 0.75),
        pool(const Alignment(0.0, 0.2), _Palette.blue, 0.5),
      ],
    );
  }
}

/// A band of light that sweeps diagonally across [child] as it scrolls:
/// near the bottom of the list it sits at the card's left, near the top at
/// its right, like a light source above the screen catching a moving pane.
///
/// The list keeps each card in its own repaint boundary, so a scroll moves
/// the card without repainting it; this listens to [scroll] and repaints
/// the sheen itself.
class _ScrollSheen extends SingleChildRenderObjectWidget {
  const _ScrollSheen({
    required this.scroll,
    required this.viewportHeight,
    required super.child,
  });

  final ScrollController scroll;
  final double viewportHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderScrollSheen(scroll, viewportHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderScrollSheen render) {
    render
      ..scroll = scroll
      ..viewportHeight = viewportHeight;
  }
}

class _RenderScrollSheen extends RenderProxyBox {
  _RenderScrollSheen(this._scroll, this.viewportHeight);

  ScrollController _scroll;
  double viewportHeight;

  set scroll(ScrollController value) {
    if (value == _scroll) return;
    if (attached) _scroll.removeListener(markNeedsPaint);
    _scroll = value;
    if (attached) _scroll.addListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scroll.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _scroll.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (viewportHeight <= 0) return;
    // Where the card's centre sits in the viewport, 0 at the bottom, 1 at
    // the top. localToGlobal is in the view's coordinates, and the list
    // fills the view, so that is the viewport.
    final centre = localToGlobal(size.center(Offset.zero)).dy;
    final t = (1 - centre / viewportHeight).clamp(-0.2, 1.2);
    final rect = offset & size;
    final band = rect.width * 0.45;
    final x = rect.left - band + (rect.width + 2 * band) * t;
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0x00FFFFFF), Color(0x30FFFFFF), Color(0x00FFFFFF)],
      ).createShader(Rect.fromLTWH(x - band, rect.top, band * 2, rect.height));
    final canvas = context.canvas
      ..save()
      ..clipRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(_cardRadius)),
      );
    canvas
      ..drawRect(rect, paint)
      ..restore();
  }
}

/// A customer "photo": a vivid gradient with the product glyph. Color is what
/// makes refraction readable as the card passes under the glass.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.headphones_rounded,
        size: 72,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.count, required this.size});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < count ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: _Palette.orange,
          ),
      ],
    );
  }
}

String _thousands(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);
