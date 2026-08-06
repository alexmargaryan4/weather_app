import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// Виды погодных карт (слоёв), которые умеет показывать приложение.
///
/// Все источники данных бесплатные и не требуют API-ключа:
/// - Базовая подложка — тайлы OpenStreetMap (стандартный слой "Standard").
/// - Осадки/грозы — радар RainViewer поверх подложки OSM (грозы показаны
///   как зоны осадков высокой интенсивности — отдельного слоя молний в
///   бесплатных API нет).
/// - Ветер/температура — собственная сетка точек 3x3 с "живыми" данными
///   из Open-Meteo, нарисованная поверх подложки OSM своими виджетами
///   (кружки со значениями/стрелками), а не сторонними тайлами.
enum WeatherMapLayer {
  precipitation,
  wind,
  temperature,
  storms,
}

extension WeatherMapLayerKind on WeatherMapLayer {
  /// true — слой рисуется как радарный растровый оверлей (RainViewer),
  /// false — слой рисуется как сетка собственных маркеров (Open-Meteo).
  bool get isRadarLayer =>
      this == WeatherMapLayer.precipitation || this == WeatherMapLayer.storms;
}

/// Перевод географических координат в номер тайла (x, y) на заданном
/// уровне зума — стандартная формула Web Mercator / Slippy Map, общая
/// для OSM и RainViewer (оба используют одну и ту же тайловую схему).
({int x, int y}) latLonToTile(double lat, double lon, int zoom) {
  final latRad = lat * math.pi / 180;
  final n = math.pow(2, zoom).toDouble();
  final x = ((lon + 180) / 360 * n).floor();
  final y = ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
          2 *
          n)
      .floor();
  return (x: x, y: y);
}

/// Базовая карта местности — OpenStreetMap Standard tiles.
/// Бесплатно, без ключа. См. https://operations.osmfoundation.org/policies/tiles/
class BaseMapTiles {
  static const List<String> _subdomains = ['a', 'b', 'c'];

  /// URL одного тайла подложки со смещением (dx, dy) от тайла,
  /// содержащего точку (lat, lon), на заданном зуме.
  static String tileUrl({
    required double lat,
    required double lon,
    required int zoom,
    int dx = 0,
    int dy = 0,
  }) {
    final tile = latLonToTile(lat, lon, zoom);
    final x = tile.x + dx;
    final y = tile.y + dy;
    // Тайлы вне диапазона [0, 2^zoom) не существуют (полюса/переход через
    // антимеридиан) — заворачиваем x по модулю и отдаём крайний валидный y.
    final n = 1 << zoom;
    final wrappedX = ((x % n) + n) % n;
    final clampedY = y.clamp(0, n - 1);
    // Простое чередование поддоменов балансирует нагрузку и почти всегда
    // ускоряет параллельную загрузку 9 тайлов сетки в браузерах/движках,
    // которые ограничивают число одновременных соединений на хост.
    final subdomain = _subdomains[(wrappedX + clampedY) % _subdomains.length];
    return 'https://$subdomain.tile.openstreetmap.org/$zoom/$wrappedX/$clampedY.png';
  }
}

/// Кадр радара RainViewer — хост тайлового кеша и путь шаблона тайлов,
/// которые отдаёт публичный API погоды. RainViewer явно требует брать оба
/// значения из ответа API, а не хардкодить их: путь содержит меняющийся
/// хеш кадра, а хост в будущем теоретически может измениться.
class RainViewerFrame {
  final String host;
  final String tilePath;

  const RainViewerFrame({required this.host, required this.tilePath});
}

/// Клиент публичного (бесключевого) API RainViewer.
/// Документация: https://www.rainviewer.com/api/weather-maps-api.html
class RainViewerApi {
  static const String _apiUrl =
      'https://api.rainviewer.com/public/weather-maps.json';

  // Простое кеширование последнего ответа на короткое время, чтобы
  // переключение между вкладками "Осадки"/"Грозы" не делало повторный
  // сетевой запрос за тем же самым кадром радара.
  static RainViewerFrame? _cachedFrame;
  static DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Последний доступный кадр радара (обычно обновляется RainViewer
  /// каждые 10 минут). Возвращает null, если сервис недоступен.
  static Future<RainViewerFrame?> latestFrame() async {
    final cached = _cachedFrame;
    final cachedAt = _cachedAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheTtl) {
      return cached;
    }

    try {
      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final host = data['host'] as String?;
      final radar = data['radar'] as Map<String, dynamic>?;
      final past = radar?['past'] as List<dynamic>?;
      if (host == null || past == null || past.isEmpty) return null;

      // Последний элемент "past" — самый свежий доступный кадр радара.
      final latest = past.last as Map<String, dynamic>;
      final path = latest['path'] as String?;
      if (path == null) return null;

      final frame = RainViewerFrame(host: host, tilePath: path);
      _cachedFrame = frame;
      _cachedAt = DateTime.now();
      return frame;
    } catch (_) {
      return null;
    }
  }

  /// URL одного тайла радара для заданного кадра и смещения (dx, dy)
  /// от центрального тайла.
  ///
  /// Формат: {host}{tilePath}/{size}/{z}/{x}/{y}/{color}/{options}.png
  /// - size 256 — стандартный размер тайла;
  /// - color 2 — стандартная палитра RainViewer ("Original/Universal
  ///   Blue"), хорошо читаемая поверх подложки OSM;
  /// - options "1_1" — включены сглаживание тайлов и отображение снега
  ///   (см. документацию RainViewer: rainviewer.com/api/weather-maps-api.html).
  ///
  /// Отдельного слоя гроз/молний в бесплатном API нет, поэтому "грозовая"
  /// карта использует те же данные радара, что и карта осадков — разница
  /// только в том, что widget поверх карты (см. mapStormsNote) явно
  /// поясняет пользователю, что более яркие/плотные зоны на радаре — это
  /// и есть зоны потенциальной грозовой активности.
  static String tileUrl({
    required RainViewerFrame frame,
    required double lat,
    required double lon,
    required int zoom,
    int dx = 0,
    int dy = 0,
  }) {
    final tile = latLonToTile(lat, lon, zoom);
    final x = tile.x + dx;
    final y = tile.y + dy;
    final n = 1 << zoom;
    final wrappedX = ((x % n) + n) % n;
    final clampedY = y.clamp(0, n - 1);

    return '${frame.host}${frame.tilePath}/256/$zoom/$wrappedX/$clampedY/2/1_1.png';
  }
}

/// Одна точка сетки живых данных Open-Meteo: координаты + значения
/// температуры и ветра в этой точке.
class WeatherGridPoint {
  final double lat;
  final double lon;
  final double? temperatureC;
  final double? windSpeedKmh;
  final double? windDirectionDeg;

  const WeatherGridPoint({
    required this.lat,
    required this.lon,
    this.temperatureC,
    this.windSpeedKmh,
    this.windDirectionDeg,
  });
}

/// Клиент бесключевого API Open-Meteo для получения сетки точек
/// температуры и ветра вокруг заданного центра.
/// Документация: https://open-meteo.com/en/docs
class OpenMeteoApi {
  static const String _forecastUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Загружает сетку gridSize x gridSize точек с шагом stepDegrees градусов
  /// вокруг (centerLat, centerLon). Все точки запрашиваются одним batched
  /// HTTP-запросом (Open-Meteo поддерживает списки координат через запятую),
  /// поэтому даже сетка 3x3 (9 точек) — это один сетевой вызов, а не девять.
  static Future<List<WeatherGridPoint>> fetchGrid({
    required double centerLat,
    required double centerLon,
    required int gridSize,
    required double stepDegrees,
  }) async {
    final half = (gridSize - 1) / 2;
    final points = <({double lat, double lon})>[];
    for (int gy = 0; gy < gridSize; gy++) {
      for (int gx = 0; gx < gridSize; gx++) {
        final lat = centerLat + (half - gy) * stepDegrees;
        final lon = centerLon + (gx - half) * stepDegrees;
        points.add((lat: lat, lon: lon));
      }
    }

    final latParam = points.map((p) => p.lat.toStringAsFixed(4)).join(',');
    final lonParam = points.map((p) => p.lon.toStringAsFixed(4)).join(',');

    final uri = Uri.parse(
      '$_forecastUrl?latitude=$latParam&longitude=$lonParam'
      '&current=temperature_2m,wind_speed_10m,wind_direction_10m'
      '&wind_speed_unit=kmh&timezone=auto',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Open-Meteo grid request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    // При запросе нескольких координат Open-Meteo возвращает JSON-массив
    // объектов (по одному на точку), в том же порядке, в котором были
    // переданы координаты. При одной точке API вернул бы один объект —
    // на случай сетки 1x1 обрабатываем оба варианта на всякий случай.
    final List<dynamic> items = decoded is List ? decoded : [decoded];

    final result = <WeatherGridPoint>[];
    for (int i = 0; i < items.length && i < points.length; i++) {
      final item = items[i] as Map<String, dynamic>;
      final current = item['current'] as Map<String, dynamic>?;
      final point = points[i];
      result.add(
        WeatherGridPoint(
          lat: point.lat,
          lon: point.lon,
          temperatureC: (current?['temperature_2m'] as num?)?.toDouble(),
          windSpeedKmh: (current?['wind_speed_10m'] as num?)?.toDouble(),
          windDirectionDeg:
              (current?['wind_direction_10m'] as num?)?.toDouble(),
        ),
      );
    }
    return result;
  }
}
