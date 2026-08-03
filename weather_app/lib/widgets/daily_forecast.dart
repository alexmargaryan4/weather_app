import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/weather_model.dart';
import '../utils/temperature_utils.dart';
import 'weather_icon.dart';

class DailyForecastList extends StatelessWidget {
  final List<DailyForecast> daily;
  final bool useFahrenheit;

  const DailyForecastList({
    super.key,
    required this.daily,
    this.useFahrenheit = false,
  });

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) {
      return const SizedBox.shrink();
    }

    // Находим глобальный минимум и максимум за все дни - для корректной шкалы полоски температуры
    final allMax = daily.map((d) => d.tempMax).reduce((a, b) => a > b ? a : b);
    final allMin = daily.map((d) => d.tempMin).reduce((a, b) => a < b ? a : b);
    final range = (allMax - allMin).clamp(1.0, double.infinity);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ПРОГНОЗ НА 5 ДНЕЙ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          ...daily.asMap().entries.map((entry) {
            final index = entry.key;
            final day = entry.value;
            final maxOffset = (allMax - day.tempMax) / range;
            final minOffset = (day.tempMin - allMin) / range;
            final widthFactor = (1 - maxOffset - minOffset).clamp(0.08, 1.0);
            final isLast = index == daily.length - 1;
            final isToday = index == 0;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      isToday ? 'Сегодня' : DateFormat.E().format(day.date),
                      style: TextStyle(
                        color: isToday ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight:
                            isToday ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  WeatherIcon(iconCode: day.iconCode, size: 24),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 30,
                    child: Text(
                      TemperatureUtils.format(day.tempMin, useFahrenheit),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final trackWidth = constraints.maxWidth;
                        return Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 4,
                              width: trackWidth,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Positioned(
                              left: trackWidth * minOffset,
                              child: Container(
                                height: 4,
                                width: trackWidth * widthFactor,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFD97D),
                                      Color(0xFFFF9F4A),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    child: Text(
                      TemperatureUtils.format(day.tempMax, useFahrenheit),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
