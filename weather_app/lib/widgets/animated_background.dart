import 'package:flutter/material.dart';

class AnimatedWeatherBackground extends StatelessWidget {
  final String iconCode;
  final Widget child;

  const AnimatedWeatherBackground({
    super.key,
    required this.iconCode,
    required this.child,
  });

  // Подбираем градиент под тип погоды и время суток (день/ночь определяется по суффиксу иконки 'd'/'n')
  List<Color> _getGradientColors() {
    final isNight = iconCode.endsWith('n');
    final code = iconCode.substring(0, 2);

    if (isNight) {
      return [const Color(0xFF0F1C3F), const Color(0xFF2C3E67)];
    }

    switch (code) {
      case '01': // ясно
        return [const Color(0xFF4A90D9), const Color(0xFF87CEEB)];
      case '02':
      case '03':
      case '04': // облачно
        return [const Color(0xFF6B8CAE), const Color(0xFFA8C0D6)];
      case '09':
      case '10': // дождь
        return [const Color(0xFF3E4A5C), const Color(0xFF6B7B8C)];
      case '11': // гроза
        return [const Color(0xFF2C2F3B), const Color(0xFF4A4E5C)];
      case '13': // снег
        return [const Color(0xFF7B96AD), const Color(0xFFC9D6E3)];
      default:
        return [const Color(0xFF4A90D9), const Color(0xFF87CEEB)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _getGradientColors(),
        ),
      ),
      child: child,
    );
  }
}