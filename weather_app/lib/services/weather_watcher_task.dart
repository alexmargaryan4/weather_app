import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import '../localization/app_localizations.dart';
import '../models/weather_model.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/notification_settings_service.dart';
import '../services/settings_service.dart';
import '../services/weather_service.dart';

/// Уникальное имя периодической Workmanager-задачи. Регистрируется один
/// раз при первом включении любого из уведомлений и снимается, когда оба
/// вида уведомлений выключены — чтобы не тратить батарею в фоне, если
/// пользователю уведомления не нужны вовсе.
const String _periodicTaskName = 'weather_watcher_periodic';
const String _uniqueTaskId = 'weather_watcher_task_id';

/// Точка входа, которую вызывает нативная сторона (Android — через
/// плагин Workmanager, отдельный isolate без доступа к состоянию основного
/// приложения). ДОЛЖНА быть top-level функцией с аннотацией
/// @pragma('vm:entry-point'), иначе релизная сборка Android отрежет её при
/// tree-shaking, и фоновые срабатывания молча ничего не будут делать.
@pragma('vm:entry-point')
void weatherWatcherCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await WeatherWatcherTask._runCheck();
    } catch (_) {
      // Фоновая задача никогда не должна "ронять" систему повторных
      // попыток Workmanager из-за временной ошибки сети/API — просто
      // пробуем снова на следующем цикле.
    }
    return true;
  });
}

/// Управляет регистрацией фоновой задачи проверки погоды и содержит саму
/// логику одного цикла проверки (вызывается и из isolate Workmanager, и
/// потенциально сразу после запуска приложения для отладки).
///
/// На iOS Workmanager работает по правилам BGTaskScheduler (система сама
/// решает, когда запускать фоновую задачу, обычно не чаще нескольких раз
/// в час, и только при определённых условиях — заряд, сеть, приложение
/// использовалось недавно), поэтому точное время ежедневной сводки там
/// не гарантировано с точностью до минуты, в отличие от Android, где
/// zonedSchedule в NotificationService сам справляется с точным временем
/// без участия Workmanager вовсе.
class WeatherWatcherTask {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await Workmanager().initialize(weatherWatcherCallbackDispatcher);
  }

  /// Регистрирует или снимает периодическую задачу в зависимости от того,
  /// включён ли хотя бы один вид уведомлений. Вызывается при каждом
  /// изменении переключателей на экране настроек уведомлений, а также при
  /// старте приложения, чтобы синхронизировать состояние задачи с
  /// сохранёнными настройками (на случай, если пользователь поменял их в
  /// предыдущей версии приложения без этой синхронизации).
  static Future<void> updateRegistration() async {
    await init();
    final settings = NotificationSettingsService();
    final dailyEnabled = await settings.getDailySummaryEnabled();
    final severeEnabled = await settings.getSevereAlertsEnabled();

    if (!dailyEnabled && !severeEnabled) {
      await Workmanager().cancelByUniqueName(_uniqueTaskId);
      return;
    }

    // 15 минут — минимальный интервал, который допускает Android для
    // периодических задач Workmanager; система в любом случае может
    // отложить запуск дольше этого значения в целях экономии батареи.
    await Workmanager().registerPeriodicTask(
      _uniqueTaskId,
      _periodicTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  /// Пересобирает расписание ежедневной сводки (используется при
  /// включении сводки или изменении времени на экране настроек) —
  /// показывает актуальный текст сразу же на основе последних известных
  /// данных о погоде, если они есть, и планирует системное уведомление на
  /// заданное время через [NotificationService.scheduleDailySummary].
  static Future<void> rescheduleDailySummary() async {
    await updateRegistration();
    final settingsService = SettingsService();
    final notifSettings = NotificationSettingsService();
    final time = await notifSettings.getDailySummaryTime();
    final lastCity = await settingsService.getLastCity();

    // Заголовок уведомления не зависит от данных о погоде и локали в
    // фоновом isolate недоступен настолько же просто, как в UI — здесь
    // используется системная локаль устройства напрямую, без BuildContext.
    final locale = PlatformDispatcher.instance.locale;
    final l10n = AppLocalizations(locale);

    String body = lastCity ?? '';
    try {
      final weatherService = WeatherService();
      final useFahrenheit = await settingsService.getUseFahrenheit();
      WeatherData weather;
      if (lastCity != null && lastCity.isNotEmpty) {
        weather = await weatherService.getWeatherByCityName(lastCity,
            langCode: l10n.weatherApiLangCode);
      } else {
        final position = await LocationService().getCurrentLocation();
        weather = await weatherService.getWeatherByCoordinates(
          position.latitude,
          position.longitude,
          langCode: l10n.weatherApiLangCode,
        );
      }
      body = NotificationService.instance
          .buildDailySummaryBody(weather, l10n, useFahrenheit);
    } catch (_) {
      // Если погоду прямо сейчас получить не удалось (нет сети и т.п.),
      // всё равно планируем уведомление с заголовком без деталей погоды —
      // лучше напомнить пользователю открыть приложение, чем не прислать
      // уведомление вовсе. Актуальный текст будет подхвачен при следующем
      // срабатывании фоновой задачи.
    }

    await NotificationService.instance.scheduleDailySummary(
      time: time,
      title: l10n.notificationDailyTitle,
      body: body,
    );
  }

  /// Один цикл фоновой проверки: получает свежие данные о погоде для
  /// последнего открытого города (или геолокации, если город не сохранён)
  /// и, если включены алерты о резких изменениях, сравнивает со снимком
  /// из прошлого цикла через [NotificationService.checkAndNotifySevereChange].
  static Future<void> _runCheck() async {
    final settingsService = SettingsService();
    final notifSettings = NotificationSettingsService();
    final severeEnabled = await notifSettings.getSevereAlertsEnabled();
    if (!severeEnabled) return;

    final lastCity = await settingsService.getLastCity();
    final locale = PlatformDispatcher.instance.locale;
    final l10n = AppLocalizations(locale);
    final weatherService = WeatherService();

    WeatherData weather;
    if (lastCity != null && lastCity.isNotEmpty) {
      weather = await weatherService.getWeatherByCityName(lastCity,
          langCode: l10n.weatherApiLangCode);
    } else {
      final position = await LocationService().getCurrentLocation();
      weather = await weatherService.getWeatherByCoordinates(
        position.latitude,
        position.longitude,
        langCode: l10n.weatherApiLangCode,
      );
    }

    await NotificationService.instance.checkAndNotifySevereChange(weather, l10n);
  }
}
