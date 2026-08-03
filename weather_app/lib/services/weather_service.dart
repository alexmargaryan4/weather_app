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

  // Получить погоду по координатам (используется для геолокации)
  Future<WeatherData> getWeatherByCoordinates(
      double lat, double lon) async {
    final currentResponse = await http.get(Uri.parse(
        '$currentWeatherUrl?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=ru'));

    final forecastResponse = await http.get(Uri.parse(
        '$forecastUrl?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=ru'));

    if (currentResponse.statusCode == 200 &&
        forecastResponse.statusCode == 200) {
      final currentJson = jsonDecode(currentResponse.body);
      final forecastJson = jsonDecode(forecastResponse.body);
      return WeatherData.fromJson(currentJson, forecastJson);
    } else {
      throw Exception(
          'Не удалось загрузить погоду. Код: ${currentResponse.statusCode}');
    }
  }

  // Получить погоду по названию города (используется при ручном поиске)
  Future<WeatherData> getWeatherByCityName(String cityName) async {
    final currentResponse = await http.get(Uri.parse(
        '$currentWeatherUrl?q=$cityName&appid=$apiKey&units=metric&lang=ru'));

    if (currentResponse.statusCode != 200) {
      throw Exception('Город не найден');
    }

    final currentJson = jsonDecode(currentResponse.body);
    final lat = currentJson['coord']['lat'];
    final lon = currentJson['coord']['lon'];

    final forecastResponse = await http.get(Uri.parse(
        '$forecastUrl?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=ru'));

    if (forecastResponse.statusCode == 200) {
      final forecastJson = jsonDecode(forecastResponse.body);
      return WeatherData.fromJson(currentJson, forecastJson);
    } else {
      throw Exception('Не удалось загрузить прогноз для этого города');
    }
  }
}