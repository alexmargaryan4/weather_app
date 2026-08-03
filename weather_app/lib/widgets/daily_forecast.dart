import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/weather_model.dart';
import 'weather_icon.dart';

class DailyForecastList extends StatelessWidget {
  final List<DailyForecast> daily;

  const DailyForecastList({super.key, required this.daily});

  @override
  Widget build(BuildContext context) {
    // Находим глобальный минимум и максимум за все дни - для корректной шкалы полоски температуры
    final allMax = daily.map((d) => d.tempMax).reduce((a, b) => a > b ? a : b);
    final allMin = daily.map((d) => d.tempMin).reduce((a, b) => a < b ? a : b);
    final range = (allMax - allMin).clamp(1, double.infinity);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 8),
          ...daily.asMap().entries.map((entry) {
            final index = entry.key;
            final day = entry.value;
            final maxOffset = (allMax - day.tempMax) / range;
            final minOffset = (day.tempMin - allMin) / range;

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
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        index == 0 ? 'Сегодня' : DateFormat.E('ru').format(day.date),
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                    WeatherIcon(iconCode: day.iconCode, size: 26),
                    const SizedBox(width: 12),
                    Text(
                      '${day.tempMin.round()}°',
                      style: const TextStyle(color: Colors.white54, fontSize: 15),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Stack(
                            children: [
                              Container(height: 4, color: Colors.white24),
                              FractionallySizedBox(
                                widthFactor: (1 - maxOffset - minOffset).clamp(0.05, 1.0),
                                alignment: Alignment(-1 + minOffset * 2, 0),
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Colors.orange, Colors.redAccent],
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '${day.tempMax.round()}°',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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