import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'home_screen.dart';

/// Красивый загрузочный экран, показываемый при старте приложения.
/// Анимирует солнце и облако (как на иконке приложения), лёгкое
/// сияние на фоне и плавно перетекает в главный экран.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Общий контроллер входа: масштаб + прозрачность лого и текста.
  late final AnimationController _introController;
  // Бесконечный контроллер для лёгкого "дыхания" солнца и дрейфа облака.
  late final AnimationController _loopController;
  // Контроллер плавного перехода на главный экран.
  late final AnimationController _exitController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _sunRayRotation;
  late final Animation<double> _cloudDrift;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _sunRayRotation = Tween<double>(begin: 0.0, end: 1.0).animate(_loopController);
    _cloudDrift = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _loopController, curve: Curves.easeInOut),
    );

    _introController.forward();
    _scheduleNavigation();
  }

  Future<void> _scheduleNavigation() async {
    // Даём анимации входа отыграть и подержим экран чуть дольше для ощущения "премиальности".
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted || _navigated) return;
    _navigated = true;
    await _exitController.forward();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
          return FadeTransition(opacity: fade, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _introController.dispose();
    _loopController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B63C9),
      body: AnimatedBuilder(
        animation: Listenable.merge(
            [_introController, _loopController, _exitController]),
        builder: (context, _) {
          final exitFade = 1.0 - _exitController.value;
          final exitScale = 1.0 + (_exitController.value * 0.08);

          return Opacity(
            opacity: exitFade.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: exitScale,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Радиальный градиентный фон, повторяющий тона иконки приложения.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.2),
                        radius: 1.3,
                        colors: [
                          const Color(0xFF3E8EE0),
                          const Color(0xFF1B63C9),
                          const Color(0xFF0E3E86),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),

                  // Едва заметные декоративные частицы-звёзды для глубины.
                  ..._buildAmbientDots(),

                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildAnimatedLogo(),
                        const SizedBox(height: 28),
                        SlideTransition(
                          position: _titleSlide,
                          child: FadeTransition(
                            opacity: _titleFade,
                            child: Column(
                              children: [
                                const Text(
                                  'Погода',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Точный прогноз каждый день',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Индикатор загрузки внизу экрана.
                  Positioned(
                    bottom: 64,
                    left: 0,
                    right: 0,
                    child: FadeTransition(
                      opacity: _titleFade,
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return FadeTransition(
      opacity: _logoFade,
      child: ScaleTransition(
        scale: _logoScale,
        child: SizedBox(
          width: 168,
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Мягкое пульсирующее свечение позади иконки.
              AnimatedBuilder(
                animation: _loopController,
                builder: (context, child) {
                  final glow = 0.35 + (_loopController.value * 0.25);
                  return Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD97D).withOpacity(glow * 0.5),
                          blurRadius: 60,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Лучи солнца, медленно вращающиеся позади облака.
              AnimatedBuilder(
                animation: _sunRayRotation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _sunRayRotation.value * 2 * math.pi,
                    child: child,
                  );
                },
                child: CustomPaint(
                  size: const Size(150, 150),
                  painter: _SunRaysPainter(),
                ),
              ),

              // Солнце
              Positioned(
                left: 24,
                top: 22,
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFFFFF3D6), Color(0xFFFFC24B)],
                      center: Alignment(-0.3, -0.3),
                    ),
                  ),
                ),
              ),

              // Облако, слегка покачивающееся из стороны в сторону.
              AnimatedBuilder(
                animation: _cloudDrift,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_cloudDrift.value * 4, 0),
                    child: child,
                  );
                },
                child: const Icon(
                  Icons.cloud_rounded,
                  size: 108,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAmbientDots() {
    // Небольшой фиксированный набор "звёздочек"/бликов для лёгкой атмосферы,
    // без реального рандома, чтобы позиции были стабильны между кадрами.
    const positions = [
      Offset(0.12, 0.18),
      Offset(0.85, 0.12),
      Offset(0.78, 0.32),
      Offset(0.18, 0.75),
      Offset(0.88, 0.68),
      Offset(0.5, 0.08),
      Offset(0.08, 0.5),
    ];

    return positions.asMap().entries.map((entry) {
      final i = entry.key;
      final pos = entry.value;
      return AnimatedBuilder(
        animation: _loopController,
        builder: (context, child) {
          final phase = (_loopController.value + (i * 0.15)) % 1.0;
          final opacity = (math.sin(phase * math.pi) * 0.45).clamp(0.0, 1.0);
          return Positioned(
            left: pos.dx * MediaQuery.of(context).size.width,
            top: pos.dy * MediaQuery.of(context).size.height,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }
}

/// Рисует простые лёгкие лучи солнца, расходящиеся из центра.
class _SunRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2 - 20, size.height / 2 - 20);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const rayCount = 8;
    const innerRadius = 40.0;
    const outerRadius = 54.0;

    for (int i = 0; i < rayCount; i++) {
      final angle = (2 * math.pi / rayCount) * i;
      final start = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );
      final end = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SunRaysPainter oldDelegate) => false;
}
