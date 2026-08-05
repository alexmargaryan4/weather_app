import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Отправляет анонимную аналитику в Supabase: устройства, избранные города
/// и запросы погоды. Пользователь не регистрируется — идентифицируется
/// случайным [device_id], сгенерированным один раз и сохранённым локально.
///
/// Каждый публичный метод обёрнут в try/catch и никогда не бросает исключение
/// наружу: аналитика не должна мешать основной функциональности приложения.
/// Если нет интернета или Supabase недоступен — событие просто теряется.
class AnalyticsService {
  static const _keyDeviceId = 'analytics_device_id';
  static const _uuid = Uuid();

  // --- Вставьте сюда свои значения из Supabase → Project Settings → API ---
  static const String supabaseUrl = 'https://wfmrdhztcypxojajwihp.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndmbXJkaHp0Y3lweG9qYWp3aWhwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU4NTQ2MzMsImV4cCI6MjEwMTQzMDYzM30.GKRaA-MP6Y61FtdauOO6U06i6d_Lcq81LRwMi0waDAk';
  // --------------------------------------------------------------------

  static AnalyticsService? _instance;
  static AnalyticsService get instance => _instance ??= AnalyticsService._();
  AnalyticsService._();

  String? _deviceId;
  bool _initialized = false;

  SupabaseClient get _client => Supabase.instance.client;

  /// Инициализировать Supabase SDK. Вызвать один раз при старте приложения,
  /// до runApp (см. main.dart).
  static Future<void> init() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
    } catch (_) {
      // Если инициализация не удалась (например, нет сети при первом
      // запуске) — приложение всё равно должно продолжить работать.
      // Дальнейшие вызовы аналитики просто будут молча падать в catch.
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_keyDeviceId);
    if (id == null) {
      id = _uuid.v4();
      await prefs.setString(_keyDeviceId, id);
    }
    _deviceId = id;
    return id;
  }

  /// Вызвать один раз при старте приложения (после инициализации Supabase).
  /// Регистрирует устройство при первом запуске / обновляет last_seen_at.
  ///
  /// ВРЕМЕННАЯ ДИАГНОСТИКА: возвращает текст ошибки (или null при успехе),
  /// чтобы её можно было показать на экране и понять, почему аналитика
  /// не доходит до Supabase. Убрать возврат String? и вернуть Future<void>
  /// после того, как проблема будет найдена и исправлена.
  Future<String?> trackAppOpen({String? countryCode, String? cityName}) async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      final locale = PlatformDispatcher.instance.locale.languageCode;
      String? appVersion;
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = info.version;
      } catch (_) {
        appVersion = null;
      }

      await _client.from('devices').upsert({
        'device_id': deviceId,
        'last_seen_at': DateTime.now().toIso8601String(),
        'app_version': appVersion,
        'platform': _platformName(),
        'locale': locale,
        if (countryCode != null) 'country_code': countryCode,
        if (cityName != null) 'city_name': cityName,
      }, onConflict: 'device_id');

      _initialized = true;
      return null;
    } catch (e) {
      return '[Диагностика] trackAppOpen: $e';
    }
  }

  /// Записать факт запроса погоды (для топ городов/стран и графиков).
  /// [source] — 'geolocation' или 'search'.
  Future<void> trackWeatherRequest({
    required String cityName,
    String? countryCode,
    required String source,
  }) async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      await _client.from('weather_requests').insert({
        'device_id': deviceId,
        'city_name': cityName,
        'country_code': countryCode,
        'source': source,
      });
    } catch (_) {
      // Не критично — пропускаем.
    }
  }

  /// Записать добавление города в избранное.
  Future<void> trackFavoriteAdded(String cityName, {String? countryCode}) async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      await _client.from('favorite_cities').insert({
        'device_id': deviceId,
        'city_name': cityName,
        'country_code': countryCode,
      });
    } catch (_) {
      // Не критично.
    }
  }

  /// Записать удаление города из избранного (мягкое удаление —
  /// помечаем последнюю активную запись как removed, а не стираем историю).
  Future<void> trackFavoriteRemoved(String cityName) async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      await _client
          .from('favorite_cities')
          .update({'removed_at': DateTime.now().toIso8601String()})
          .eq('device_id', deviceId)
          .eq('city_name', cityName)
          .filter('removed_at', 'is', null);
    } catch (_) {
      // Не критично.
    }
  }

  bool get isReady => _initialized;

  String _platformName() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isWindows) return 'windows';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
    } catch (_) {
      // Platform может бросить исключение на некоторых платформах —
      // это не критично для аналитики.
    }
    return 'unknown';
  }
}
