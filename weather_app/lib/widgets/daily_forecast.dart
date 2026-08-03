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
        color: Colors.red.withOpacity(0.3), // ВРЕМЕННО: яркий цвет, чтобы видеть границы контейнера
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.yellow, width: 2), // ВРЕМЕННО
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'ПРОГНОЗ НА 5 ДНЕЙ (allMax=$allMax allMin=$allMin range=$range)', // ВРЕМЕННО
              style: const TextStyle(
                color: Colors.white,
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

            return Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 4),
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3), // ВРЕМЕННО
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                // ВРЕМЕННО: чистый текст без сложной вёрстки, чтобы проверить рендер построчно
                '[$index] ${day.date} min=${day.tempMin} max=${day.tempMax} '
                'maxOffset=$maxOffset minOffset=$minOffset '
                'widthFactor=${(1 - maxOffset - minOffset).clamp(0.08, 1.0)}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            );
          }),
        ],
      ),
    );
  }
}
