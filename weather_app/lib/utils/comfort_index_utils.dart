/// Категории итогового индекса комфорта — используются для цвета и подписи
/// в UI, а также при желании пользователя расширить список категорий.
enum ComfortLevel {
  excellent,
  good,
  moderate,
  poor,
  bad,
}

class ComfortIndexResult {
  // Итоговое значение индекса комфорта: 0 (совсем некомфортно) .. 100 (идеально).
  final int score;
  final ComfortLevel level;

  ComfortIndexResult({required this.score, required this.level});
}

/// Рассчитывает "Индекс комфорта" пребывания на улице (0..100) на основе
/// температуры, влажности, ветра, УФ-индекса и вероятности дождя.
///
/// Это не официальная метеорологическая формула (единого стандарта для
/// такого сводного индекса не существует), а прозрачная эвристика:
/// начинаем со 100 баллов и вычитаем штрафы за каждый фактор, который
/// уводит условия от "идеальных для прогулки" (около 20-24°C, лёгкий
/// ветер, умеренная влажность, без дождя и без сильного солнца).
class ComfortIndexUtils {
  static ComfortIndexResult calculate({
    required double tempCelsius,
    required int humidityPercent,
    required double windSpeedMs,
    double? uvIndex,
    double? precipitationProbability, // 0.0..1.0
  }) {
    double score = 100;

    // --- Температура: идеал ~21°C, штраф растёт по мере отклонения. ---
    const idealTemp = 21.0;
    final tempDiff = (tempCelsius - idealTemp).abs();
    if (tempDiff > 2) {
      // До 2 градусов отклонения — не штрафуем вовсе (комфортный диапазон).
      final penalizedDiff = tempDiff - 2;
      // Штраф растёт быстрее для экстремальных значений (квадратично),
      // чтобы, например, -10°C или +38°C давали действительно низкий балл.
      score -= (penalizedDiff * 2.2) + (penalizedDiff * penalizedDiff * 0.06);
    }

    // --- Влажность: идеал 40-60%. ---
    if (humidityPercent < 40) {
      score -= (40 - humidityPercent) * 0.35;
    } else if (humidityPercent > 60) {
      score -= (humidityPercent - 60) * 0.45;
    }
    // Высокая влажность при высокой температуре ощущается ещё тяжелее —
    // добавляем дополнительный штраф за духоту (аналог "точки росы").
    if (tempCelsius > 25 && humidityPercent > 60) {
      score -= (tempCelsius - 25) * (humidityPercent - 60) * 0.05;
    }

    // --- Ветер: лёгкий ветер приятен, сильный — некомфортен (а на холоде
    // ещё и усиливает ощущение мороза). ---
    if (windSpeedMs > 4) {
      score -= (windSpeedMs - 4) * 3.0;
    }
    if (tempCelsius < 10 && windSpeedMs > 2) {
      score -= (windSpeedMs - 2) * (10 - tempCelsius) * 0.15;
    }

    // --- УФ-индекс: 0-2 безопасно, дальше растущий штраф. ---
    if (uvIndex != null && uvIndex > 2) {
      score -= (uvIndex - 2) * 4.0;
    }

    // --- Вероятность дождя: прямой штраф, до 25 баллов при 100% дожде. ---
    if (precipitationProbability != null) {
      score -= precipitationProbability * 25;
    }

    final clamped = score.clamp(0, 100).round();
    return ComfortIndexResult(score: clamped, level: _levelFor(clamped));
  }

  static ComfortLevel _levelFor(int score) {
    if (score >= 85) return ComfortLevel.excellent;
    if (score >= 65) return ComfortLevel.good;
    if (score >= 45) return ComfortLevel.moderate;
    if (score >= 25) return ComfortLevel.poor;
    return ComfortLevel.bad;
  }
}
