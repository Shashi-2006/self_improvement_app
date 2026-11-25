// ─────────────────────────────────────────────────────────────────────────────
// WEEKLY ORBIT RECAP — the dynamic end-of-week show from the spec.
//
// SEQUENCE (exactly as decided 25 Nov 2026):
//  1. On load, the top wasting apps fly in ONE BY ONE, biggest first, and
//     circle fast around the centre total.
//  2. The orbit stops and the TOP app pops up — "this was the top app which
//     utilized most of the time" — with its weekly time.
//  3. That app's logo then runs in the background while its detail card is
//     shown, then the next app's logo takes over for the next card.
//  4. After all apps, the deltas vs last week (+1h 20m / −40m) and the
//     reality check appear.
//
// IMPLEMENTATION NOTE: each app is a Widget placed on a circle with
// trigonometry (cos/sin). A single AnimationController drives the whole
// show; each app's entrance is one Interval of that controller, so the
// one-by-one order is guaranteed. "Replay" restarts the controller.
// The app "logos" are coloured circles with the app's first letter — no
// image files, no trademark logos shipped in the repo.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Brand-ish colours for the orbit icons (first letter on a coloured disc).
const Map<String, Color> _appColours = {
  'Instagram': Color(0xFFE1306C),
  'YouTube': Color(0xFFFF0000),
  'TikTok': Color(0xFF010101),
  'Snapchat': Color(0xFFF7C600),
  'Facebook': Color(0xFF1877F2),
  'WhatsApp': Color(0xFF25D366),
  'LinkedIn': Color(0xFF0A66C2),
  'Netflix': Color(0xFFE50914),
  'X': Color(0xFF000000),
  'Reddit': Color(0xFFFF4500),
  'Games': Color(0xFF7C3AED),
  'LeetCode': Color(0xFFF59E0B),
};

Color appColour(String name) =>
    _appColours[name] ?? AppTheme.sky;

class OrbitRecap extends StatefulWidget {
  const OrbitRecap({super.key, required this.apps, required this.realityCheck});

  /// Top wasting apps, biggest first.
  final List<AppUsageEntry> apps;

  /// The projection text shown at the end.
  final String realityCheck;

  @override
  State<OrbitRecap> createState() => _OrbitRecapState();
}

class _OrbitRecapState extends State<OrbitRecap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Index of the app currently showcased (-1 = still orbiting).
  int get _showcaseIndex {
    if (widget.apps.isEmpty) return -1;
    // Each app gets an equal slice of the second half of the timeline.
    final progress = _controller.value;
    if (progress < 0.5) return -1;
    final slice = 0.5 / widget.apps.length;
    final index = ((progress - 0.5) / slice).floor();
    return index.clamp(0, widget.apps.length - 1);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3 + widget.apps.length * 2),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant OrbitRecap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apps != widget.apps) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.apps.isEmpty) {
      return const AppCard(
        child: Text('No wasted time this week — nothing to orbit.'),
      );
    }
    final totalMinutes =
        widget.apps.fold<int>(0, (sum, a) => sum + a.minutesToday * 7);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final showcase = _showcaseIndex;
        final orbiting = showcase < 0;
        return Column(
          children: [
            SizedBox(
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background logo of the app being showcased.
                  if (showcase >= 0)
                    Opacity(
                      opacity: 0.08,
                      child: Text(
                        widget.apps[showcase].appName[0],
                        style: const TextStyle(
                          fontSize: 200,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  // Centre total.
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatMinutes(totalMinutes),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'wasted this week',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  // The orbiting app icons.
                  for (var i = 0; i < widget.apps.length; i++)
                    _orbitIcon(i, orbiting, showcase),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (orbiting)
              const Text(
                'Your top time-wasters, circling in…',
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              )
            else ...[
              _showcaseCard(widget.apps[showcase], showcase),
              const SizedBox(height: 12),
              _deltasCard(),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    _controller
                      ..reset()
                      ..forward();
                  },
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('Replay orbit'),
                ),
                const SizedBox(width: 12),
                if (showcase >= 0)
                  TextButton(
                    onPressed: () {
                      _controller.value = 1.0;
                    },
                    child: const Text('Skip to results'),
                  ),
              ],
            ),
            if (_controller.value >= 1.0) ...[
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb, color: AppTheme.amber),
                        SizedBox(width: 8),
                        Text(
                          'Reality check',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(widget.realityCheck),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// One app icon on the orbit. Entrance is staggered: app i flies in
  /// during Interval(i * 0.1, i * 0.1 + 0.2) of the first half, then the
  /// whole ring spins fast and eases to a stop.
  Widget _orbitIcon(int index, bool orbiting, int showcase) {
    final app = widget.apps[index];
    final count = widget.apps.length;
    // Base angle spreads the icons evenly around the circle.
    final baseAngle = (2 * math.pi * index / count) - math.pi / 2;
    // Spin: two fast turns in the first half, easing out.
    final spin = orbiting
        ? Curves.easeOut.transform(
              (_controller.value / 0.5).clamp(0.0, 1.0),
            ) *
            4 *
            math.pi
        : 4 * math.pi;
    final angle = baseAngle + spin;
    // Entrance: scale from 0 to 1, staggered one by one.
    final entranceStart = index * 0.08;
    final entrance = Curves.easeOut.transform(
      ((_controller.value - entranceStart) / 0.25).clamp(0.0, 1.0),
    );
    final isTop = index == 0;
    final isShowcased = index == showcase;
    const radius = 95.0;
    final size = (isShowcased ? 64.0 : 48.0) * entrance;
    if (size <= 1) return const SizedBox.shrink();
    return Transform.translate(
      offset: Offset(math.cos(angle) * radius, math.sin(angle) * radius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: appColour(app.appName),
          shape: BoxShape.circle,
          border: isShowcased
              ? Border.all(color: AppTheme.amber, width: 3)
              : null,
          boxShadow: AppTheme.cardShadow(context),
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              app.appName[0],
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (isTop && orbiting)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.amber,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '#1',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _showcaseCard(AppUsageEntry app, int index) {
    final label = index == 0
        ? 'This was the top app which utilized most of the time'
        : '#${index + 1} · ${app.appName} — ${index + 1}${_ordinalSuffix(index + 1)} biggest this week';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${app.appName}: ${formatMinutes(app.minutesToday * 7)} this week '
            '(${formatMinutes(app.minutesToday)} today)',
          ),
          if (app.dailyLimitMinutes != null)
            Text(
              'Limit was ${formatMinutes(app.dailyLimitMinutes!)} a day — '
              '${formatMinutes(app.minutesOverLimit)} over today.',
              style: const TextStyle(color: AppTheme.rose),
            ),
        ],
      ),
    );
  }

  Widget _deltasCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'vs last week',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final app in widget.apps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(app.appName),
                  Text(
                    _deltaText(app.weeklyDeltaMinutes),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: app.weeklyDeltaMinutes > 0
                          ? AppTheme.rose
                          : AppTheme.emerald,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _deltaText(int delta) {
    final sign = delta > 0 ? '+' : delta < 0 ? '−' : '';
    return '$sign${formatMinutes(delta.abs())}';
  }

  String _ordinalSuffix(int n) {
    if (n == 1) return 'st';
    if (n == 2) return 'nd';
    if (n == 3) return 'rd';
    return 'th';
  }
}
