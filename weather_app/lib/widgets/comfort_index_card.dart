import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../utils/comfort_index_utils.dart';

/// Карточка "Индекс комфорта" — сводная оценка (0..100) того, насколько
/// приятно сейчас находиться на улице, с разбивкой по вкладу факторов.
class ComfortIndexCard extends StatelessWidget {
  final double tempCelsius;
  final int humidityPercent;
  final double windSpeedMs;
  final double? uvIndex;
  final double? precipitationProbability;

  const ComfortIndexCard({
    super.key,
    required this.tempCelsius,
    required this.humidityPercent,
    required this.windSpeedMs,
    this.uvIndex,
    this.precipitationProbability,
  });

  ({String label, Color color}) _infoFor(
      ComfortLevel level, AppLocalizations l10n) {
    switch (level) {
      case ComfortLevel.excellent:
        return (label: l10n.comfortExcellent, color: const Color(0xFF7ED957));
      case ComfortLevel.good:
        return (label: l10n.comfortGood, color: const Color(0xFFC7E86B));
      case ComfortLevel.moderate:
        return (label: l10n.comfortModerate, color: const Color(0xFFFFD166));
      case ComfortLevel.poor:
        return (label: l10n.comfortPoor, color: const Color(0xFFFF8C5A));
      case ComfortLevel.bad:
        return (label: l10n.comfortBad, color: const Color(0xFFFF5A5F));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = ComfortIndexUtils.calculate(
      tempCelsius: tempCelsius,
      humidityPercent: humidityPercent,
      windSpeedMs: windSpeedMs,
      uvIndex: uvIndex,
      precipitationProbability: precipitationProbability,
    );
    final info = _infoFor(result.level, l10n);

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
              SizedBox(
                width: 64,
                height: 64,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0.0, end: result.score / 100),
                  builder: (context, value, child) {
                    return CustomPaint(
                      painter: _ComfortRingPainter(
                        progress: value,
                        color: info.color,
                      ),
                      child: Center(
                        child: Text(
                          '${(value * 100).round()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.comfortIndex,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.label,
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
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FactorChip(
                icon: Icons.thermostat_rounded,
                label: l10n.comfortFactorTemp,
                value: '${tempCelsius.round()}°',
              ),
              _FactorChip(
                icon: Icons.water_drop_outlined,
                label: l10n.comfortFactorHumidity,
                value: '$humidityPercent%',
              ),
              _FactorChip(
                icon: Icons.air_rounded,
                label: l10n.comfortFactorWind,
                value: '${windSpeedMs.round()} ${l10n.windUnit}',
              ),
              if (uvIndex != null)
                _FactorChip(
                  icon: Icons.wb_sunny_outlined,
                  label: l10n.comfortFactorUv,
                  value: uvIndex!.round().toString(),
                ),
              if (precipitationProbability != null)
                _FactorChip(
                  icon: Icons.umbrella_outlined,
                  label: l10n.comfortFactorRain,
                  value: '${(precipitationProbability! * 100).round()}%',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FactorChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _FactorChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white60, size: 14),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComfortRingPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;

  _ComfortRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ComfortRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
