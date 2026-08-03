import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Круговая дуга, показывающая положение солнца между восходом и закатом.
class SunArcCard extends StatelessWidget {
  final DateTime sunrise;
  final DateTime sunset;

  const SunArcCard({super.key, required this.sunrise, required this.sunset});

  double get _progress {
    final now = DateTime.now();
    final total = sunset.difference(sunrise).inSeconds;
    if (total <= 0) return 0;
    final elapsed = now.difference(sunrise).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  bool get _isDaytime {
    final now = DateTime.now();
    return now.isAfter(sunrise) && now.isBefore(sunset);
  }

  @override
  Widget build(BuildContext context) {
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
              Icon(
                _isDaytime ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'СОЛНЦЕ',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0.0, end: _progress),
              builder: (context, value, child) {
                return CustomPaint(
                  painter: _SunArcPainter(progress: value),
                  child: Container(),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SunTimeLabel(label: 'Восход', time: sunrise),
              _SunTimeLabel(label: 'Закат', time: sunset, alignEnd: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _SunTimeLabel extends StatelessWidget {
  final String label;
  final DateTime time;
  final bool alignEnd;

  const _SunTimeLabel({
    required this.label,
    required this.time,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          DateFormat.Hm().format(time),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SunArcPainter extends CustomPainter {
  final double progress; // 0.0 = восход, 1.0 = закат

  _SunArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final baseline = height - 8;
    final radius = width / 2;
    final center = Offset(width / 2, baseline);

    // Фоновая дуга (полукруг)
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final trackRect = Rect.fromCircle(center: center, radius: radius - 4);
    canvas.drawArc(trackRect, math.pi, math.pi, false, trackPaint);

    // Пройденная часть дуги (ярче)
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD97D), Color(0xFFFF9F4A)],
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
        trackRect, math.pi, math.pi * progress, false, progressPaint);

    // Пунктирная линия горизонта
    final horizonPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 1;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < width) {
      canvas.drawLine(
        Offset(startX, baseline),
        Offset(startX + dashWidth, baseline),
        horizonPaint,
      );
      startX += dashWidth + dashSpace;
    }

    // Положение солнца на дуге
    final angle = math.pi + math.pi * progress;
    final sunCenter = Offset(
      center.dx + (radius - 4) * math.cos(angle),
      center.dy + (radius - 4) * math.sin(angle),
    );

    final glowPaint = Paint()
      ..color = const Color(0xFFFFD97D).withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(sunCenter, 12, glowPaint);

    final sunPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFF3D6), Color(0xFFFFC24B)],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: 7));
    canvas.drawCircle(sunCenter, 7, sunPaint);
  }

  @override
  bool shouldRepaint(covariant _SunArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
