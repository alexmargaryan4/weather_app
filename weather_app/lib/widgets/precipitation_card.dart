import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../localization/app_localizations.dart';
import '../models/weather_model.dart';

/// Карточка вероятности осадков: крупная цифра "сейчас" слева и мини-график
/// столбиками по ближайшим часам справа/снизу.
class PrecipitationCard extends StatelessWidget {
  final double? currentProbability; // 0.0..1.0
  final List<HourlyForecast> hourly;

  const PrecipitationCard({
    super.key,
    required this.currentProbability,
    required this.hourly,
  });

  Color _colorFor(double probability) {
    if (probability >= 0.6) return const Color(0xFF4FA8FF);
    if (probability >= 0.3) return const Color(0xFF7EC8FF);
    return const Color(0xFFB9DDFF);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = currentProbability ?? 0.0;
    final displayedHours = hourly.take(8).toList();

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
          Row(
            children: [
              Icon(Icons.water_drop_rounded,
                  color: _colorFor(current), size: 16),
              const SizedBox(width: 8),
              Text(
                l10n.precipitationChance,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(current * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w300,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.precipitationNow,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ],
          ),
          if (displayedHours.isNotEmpty) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 76,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final hour in displayedHours)
                    Expanded(
                      child: _HourBar(
                        hour: hour,
                        color: _colorFor(hour.pop),
                        dateFormatLocale: l10n.dateFormatLocale,
                        isNow: hour == displayedHours.first,
                        nowLabel: l10n.now,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HourBar extends StatelessWidget {
  final HourlyForecast hour;
  final Color color;
  final String dateFormatLocale;
  final bool isNow;
  final String nowLabel;

  const _HourBar({
    required this.hour,
    required this.color,
    required this.dateFormatLocale,
    required this.isNow,
    required this.nowLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Высота столбика пропорциональна вероятности, но с минимальной высотой,
    // чтобы столбик был виден даже при 0% (иначе колонка выглядит "сломанной").
    final barHeight = 6.0 + hour.pop * 34.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${(hour.pop * 100).round()}%',
          style: TextStyle(
            color: hour.pop > 0 ? Colors.white70 : Colors.white38,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: barHeight,
          width: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isNow ? nowLabel : DateFormat.Hm(dateFormatLocale).format(hour.time),
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}
