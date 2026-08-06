import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Хранит пользовательские настройки уведомлений между запусками:
/// — включена ли ежедневная утренняя сводка и во сколько её присылать;
/// — включены ли алерты о резкой смене погоды (дождь/похолодание/
///   потепление в ближайшие часы).
///
/// Сами уведомления планирует/показывает [NotificationService] — этот
/// класс отвечает только за хранение выбора пользователя, чтобы оба места
/// (экран настроек и фоновая задача) читали одни и те же значения.
class NotificationSettingsService {
  static const _keyDailyEnabled = 'notif_daily_enabled';
  static const _keyDailyHour = 'notif_daily_hour';
  static const _keyDailyMinute = 'notif_daily_minute';
  static const _keySevereEnabled = 'notif_severe_enabled';

  Future<bool> getDailySummaryEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDailyEnabled) ?? false;
  }

  Future<void> setDailySummaryEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDailyEnabled, value);
  }

  /// Время дня, в которое присылать ежедневную сводку. По умолчанию 8:00.
  Future<TimeOfDay> getDailySummaryTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_keyDailyHour) ?? 8;
    final minute = prefs.getInt(_keyDailyMinute) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setDailySummaryTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDailyHour, time.hour);
    await prefs.setInt(_keyDailyMinute, time.minute);
  }

  Future<bool> getSevereAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySevereEnabled) ?? false;
  }

  Future<void> setSevereAlertsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySevereEnabled, value);
  }
}
