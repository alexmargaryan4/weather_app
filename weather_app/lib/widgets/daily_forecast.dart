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
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'ПРОГНОЗ НА 5 ДНЕЙ',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...daily.asMap().entries.map((entry) {
            final index = entry.key;
            final day = entry.value;
            final maxOffset = (allMax - day.tempMax) / range;
            final minOffset = (day.tempMin - allMin) / range;
            final isLast = index == daily.length - 1;

            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 400 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset((1 - value) * 30, 0),
                    child: child,
                  ),
                );
              },
              child: Container(
                margin: EdgeInsets.only(bottom: isLast ? 0 : 4),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                decoration: BoxDecoration(
                  color: index == 0
                      ? Colors.white.withOpacity(0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(
                        index == 0
                            ? 'Сегодня'
                            : DateFormat.E('ru').format(day.date),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                    WeatherIcon(iconCode: day.iconCode, size: 26),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 30,
                      child: Text(
                        TemperatureUtils.format(day.tempMin, useFahrenheit),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 15),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            children: [
                              Container(height: 5, color: Colors.white24),
                              FractionallySizedBox(
                                widthFactor:
                                    (1 - maxOffset - minOffset).clamp(0.08, 1.0),
                                alignment: Alignment(-1 + minOffset * 2, 0),
                                child: Container(
                                  height: 5,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.orange,
                                        Colors.redAccent
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text(
                        TemperatureUtils.format(day.tempMax, useFahrenheit),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
