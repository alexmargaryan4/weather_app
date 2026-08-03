import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';

class WeatherService {
  // Вставьте сюда свой API-ключ с OpenWeatherMap
  static const String apiKey = 'd76b6cdb234d933ccca184840dce91ee';

  static const String currentWeatherUrl =
      'https://api.openweathermap.org/data/2.5/weather';
  static const String forecastUrl =
      'https://api.openweathermap.org/data/2.5/forecast';
  static const String airPollutionUrl =
      'https://api.openweathermap.org/data/2.5/air_pollution';

  // Получить погоду по координатам (используется для геолокации)
  Future<WeatherData> getWeatherByCoordinates(double lat, double lon) async {
    final currentResponse = await _get(
        '$currentWeatherUrl?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=ru');
    final forecastResponse = await _get(
        '$forecastUrl?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=ru');

    if (currentResponse.statusCode == 200 &&
        forecastResponse.statusCode == 200) {
      final currentJson = jsonDecode(currentResponse.body);
      final forecastJson = jsonDecode(forecastResponse.body);
      var weather = WeatherData.fromJson(currentJson, forecastJson);
      weather = weather.copyWithAirQuality(await _fetchAirQuality(lat, lon));
      return weather;
    } else {
      throw Exception(_errorMessageFor(currentResponse.statusCode));
    }
  }

  // Получить погоду по названию города (используется при ручном поиске)
  Future<WeatherData> getWeatherByCityName(String cityName) async {
    final currentResponse = await _get(
        '$currentWeatherUrl?q=${Uri.encodeComponent(cityName)}&appid=$apiKey&units=metric&lang=ru');

    if (currentResponse.statusCode != 200) {
      throw Exception(_errorMessageFor(currentResponse.statusCode,
          notFoundMessage: 'Город не найден. Проверьте название.'));
    }

    final currentJson = jsonDecode(currentResponse.body);
    final lat = (currentJson['coord']['lat'] as num).toDouble();
    final lon = (currentJson['coord']['lon'] as num).toDouble();

    final forecastResponse = await _get(
        '$forecastUrl?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=ru');

    if (forecastResponse.statusCode == 200) {
      final forecastJson = jsonDecode(forecastResponse.body);
      var weather = WeatherData.fromJson(currentJson, forecastJson);
      weather = weather.copyWithAirQuality(await _fetchAirQuality(lat, lon));
      return weather;
    } else {
      throw Exception('Не удалось загрузить прогноз для этого города');
    }
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

  Future<http.Response> _get(String url) async {
    try {
      return await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 15),
          );
    } catch (e) {
      throw Exception(
          'Нет соединения с интернетом. Проверьте сеть и попробуйте снова.');
    }
  }

  String _errorMessageFor(int statusCode, {String? notFoundMessage}) {
    switch (statusCode) {
      case 401:
        return 'Ошибка авторизации API. Проверьте ключ OpenWeatherMap.';
      case 404:
        return notFoundMessage ?? 'Данные не найдены.';
      case 429:
        return 'Превышен лимит запросов к погодному сервису. Попробуйте позже.';
      default:
        return 'Не удалось загрузить погоду. Код: $statusCode';
    }
  }
}
