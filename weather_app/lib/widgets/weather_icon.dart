import 'package:flutter/material.dart';

class WeatherIcon extends StatelessWidget {
  final String iconCode;
  final double size;

  const WeatherIcon({super.key, required this.iconCode, this.size = 40});

  IconData _getIconData() {
    final isNight = iconCode.endsWith('n');
    final code = iconCode.substring(0, 2);

    switch (code) {
      case '01':
        return isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded;
      case '02':
        return isNight ? Icons.nights_stay_rounded : Icons.wb_cloudy_rounded;
      case '03':
      case '04':
        return Icons.cloud_rounded;
      case '09':
        return Icons.grain_rounded;
      case '10':
        return Icons.water_drop_rounded;
      case '11':
        return Icons.thunderstorm_rounded;
      case '13':
        return Icons.ac_unit_rounded;
      case '50':
        return Icons.foggy;
      default:
        return Icons.wb_sunny_rounded;
    }
  }

  Color _getIconColor() {
    final isNight = iconCode.endsWith('n');
    final code = iconCode.substring(0, 2);

    if (code == '01' && !isNight) return Colors.amber;
    if (isNight) return Colors.blueGrey.shade100;
    if (code == '13') return Colors.white;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Icon(
      _getIconData(),
      size: size,
      color: _getIconColor(),
    );
  }
}