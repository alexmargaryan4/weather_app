import 'dart:math' as math;

/// Виды фаз луны для отображения в UI.
enum MoonPhaseType {
  newMoon,
  waxingCrescent,
  firstQuarter,
  waxingGibbous,
  fullMoon,
  waningGibbous,
  lastQuarter,
  waningCrescent,
}

/// Результат расчёта фазы луны на конкретную дату.
class MoonPhaseInfo {
  // Возраст луны в долях синодического месяца: 0.0 = новолуние,
  // 0.5 = полнолуние, дальше снова к 1.0 = новолуние.
  final double age;
  final MoonPhaseType type;
  // Доля освещённого диска (0.0 = совсем тёмный, 1.0 = полностью освещён) —
  // используется для отрисовки полумесяца на карточке.
  final double illumination;

  MoonPhaseInfo({
    required this.age,
    required this.type,
    required this.illumination,
  });
}

/// Простой астрономический расчёт фазы луны без сторонних пакетов —
/// точность около +/-1 дня, чего более чем достаточно для отображения
/// иконки и названия фазы в приложении погоды (не для точных расчётов
/// затмений и т.п.).
class MoonPhaseUtils {
  // Известное новолуние, взятое как опорная точка расчёта
  // (6 января 2000, 18:14 UTC).
  static final DateTime _knownNewMoon = DateTime.utc(2000, 1, 6, 18, 14);

  // Средняя длительность синодического месяца (от новолуния до новолуния).
  static const double _synodicMonthDays = 29.53058867;

  static MoonPhaseInfo calculate(DateTime date) {
    final diffMinutes =
        date.toUtc().difference(_knownNewMoon).inMinutes.toDouble();
    final diffDays = diffMinutes / (60 * 24);

    double age = (diffDays % _synodicMonthDays) / _synodicMonthDays;
    if (age < 0) age += 1.0;

    // Освещённость диска: 0 в новолуние, 1 в полнолуние, снова 0 в новолуние —
    // косинусная кривая по возрасту луны даёт достаточно точное приближение
    // без полной орбитальной модели.
    final illumination = (1 - math.cos(2 * math.pi * age)) / 2;

    final type = _typeForAge(age);

    return MoonPhaseInfo(age: age, type: type, illumination: illumination);
  }

  static MoonPhaseType _typeForAge(double age) {
    if (age < 0.03 || age >= 0.97) return MoonPhaseType.newMoon;
    if (age < 0.22) return MoonPhaseType.waxingCrescent;
    if (age < 0.28) return MoonPhaseType.firstQuarter;
    if (age < 0.47) return MoonPhaseType.waxingGibbous;
    if (age < 0.53) return MoonPhaseType.fullMoon;
    if (age < 0.72) return MoonPhaseType.waningGibbous;
    if (age < 0.78) return MoonPhaseType.lastQuarter;
    return MoonPhaseType.waningCrescent;
  }
}
