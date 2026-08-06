import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../localization/app_localizations.dart';
import '../models/weather_model.dart';
import '../utils/temperature_utils.dart';

/// Карточка с линейным графиком изменения температуры на ближайшие часы
/// (по данным hourly-прогноза, который уже загружается приложением).
class TemperatureChart extends StatelessWidget {
  final List<HourlyForecast> hourly;
  final bool useFahrenheit;

  const TemperatureChart({
    super.key,
    required this.hourly,
    this.useFahrenheit = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (hourly.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.temperatureTrend,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return CustomPaint(
                  painter: _TemperatureChartPainter(
                    hourly: hourly,
                    useFahrenheit: useFahrenheit,
                    progress: value,
                    dateFormatLocale: l10n.dateFormatLocale,
                    nowLabel: l10n.now,
                  ),
                  child: Container(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TemperatureChartPainter extends CustomPainter {
  final List<HourlyForecast> hourly;
  final bool useFahrenheit;
  final double progress; // 0..1 анимация появления линии
  final String dateFormatLocale;
  final String nowLabel;

  _TemperatureChartPainter({
    required this.hourly,
    required this.useFahrenheit,
    required this.progress,
    required this.dateFormatLocale,
    required this.nowLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (hourly.isEmpty) return;

    const topPadding = 24.0;
    const bottomPadding = 30.0;
    const sidePadding = 8.0;
    final chartWidth = size.width - sidePadding * 2;
    final chartHeight = size.height - topPadding - bottomPadding;

    final temps = hourly.map((h) => h.temp).toList();
    final minTemp = temps.reduce((a, b) => a < b ? a : b);
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);
    // Небольшой запас сверху/снизу, чтобы точки не упирались в края.
    final range = (maxTemp - minTemp).abs() < 1 ? 1.0 : (maxTemp - minTemp);
    final paddedMin = minTemp - range * 0.2;
    final paddedRange = range * 1.4;

    double xFor(int index) {
      if (hourly.length == 1) return sidePadding + chartWidth / 2;
      return sidePadding + (chartWidth / (hourly.length - 1)) * index;
    }

    double yFor(double temp) {
      final t = (temp - paddedMin) / paddedRange;
      return topPadding + chartHeight - (t * chartHeight);
    }

    final points = <Offset>[
      for (int i = 0; i < hourly.length; i++) Offset(xFor(i), yFor(hourly[i].temp))
    ];

    // Сколько точек показывать с учётом анимации появления слева направо.
    final visibleCount = (points.length * progress).ceil().clamp(1, points.length);
    final visiblePoints = points.sublist(0, visibleCount);

    // Плавная кривая через точки (Catmull-Rom -> кубические Безье).
    final linePath = Path();
    if (visiblePoints.isNotEmpty) {
      linePath.moveTo(visiblePoints.first.dx, visiblePoints.first.dy);
      for (int i = 0; i < visiblePoints.length - 1; i++) {
        final p0 = i == 0 ? visiblePoints[i] : visiblePoints[i - 1];
        final p1 = visiblePoints[i];
        final p2 = visiblePoints[i + 1];
        final p3 = i + 2 < visiblePoints.length ? visiblePoints[i + 2] : p2;

        final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
        final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
        linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      }
    }

    // Заливка под кривой градиентом.
    if (visiblePoints.length > 1) {
      final fillPath = Path.from(linePath);
      fillPath.lineTo(visiblePoints.last.dx, topPadding + chartHeight);
      fillPath.lineTo(visiblePoints.first.dx, topPadding + chartHeight);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFB25A).withOpacity(0.35),
            const Color(0xFFFFB25A).withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight));
      canvas.drawPath(fillPath, fillPaint);
    }

    // Линия графика.
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD97D), Color(0xFFFF9F4A)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(linePath, linePaint);

    // Точки + подписи температуры и времени под каждой видимой точкой,
    // прорежены, чтобы не накладывались друг на друга при большом числе часов.
    final labelEvery = hourly.length > 8 ? 2 : 1;
    for (int i = 0; i < visiblePoints.length; i++) {
      final point = visiblePoints[i];
      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(point, i == 0 ? 4.5 : 3, dotPaint);

      if (i % labelEvery != 0 && i != visiblePoints.length - 1) continue;

      final tempText = TemperatureUtils.format(hourly[i].temp, useFahrenheit);
      final tempPainter = TextPainter(
        text: TextSpan(
          text: tempText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tempPainter.paint(
        canvas,
        Offset(point.dx - tempPainter.width / 2, point.dy - 20),
      );

      final timeLabel = i == 0
          ? nowLabel
          : DateFormat.Hm(dateFormatLocale).format(hourly[i].time);
      final timePainter = TextPainter(
        text: TextSpan(
          text: timeLabel,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      timePainter.paint(
        canvas,
        Offset(point.dx - timePainter.width / 2, size.height - bottomPadding + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TemperatureChartPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.hourly != hourly ||
      oldDelegate.useFahrenheit != useFahrenheit;
}
