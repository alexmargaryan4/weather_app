import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../localization/app_localizations.dart';
import '../models/weather_model.dart';
import '../utils/temperature_utils.dart';

/// Виды уведомлений, различаются числовым id канала/группы, чтобы можно
/// было независимо отменять и перепланировать каждый вид, не трогая
/// остальные.
class NotificationIds {
  static const dailySummary = 1001;
  static const rainSoon = 1002;
  static const tempDrop = 1003;
  static const tempRise = 1004;
}

/// Отвечает за весь жизненный цикл локальных уведомлений: инициализацию
/// плагина, запрос разрешений (Android 13+ и iOS отдельно требуют явного
/// разрешения), планирование ежедневной повторяющейся сводки погоды и
/// показ разовых алертов о резкой смене погоды.
///
/// Сам сервис не решает, ЧТО отправлять в фоне — это делает
/// [WeatherWatcherTask] (Workmanager-задача), которая раз в некоторое
/// время сверяет свежие данные с последним сохранённым снимком погоды и
/// вызывает методы show*Alert здесь, если разница существенная.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Ключи SharedPreferences, под которыми фоновая задача хранит последний
  /// увиденный снимок погоды (для сравнения "было/стало" между запусками).
  /// Вынесены сюда как константы, чтобы UI-слой (при необходимости сбросить
  /// историю сравнения, например при смене города) не дублировал строки.
  static const snapshotTempKey = 'notif_last_temp';
  static const snapshotPopKey = 'notif_last_pop';
  static const snapshotCityKey = 'notif_last_city';

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    // Явную локальную таймзону устройства без плагина timezone-с-геолокацией
    // получить нельзя без нативного вызова, поэтому используем таймзону,
    // которую определяет сам движок Dart из системных настроек через
    // DateTime.now(); .toLocal() уже учитывает её при показе, а для
    // scheduling'а плагину нужен явный tz.Location — берём смещение
    // текущего момента и подбираем ближайшую по UTC-офсету зону.
    tz.setLocalLocation(tz.getLocation(_guessTimeZoneName()));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'daily_summary',
          'Daily weather summary',
          description: 'Morning notification with today\'s forecast',
          importance: Importance.defaultImportance,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'weather_alerts',
          'Weather alerts',
          description: 'Sudden weather changes',
          importance: Importance.high,
        ),
      );
    }
  }

  // Плагин timezone не умеет сам определить системную таймзону без
  // доп. плагина вроде flutter_timezone — для локальных уведомлений
  // достаточно приблизительного подбора по текущему смещению UTC, так как
  // нам важна разница между "сейчас" и "время сводки", а не точное имя
  // зоны. Если точное совпадение не найдено, используем UTC как безопасный
  // fallback (уведомление всё равно придёт, но, возможно, будет сдвинуто
  // относительно локального времени пользователя на величину его сдвига
  // от UTC, если система поменяет DST на границе).
  String _guessTimeZoneName() {
    final offset = DateTime.now().timeZoneOffset;
    final hours = offset.inMinutes / 60.0;
    final sign = hours >= 0 ? '+' : '-';
    final absHours = hours.abs().floor();
    final candidates = {
      '+4.0': 'Asia/Yerevan',
      '+3.0': 'Europe/Moscow',
      '+0.0': 'UTC',
      '-5.0': 'America/New_York',
      '-8.0': 'America/Los_Angeles',
      '+1.0': 'Europe/Berlin',
      '+2.0': 'Europe/Kyiv',
      '+5.5': 'Asia/Kolkata',
      '+9.0': 'Asia/Tokyo',
    };
    final key = '$sign${absHours.toString()}.${((hours.abs() - absHours) * 60 == 30 ? 5 : 0)}';
    return candidates[key] ?? 'UTC';
  }

  /// Запрашивает системное разрешение на уведомления. На Android 13+ и iOS
  /// без этого показ уведомлений молча ничего не делает. Возвращает true,
  /// если разрешение получено (или уже было получено ранее).
  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final enabled = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      return enabled ?? true;
    }
    return true;
  }

  /// Планирует ежедневное повторяющееся уведомление в заданное время с
  /// текстом, уже отрендеренным вызывающей стороной (HomeScreen знает
  /// актуальные данные погоды и локализацию, сервис — нет).
  Future<void> scheduleDailySummary({
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      NotificationIds.dailySummary,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_summary',
          'Daily weather summary',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailySummary() async {
    await init();
    await _plugin.cancel(NotificationIds.dailySummary);
  }

  Future<void> showRainSoonAlert(
      {required String title, required String body}) async {
    await init();
    await _plugin.show(
      NotificationIds.rainSoon,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weather_alerts',
          'Weather alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showTempChangeAlert({
    required bool isRising,
    required String title,
    required String body,
  }) async {
    await init();
    await _plugin.show(
      isRising ? NotificationIds.tempRise : NotificationIds.tempDrop,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weather_alerts',
          'Weather alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Сравнивает свежие данные погоды с последним сохранённым снимком и
  /// показывает подходящий алерт, если изменение достаточно значимое.
  /// Используется и из фоновой Workmanager-задачи, и (опционально) сразу
  /// после ручного обновления на экране, чтобы логика сравнения не
  /// дублировалась в двух местах.
  ///
  /// Пороги: скачок температуры на 5°C и более, либо вероятность осадков
  /// в ближайшие 2 часа выше 50%, когда до этого было ниже 30% —
  /// намеренно консервативные значения, чтобы не спамить уведомлениями на
  /// обычные суточные колебания погоды.
  Future<void> checkAndNotifySevereChange(
    WeatherData current,
    AppLocalizations l10n,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTemp = prefs.getDouble(snapshotTempKey);
    final lastPop = prefs.getDouble(snapshotPopKey);

    final nextPop = current.hourly.take(2).isEmpty
        ? (current.precipitationProbability ?? 0)
        : current.hourly
            .take(2)
            .map((h) => h.pop)
            .reduce((a, b) => a > b ? a : b);

    if (lastPop != null && lastPop < 0.3 && nextPop >= 0.5) {
      await showRainSoonAlert(
        title: l10n.notificationRainSoonTitle,
        body: l10n.notificationRainSoonBody(current.cityName),
      );
    }

    if (lastTemp != null) {
      final delta = current.temp - lastTemp;
      if (delta <= -5) {
        await showTempChangeAlert(
          isRising: false,
          title: l10n.notificationTempDropTitle,
          body: l10n.notificationTempDropBody(current.cityName),
        );
      } else if (delta >= 5) {
        await showTempChangeAlert(
          isRising: true,
          title: l10n.notificationTempRiseTitle,
          body: l10n.notificationTempRiseBody(current.cityName),
        );
      }
    }

    await prefs.setDouble(snapshotTempKey, current.temp);
    await prefs.setDouble(snapshotPopKey, nextPop);
    await prefs.setString(snapshotCityKey, current.cityName);
  }

  /// Готовит текст ежедневной сводки на основе текущих данных погоды —
  /// вынесено сюда, а не в HomeScreen, чтобы фоновая задача (у которой нет
  /// живого BuildContext) могла построить тот же текст самостоятельно.
  String buildDailySummaryBody(
    WeatherData weather,
    AppLocalizations l10n,
    bool useFahrenheit,
  ) {
    final temp = TemperatureUtils.format(weather.temp, useFahrenheit);
    final desc = weather.description.isEmpty
        ? ''
        : weather.description[0].toUpperCase() +
            weather.description.substring(1);
    return '${weather.cityName}: $temp, $desc';
  }
}
