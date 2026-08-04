import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Живой погодный слой поверх градиентного фона: дождь, снег, мерцающие
/// звёзды ночью или мягкие блики в ясную погоду — как в приложении погоды Apple.
class WeatherParticles extends StatefulWidget {
  final String iconCode;

  const WeatherParticles({super.key, required this.iconCode});

  @override
  State<WeatherParticles> createState() => _WeatherParticlesState();
}

enum _ParticleMode { rain, snow, stars, sunFlare, none }

class _WeatherParticlesState extends State<WeatherParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<_Particle> _particles;
  _ParticleMode _mode = _ParticleMode.none;
  final math.Random _random = math.Random(7);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _mode = _modeFor(widget.iconCode);
    _particles = _generateParticles(_mode);
  }

  @override
  void didUpdateWidget(covariant WeatherParticles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.iconCode != widget.iconCode) {
      final newMode = _modeFor(widget.iconCode);
      if (newMode != _mode) {
        _mode = newMode;
        _particles = _generateParticles(_mode);
      }
    }
  }

  _ParticleMode _modeFor(String iconCode) {
    final isNight = iconCode.endsWith('n');
    final code = iconCode.length >= 2 ? iconCode.substring(0, 2) : '01';

    if (code == '09' || code == '10' || code == '11') return _ParticleMode.rain;
    if (code == '13') return _ParticleMode.snow;
    if (isNight) return _ParticleMode.stars;
    // Днём при любой погоде без осадков (ясно, облачно, пасмурно) показываем
    // мягкие солнечные блики — раньше это работало только для '01'/'02',
    // и коды '03'/'04' (облачно/пасмурно) оставались вообще без анимации.
    return _ParticleMode.sunFlare;
  }

  List<_Particle> _generateParticles(_ParticleMode mode) {
    final count = switch (mode) {
      _ParticleMode.rain => 70,
      _ParticleMode.snow => 45,
      _ParticleMode.stars => 40,
      _ParticleMode.sunFlare => 0,
      _ParticleMode.none => 0,
    };

    return List.generate(count, (i) {
      return _Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        speed: 0.4 + _random.nextDouble() * 0.9,
        size: 1.0 + _random.nextDouble() * 2.2,
        phase: _random.nextDouble(),
        drift: (_random.nextDouble() - 0.5) * 0.4,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == _ParticleMode.none) return const SizedBox.shrink();

    if (_mode == _ParticleMode.sunFlare) {
      return IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _SunFlarePainter(progress: _controller.value),
              size: Size.infinite,
            );
          },
        ),
      );
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _ParticlePainter(
              particles: _particles,
              progress: _controller.value,
              mode: _mode,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Particle {
  final double x; // 0..1 относительная позиция по горизонтали
  final double y; // 0..1 начальная позиция по вертикали (используется как фазовый сдвиг)
  final double speed;
  final double size;
  final double phase;
  final double drift; // для снега — горизонтальное покачивание

  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.phase,
    required this.drift,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final _ParticleMode mode;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.mode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (mode == _ParticleMode.rain) {
      _paintRain(canvas, size);
    } else if (mode == _ParticleMode.snow) {
      _paintSnow(canvas, size);
    } else if (mode == _ParticleMode.stars) {
      _paintStars(canvas, size);
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    for (final p in particles) {
      final t = (progress * p.speed * 6 + p.phase) % 1.0;
      final startY = t * (size.height + 60) - 40;
      final x = p.x * size.width;
      final length = 12 + p.size * 4;

      canvas.drawLine(
        Offset(x, startY),
        Offset(x - 3, startY + length),
        paint,
      );
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.75);

    for (final p in particles) {
      final t = (progress * p.speed * 0.8 + p.phase) % 1.0;
      final y = t * (size.height + 40) - 20;
      final swayX = math.sin((t * 2 * math.pi) + p.phase * 10) * (14 + p.drift.abs() * 20);
      final x = (p.x * size.width) + swayX;

      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  void _paintStars(Canvas canvas, Size size) {
    for (final p in particles) {
      final twinkle = (math.sin((progress * 2 * math.pi * p.speed) + p.phase * 10) + 1) / 2;
      final opacity = 0.15 + twinkle * 0.55;
      final paint = Paint()..color = Colors.white.withOpacity(opacity);
      final x = p.x * size.width;
      final y = p.y * size.height * 0.65; // звёзды только в верхней части неба

      canvas.drawCircle(Offset(x, y), p.size * 0.9, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

/// Мягкие вращающиеся блики света для ясной/облачной дневной погоды.
class _SunFlarePainter extends CustomPainter {
  final double progress;

  _SunFlarePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.78, size.height * 0.12);
    final angle = progress * 2 * math.pi;

    for (int i = 0; i < 3; i++) {
      final localAngle = angle + (i * 2.1);
      final radius = 55.0 + i * 34;
      final offset = Offset(
        center.dx + math.cos(localAngle) * 14,
        center.dy + math.sin(localAngle) * 14,
      );
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.16 - i * 0.03)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34);
      canvas.drawCircle(offset, radius, paint);
    }

    // Дополнительный мягкий блик снизу-слева, чтобы сцена не выглядела пустой
    // на широких экранах и было ощущение объёма даже без осадков.
    final secondaryCenter = Offset(size.width * 0.15, size.height * 0.55);
    final secondaryOffset = Offset(
      secondaryCenter.dx + math.cos(-angle * 0.6) * 10,
      secondaryCenter.dy + math.sin(-angle * 0.6) * 10,
    );
    final secondaryPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(secondaryOffset, 90, secondaryPaint);
  }

  @override
  bool shouldRepaint(covariant _SunFlarePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
