import 'package:flutter/material.dart';

/// Круглая карточка индекса качества воздуха (AQI по шкале OpenWeather: 1..5).
class AirQualityCard extends StatelessWidget {
  final int? aqi;

  const AirQualityCard({super.key, required this.aqi});

  ({String label, Color color}) _infoFor(int value) {
    switch (value) {
      case 1:
        return (label: 'Отличное', color: const Color(0xFF7ED957));
      case 2:
        return (label: 'Хорошее', color: const Color(0xFFC7E86B));
      case 3:
        return (label: 'Среднее', color: const Color(0xFFFFD166));
      case 4:
        return (label: 'Плохое', color: const Color(0xFFFF8C5A));
      default:
        return (label: 'Очень плохое', color: const Color(0xFFFF5A5F));
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = aqi;
    final info = value != null ? _infoFor(value) : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (info?.color ?? Colors.white24).withOpacity(0.25),
              border: Border.all(
                color: info?.color ?? Colors.white38,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                value?.toString() ?? '–',
                style: TextStyle(
                  color: info?.color ?? Colors.white70,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'КАЧЕСТВО ВОЗДУХА',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info?.label ?? 'Нет данных',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
