// Weekly utilised-vs-wasted bar chart, drawn by hand with CustomPainter.
// (No chart package: 7 bars is small enough to draw ourselves, and it keeps
// the project dependency-free. A "painter" gets a canvas and draws shapes;
// Flutter calls paint() again whenever the data changes.)

import 'package:flutter/material.dart';

import '../services/recap_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class WeeklyChart extends StatelessWidget {
  const WeeklyChart({super.key, required this.days});

  /// 7 day summaries, oldest first.
  final List<DaySummary> days;

  @override
  Widget build(BuildContext context) {
    final maxMinutes = days.fold<int>(
      0,
      (max, d) =>
          d.utilisedMinutes + d.wastedMinutes > max
              ? d.utilisedMinutes + d.wastedMinutes
              : max,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendDot(AppTheme.emerald, 'Utilised'),
            const SizedBox(width: 16),
            _legendDot(AppTheme.amber, 'Wasted'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: CustomPaint(
            painter: _WeeklyChartPainter(
              days: days,
              maxMinutes: maxMinutes < 60 ? 60 : maxMinutes,
              utilisedColor: AppTheme.emerald,
              wastedColor: AppTheme.amber,
              labelColor: Theme.of(context).textTheme.bodySmall?.color ??
                  Colors.grey,
            ),
            child: Container(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: days.map((d) {
            final date = DateTime.parse(d.date);
            const weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            return Text(
              weekday[date.weekday - 1],
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}

class _WeeklyChartPainter extends CustomPainter {
  _WeeklyChartPainter({
    required this.days,
    required this.maxMinutes,
    required this.utilisedColor,
    required this.wastedColor,
    required this.labelColor,
  });

  final List<DaySummary> days;
  final int maxMinutes;
  final Color utilisedColor;
  final Color wastedColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / days.length * 0.45;
    final gap = size.width / days.length;
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final x = gap * i + (gap - barWidth) / 2;
      final utilisedHeight =
          size.height * (day.utilisedMinutes / maxMinutes);
      final wastedHeight = size.height * (day.wastedMinutes / maxMinutes);

      // Wasted bar sits behind, utilised bar in front — one column per day.
      final wastedRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - wastedHeight, barWidth, wastedHeight),
        const Radius.circular(6),
      );
      final utilisedRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          size.height - utilisedHeight,
          barWidth,
          utilisedHeight,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        wastedRect,
        Paint()..color = wastedColor.withValues(alpha: 0.35),
      );
      canvas.drawRRect(utilisedRect, Paint()..color = utilisedColor);

      // Minutes label on top of the taller bar.
      final total = day.utilisedMinutes + day.wastedMinutes;
      if (total > 0) {
        final span = TextSpan(
          text: formatMinutes(total),
          style: TextStyle(fontSize: 10, color: labelColor),
        );
        final painter = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          Offset(x + barWidth / 2 - painter.width / 2,
              size.height - (utilisedHeight > wastedHeight
                      ? utilisedHeight
                      : wastedHeight) -
                  16),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyChartPainter old) =>
      old.days != days || old.maxMinutes != maxMinutes;
}
