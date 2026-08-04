import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';

/// Виды ошибок, которые может выбросить [WeatherService]. Сам сервис не
/// хранит текстов сообщений (он не имеет доступа к выбранному языку
/// интерфейса) — это позволяет UI-слою (например, HomeScreen) подобрать
/// локализованный текст через AppLocalizations по коду ошибки.
enum WeatherErrorType {
  auth,
  notFound,
  cityNotFound,
  rateLimit,
  noInternet,
  forecastLoad,
  generic,
}

class WeatherServiceException implements Exception {
  final WeatherErrorType type;
  final int? statusCode;

  WeatherServiceException(this.type, {this.statusCode});

  @override
  String toString() => 'WeatherServiceException($type, code: $statusCode)';
}

class WeatherService {
  // Вставьте сюда свой API-ключ с OpenWeatherMap
  static const String apiKey = 'd76b6cdb234d933ccca184840dce91ee';

  // Простой in-memory кэш последнего ответа по каждому городу/геолокации.
  // Он живёт, пока не закрыто приложение (WeatherService создаётся один раз
  // в HomeScreen), и позволяет мгновенно показать данные при возврате к уже
  // открытому городу, не дожидаясь сети — самая частая причина "нескольких
  // секунд ожидания" при переключении между вкладками городов.
  final Map<String, _CacheEntry> _cache = {};

  // Сколько кэш считается "свежим" и не требует фонового обновления сразу
  // после мгновенного показа.
  static const Duration _freshFor = Duration(minutes: 10);

  WeatherData? peekCache(String key) => _cache[key]?.data;

  bool isFresh(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    return DateTime.now().difference(entry.timestamp) < _freshFor;
  }

  static const String currentWeatherUrl =
      'https://api.openweathermap.org/data/2.5/weather';
  static const String forecastUrl =
      'https://api.openweathermap.org/data/2.5/forecast';
  static const String airPollutionUrl =
      'https://api.openweathermap.org/data/2.5/air_pollution';

  // Open-Meteo не требует API-ключа и отдаёт видимость (в метрах) как
  // рассчитанную модельную величину без "потолка" в 10 км, в отличие от
  // OpenWeatherMap, где станции часто просто не измеряют больше 10000 м.
  // Используется ТОЛЬКО для видимости — вся остальная погода по-прежнему
  // берётся из OpenWeatherMap, как и раньше.
  static const String openMeteoUrl = 'https://api.open-meteo.com/v1/forecast';

  // Получить погоду по координатам (используется для геолокации).
  // [cacheKey] позволяет вызывающей стороне (HomeScreen) сохранить результат
  // под стабильным ключом ("geo"), даже если coordinates каждый раз чуть
  // отличаются из-за погрешности GPS.
  // [langCode] — код языка для описания погоды от OpenWeatherMap
  // (см. AppLocalizations.weatherApiLangCode); по умолчанию русский, чтобы
  // поведение не изменилось для существующих вызовов без явного языка.
  Future<WeatherData> getWeatherByCoordinates(double lat, double lon,
      {String? cacheKey, String langCode = 'ru'}) async {
    // Запускаем все запросы одновременно, а не по очереди — раньше каждый
    // "await" ждал предыдущий запрос целиком, из-за чего суммарное время
    // загрузки было суммой всех запросов (несколько секунд). Погода,
    // прогноз, качество воздуха и видимость друг от друга не зависят,
    // поэтому их можно грузить параллельно и просто подождать самый долгий.
    final results = await Future.wait<Object?>([
      _get('$currentWeatherUrl?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=$langCode'),
      _get('$forecastUrl?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=$langCode'),
      _fetchAirQuality(lat, lon),
      _fetchVisibility(lat, lon),
    ]);

    final currentResponse = results[0] as http.Response;
    final forecastResponse = results[1] as http.Response;
    final airQuality = results[2] as int?;
    final visibility = results[3] as int?;

    if (currentResponse.statusCode == 200 &&
        forecastResponse.statusCode == 200) {
      final currentJson = jsonDecode(currentResponse.body);
      final forecastJson = jsonDecode(forecastResponse.body);
      var weather = WeatherData.fromJson(currentJson, forecastJson);
      weather = weather.copyWithAirQuality(airQuality);
      weather = weather.copyWithVisibility(visibility ?? weather.visibility);
      _store(cacheKey ?? 'geo', weather);
      _store(weather.cityName.toLowerCase(), weather);
      return weather;
    } else {
      throw _exceptionFor(currentResponse.statusCode);
    }
  }

  // Получить погоду по названию города (используется при ручном поиске
  // и при переключении между сохранёнными городами).
  Future<WeatherData> getWeatherByCityName(String cityName,
      {String langCode = 'ru'}) async {
    final currentResponse = await _get(
        '$currentWeatherUrl?q=${Uri.encodeComponent(cityName)}&appid=$apiKey&units=metric&lang=$langCode');

    if (currentResponse.statusCode != 200) {
      throw _exceptionFor(currentResponse.statusCode,
          notFound: WeatherErrorType.cityNotFound);
    }

    final currentJson = jsonDecode(currentResponse.body);
    final lat = (currentJson['coord']['lat'] as num).toDouble();
    final lon = (currentJson['coord']['lon'] as num).toDouble();

    // Прогноз, качество воздуха и видимость друг от друга не зависят —
    // запускаем их одновременно вместо ожидания по очереди.
    final results = await Future.wait<Object?>([
      _get('$forecastUrl?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=$langCode'),
      _fetchAirQuality(lat, lon),
      _fetchVisibility(lat, lon),
    ]);

    final forecastResponse = results[0] as http.Response;
    final airQuality = results[1] as int?;
    final visibility = results[2] as int?;

    if (forecastResponse.statusCode == 200) {
      final forecastJson = jsonDecode(forecastResponse.body);
      var weather = WeatherData.fromJson(currentJson, forecastJson);
      weather = weather.copyWithAirQuality(airQuality);
      weather = weather.copyWithVisibility(visibility ?? weather.visibility);
      _store(cityName.toLowerCase(), weather);
      _store(weather.cityName.toLowerCase(), weather);
      return weather;
    } else {
      throw WeatherServiceException(WeatherErrorType.forecastLoad);
    }
  }

  void _store(String key, WeatherData data) {
    _cache[key] = _CacheEntry(data, DateTime.now());
  }

  // Индекс качества воздуха (1..5). Возвращает null, если запрос не удался —
  // это второстепенные данные, и без них экран погоды всё равно должен работать.
  Future<int?> _fetchAirQuality(double lat, double lon) async {
    try {
      final response =
          await _get('$airPollutionUrl?lat=$lat&lon=$lon&appid=$apiKey');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final list = json['list'] as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          return list.first['main']['aqi'] as int;
        }
      }
    } catch (_) {
      // Игнорируем — качество воздуха необязательный виджет
    }
    return null;
  }

  // Видимость (в метрах) от Open-Meteo. Возвращает null при любой ошибке —
  // в этом случае просто останется значение от OpenWeatherMap (или null),
  // так что экран погоды никогда не сломается из-за этого запроса.
  Future<int?> _fetchVisibility(double lat, double lon) async {
    try {
      final response = await _get(
          '$openMeteoUrl?latitude=$lat&longitude=$lon&current=visibility');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final value = json['current']?['visibility'];
        if (value != null) {
          return (value as num).toInt();
        }
      }
    } catch (_) {
      // Игнорируем — видимость не критична, фолбэк на OpenWeatherMap ниже
    }
    return null;
  }

  Future<http.Response> _get(String url) async {
    try {
      return await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 15),
          );
    } catch (e) {
      throw WeatherServiceException(WeatherErrorType.noInternet);
    }
  }

  WeatherServiceException _exceptionFor(int statusCode,
      {WeatherErrorType? notFound}) {
    switch (statusCode) {
      case 401:
        return WeatherServiceException(WeatherErrorType.auth,
            statusCode: statusCode);
      case 404:
        return WeatherServiceException(notFound ?? WeatherErrorType.notFound,
            statusCode: statusCode);
      case 429:
        return WeatherServiceException(WeatherErrorType.rateLimit,
            statusCode: statusCode);
      default:
        return WeatherServiceException(WeatherErrorType.generic,
            statusCode: statusCode);
    }
  }
}

class _CacheEntry {
  final WeatherData data;
  final DateTime timestamp;

  _CacheEntry(this.data, this.timestamp);
}
