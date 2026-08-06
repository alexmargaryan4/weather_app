import 'dart:math' as math;
import '../services/weather_service.dart';

/// Виды погодных карт (слоёв), которые умеет показывать приложение.
/// Основаны на бесплатных тайловых слоях OpenWeatherMap Weather Maps 1.0
/// (https://tile.openweathermap.org/map/{layer}/{z}/{x}/{y}.png).
enum WeatherMapLayer {
  precipitation,
  wind,
  temperature,
  // Отдельного "радара гроз" в бесплатном тарифе OpenWeatherMap нет —
  // ближайшая по смыслу карта грозовой активности строится по плотной
  // кучево-дождевой облачности, поэтому здесь используется тот же
  // тайловый слой облаков (clouds_new), что и для гроз.
  storms,
}

extension WeatherMapLayerTiles on WeatherMapLayer {
  // Имя слоя, которое OpenWeatherMap ожидает в URL тайла.
  String get tileLayerName {
    switch (this) {
      case WeatherMapLayer.precipitation:
        return 'precipitation_new';
      case WeatherMapLayer.wind:
        return 'wind_new';
      case WeatherMapLayer.temperature:
        return 'temp_new';
      case WeatherMapLayer.storms:
        return 'clouds_new';
    }
  }
}

/// Построение URL-ов тайлов погодных карт вокруг заданной точки (lat/lon).
///
/// Карта рисуется как сетка PNG-тайлов Web Mercator (тот же формат, что
/// использует большинство картографических сервисов), поэтому здесь не
/// нужен отдельный пакет карт — сетка Image.network достаточно, чтобы
/// показать облачность/осадки/ветер/температуру вокруг города.
class WeatherMapUtils {
  static const String _baseUrl = 'https://tile.openweathermap.org/map';

  // Переводит географические координаты в номер тайла (x, y) на заданном
  // уровне зума — стандартная формула Web Mercator / Slippy Map.
  static ({int x, int y}) latLonToTile(double lat, double lon, int zoom) {
    final latRad = lat * math.pi / 180;
    final n = math.pow(2, zoom).toDouble();
    final x = ((lon + 180) / 360 * n).floor();
    final y = ((1 -
                math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
            2 *
            n)
        .floor();
    return (x: x, y: y);
  }

  // URL одного тайла с заданным смещением (dx, dy) от центрального —
  // используется, чтобы собрать сетку 3x3 тайлов вокруг города для более
  // широкого обзора карты, а не только один квадрат прямо над городом.
  static String tileUrl({
    required WeatherMapLayer layer,
    required double lat,
    required double lon,
    required int zoom,
    int dx = 0,
    int dy = 0,
  }) {
    final tile = latLonToTile(lat, lon, zoom);
    final x = tile.x + dx;
    final y = tile.y + dy;
    return '$_baseUrl/${layer.tileLayerName}/$zoom/$x/$y.png?appid=${WeatherService.apiKey}';
  }
}
