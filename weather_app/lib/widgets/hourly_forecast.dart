import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../localization/app_localizations.dart';
import '../models/weather_model.dart';
import '../utils/temperature_utils.dart';
import 'weather_icon.dart';

class HourlyForecastList extends StatelessWidget {
  final List<HourlyForecast> hourly;
  final bool useFahrenheit;

  const HourlyForecastList({
    super.key,
    required this.hourly,
    this.useFahrenheit = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              l10n.hourlyForecast,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 128,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: hourly.length,
              itemBuilder: (context, index) {
                final item = hourly[index];
                final isNow = index == 0;
                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 400 + (index * 80)),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 20),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isNow
                          ? Colors.white.withOpacity(0.22)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(32),
                      border: isNow
                          ? Border.all(
                              color: Colors.white.withOpacity(0.3), width: 1)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isNow
                              ? l10n.now
                              : DateFormat.Hm(l10n.dateFormatLocale)
                                  .format(item.time),
                          style: TextStyle(
                            color: isNow ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight:
                                isNow ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 10),
                        WeatherIcon(iconCode: item.iconCode, size: 30),
                        const SizedBox(height: 10),
                        Text(
                          TemperatureUtils.format(item.temp, useFahrenheit),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
