/// Утилиты для перевода и форматирования температуры.
/// Все данные из API приходят в градусах Цельсия (units=metric);
/// эти функции только меняют то, что видит пользователь.
class TemperatureUtils {
  static double celsiusToDisplay(double celsius, bool useFahrenheit) {
    if (!useFahrenheit) return celsius;
    return celsius * 9 / 5 + 32;
  }

  static String format(double celsius, bool useFahrenheit) {
    final value = celsiusToDisplay(celsius, useFahrenheit);
    return '${value.round()}°';
  }
}
