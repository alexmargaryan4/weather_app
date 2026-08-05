/// Аналитика отключена.
///
/// Раньше этот сервис отправлял анонимную статистику (устройства,
/// избранные города, запросы погоды) в Supabase для внутренней панели
/// разработчика. Сейчас отправка данных полностью отключена: методы
/// оставлены на месте (чтобы не менять вызовы в остальных частях
/// приложения), но ничего не делают и никуда не обращаются по сети.
///
/// Приложение больше не подключается к Supabase, ничего не хранит и не
/// отправляет с устройства пользователя.
class AnalyticsService {
  static AnalyticsService? _instance;
  static AnalyticsService get instance => _instance ??= AnalyticsService._();
  AnalyticsService._();

  /// Ничего не делает — аналитика отключена.
  static Future<void> init() async {}

  /// Ничего не делает — аналитика отключена.
  Future<void> trackAppOpen({String? countryCode, String? cityName}) async {}

  /// Ничего не делает — аналитика отключена.
  Future<void> trackWeatherRequest({
    required String cityName,
    String? countryCode,
    required String source,
  }) async {}

  /// Ничего не делает — аналитика отключена.
  Future<void> trackFavoriteAdded(String cityName, {String? countryCode}) async {}

  /// Ничего не делает — аналитика отключена.
  Future<void> trackFavoriteRemoved(String cityName) async {}

  bool get isReady => false;
}
