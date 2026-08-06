import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../utils/moon_phase_utils.dart';

/// Карточка фазы луны на сегодня: иконка (нарисованная кодом, без картинок)
/// + название фазы + процент освещённости диска.
class MoonPhaseCard extends StatelessWidget {
  final DateTime date;

  const MoonPhaseCard({super.key, required this.date});

  String _labelFor(MoonPhaseType type, AppLocalizations l10n) {
    switch (type) {
      case MoonPhaseType.newMoon:
        return l10n.moonNew;
      case MoonPhaseType.waxingCrescent:
        return l10n.moonWaxingCrescent;
      case MoonPhaseType.firstQuarter:
        return l10n.moonFirstQuarter;
      case MoonPhaseType.waxingGibbous:
        return l10n.moonWaxingGibbous;
      case MoonPhaseType.fullMoon:
        return l10n.moonFull;
      case MoonPhaseType.waningGibbous:
        return l10n.moonWaningGibbous;
      case MoonPhaseType.lastQuarter:
        return l10n.moonLastQuarter;
      case MoonPhaseType.waningCrescent:
        return l10n.moonWaningCrescent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final info = MoonPhaseUtils.calculate(date);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(
              painter: _MoonPainter(age: info.age),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.moonPhase,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _labelFor(info.type, l10n),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(info.illumination * 100).round()}% ${l10n.moonIllumination}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Рисует диск луны с освещённой частью, соответствующей возрасту фазы.
/// age: 0.0 = новолуние, 0.25 = первая четверть, 0.5 = полнолуние,
/// 0.75 = последняя четверть.
class _MoonPainter extends CustomPainter {
  final double age;

  _MoonPainter({required this.age});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Тёмный диск-основа (тень луны)
    final darkPaint = Paint()..color = const Color(0xFF1B2440);
    canvas.drawCircle(center, radius, darkPaint);

    // Освещённая часть рисуется как пересечение диска с "терминатором" —
    // эллиптической кривой, которая при age=0 и age=0.5 вырождается в
    // прямую линию (новолуние/полнолуние), а между ними изгибается.
    final litPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFF6DD), Color(0xFFE9D9A8)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final path = Path();
    // waxing (0..0.5): освещена правая часть, растущая к полнолунию.
    // waning (0.5..1): освещена левая часть, убывающая от полнолуния.
    final isWaxing = age <= 0.5;
    // t: 0 в новолунии, 1 в полнолунии — симметрично для обеих половин цикла.
    final t = isWaxing ? age / 0.5 : (1 - age) / 0.5;
    // Кривизна терминатора: -1 (полностью вогнутый, новолуние) через 0
    // (прямая линия, четверти) до +1 (полностью выпуклый, полнолуние).
    final curveFactor = (t - 0.5) * 2;

    final rect = Rect.fromCircle(center: center, radius: radius);
    // Контрольная точка квадратичной кривой Безье смещается на 2*radius, а не
    // на radius: только тогда середина кривой (t=0.5) физически достигает
    // края диска при curveFactor=±1, и терминатор корректно вырождается в
    // прямую в новолунии/полнолунии, а не останавливается на полпути.
    if (isWaxing) {
      // Освещённая половина — правая; добавляем к ней выпуклый/вогнутый край.
      path.addArc(rect, -math.pi / 2, math.pi);
      final controlOffset = 2 * radius * curveFactor;
      path.quadraticBezierTo(
        center.dx + controlOffset,
        center.dy,
        center.dx,
        center.dy - radius,
      );
    } else {
      path.addArc(rect, math.pi / 2, math.pi);
      final controlOffset = -2 * radius * curveFactor;
      path.quadraticBezierTo(
        center.dx + controlOffset,
        center.dy,
        center.dx,
        center.dy + radius,
      );
    }
    path.close();
    canvas.drawPath(path, litPaint);

    // Тонкая обводка диска
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _MoonPainter oldDelegate) =>
      oldDelegate.age != age;
}
