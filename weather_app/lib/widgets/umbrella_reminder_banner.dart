import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

/// Баннер-напоминание "возьмите зонт", показывается только когда вероятность
/// осадков в ближайшие часы достаточно высокая (см. порог в HomeScreen).
class UmbrellaReminderBanner extends StatelessWidget {
  const UmbrellaReminderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF4FA8FF).withOpacity(0.22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF4FA8FF).withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.umbrella_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.umbrellaReminderTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.umbrellaReminderBody,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
