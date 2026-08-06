import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../utils/weather_map_utils.dart';

/// Секция с переключаемыми картами погоды вокруг текущего города: осадки,
/// ветер, грозы и температура — поверх настоящей базовой карты местности
/// (OpenStreetMap), чтобы данные было хорошо видно и понятно, где именно
/// на карте они относятся.
///
/// Источники данных (все бесплатные, без API-ключа):
/// - Подложка — тайлы OpenStreetMap.
/// - Осадки/грозы — радар RainViewer (https://www.rainviewer.com) поверх
///   подложки; грозы показаны как зоны осадков высокой интенсивности,
///   т.к. отдельного слоя молний в бесплатных API нет.
/// - Ветер/температура — сетка "живых" значений из Open-Meteo
///   (https://open-meteo.com), нарисованная собственными виджетами
///   (кружки со значениями/стрелками) поверх подложки OSM.
class WeatherMapsSection extends StatefulWidget {
  final double lat;
  final double lon;

  const WeatherMapsSection({super.key, required this.lat, required this.lon});

  @override
  State<WeatherMapsSection> createState() => _WeatherMapsSectionState();
}

class _WeatherMapsSectionState extends State<WeatherMapsSection> {
  WeatherMapLayer _selectedLayer = WeatherMapLayer.precipitation;

  // Зум 7 — максимум, который поддерживают тайлы радара RainViewer
  // (https://www.rainviewer.com/api/weather-maps-api.html), и хороший
  // баланс детализации/охвата для подложки OSM вокруг города.
  static const int _zoom = 7;

  String _labelFor(WeatherMapLayer layer, AppLocalizations l10n) {
    switch (layer) {
      case WeatherMapLayer.precipitation:
        return l10n.mapPrecipitation;
      case WeatherMapLayer.wind:
        return l10n.mapWind;
      case WeatherMapLayer.storms:
        return l10n.mapStorms;
      case WeatherMapLayer.temperature:
        return l10n.mapTemperature;
    }
  }

  IconData _iconFor(WeatherMapLayer layer) {
    switch (layer) {
      case WeatherMapLayer.precipitation:
        return Icons.water_drop_rounded;
      case WeatherMapLayer.wind:
        return Icons.air_rounded;
      case WeatherMapLayer.storms:
        return Icons.bolt_rounded;
      case WeatherMapLayer.temperature:
        return Icons.thermostat_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.weatherMaps,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final layer in WeatherMapLayer.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _LayerChip(
                      label: _labelFor(layer, l10n),
                      icon: _iconFor(layer),
                      selected: layer == _selectedLayer,
                      onTap: () => setState(() => _selectedLayer = layer),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1,
              child: _MapView(
                key: ValueKey(_selectedLayer),
                layer: _selectedLayer,
                lat: widget.lat,
                lon: widget.lon,
                zoom: _zoom,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _Attribution(layer: _selectedLayer),
          if (_selectedLayer == WeatherMapLayer.storms) ...[
            const SizedBox(height: 6),
            Text(
              l10n.mapStormsNote,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

/// Атрибуция источника данных — обязательна по условиям бесплатного
/// использования OpenStreetMap и RainViewer.
class _Attribution extends StatelessWidget {
  final WeatherMapLayer layer;

  const _Attribution({required this.layer});

  @override
  Widget build(BuildContext context) {
    final text = layer.isRadarLayer
        ? '© OpenStreetMap contributors · Radar: RainViewer'
        : '© OpenStreetMap contributors · Data: Open-Meteo';

    return Text(
      text,
      style: const TextStyle(color: Colors.white30, fontSize: 10),
    );
  }
}

class _LayerChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LayerChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withOpacity(0.9)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: selected ? const Color(0xFF1E2A47) : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF1E2A47) : Colors.white70,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Переключает между радарным видом (осадки/грозы) и видом сетки значений
/// (ветер/температура) для выбранного слоя.
class _MapView extends StatelessWidget {
  final WeatherMapLayer layer;
  final double lat;
  final double lon;
  final int zoom;

  const _MapView({
    super.key,
    required this.layer,
    required this.lat,
    required this.lon,
    required this.zoom,
  });

  @override
  Widget build(BuildContext context) {
    if (layer.isRadarLayer) {
      return _RadarMap(layer: layer, lat: lat, lon: lon, zoom: zoom);
    }
    return _GridValueMap(layer: layer, lat: lat, lon: lon, zoom: zoom);
  }
}

/// Базовая карта местности (OpenStreetMap) — сетка 3x3 тайлов вокруг
/// центральной точки. Используется как общая подложка и для радарного
/// вида, и для вида сетки значений, чтобы оба выглядели согласованно.
class _BaseMapGrid extends StatelessWidget {
  final double lat;
  final double lon;
  final int zoom;

  const _BaseMapGrid({
    required this.lat,
    required this.lon,
    required this.zoom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8E6E0),
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 0,
        crossAxisSpacing: 0,
        children: [
          for (int dy = -1; dy <= 1; dy++)
            for (int dx = -1; dx <= 1; dx++)
              _RasterTile(
                key: ValueKey('base_${dx}_$dy'),
                url: BaseMapTiles.tileUrl(
                  lat: lat,
                  lon: lon,
                  zoom: zoom,
                  dx: dx,
                  dy: dy,
                ),
                placeholderColor: const Color(0xFFE8E6E0),
              ),
        ],
      ),
    );
  }
}

/// Радарный вид (осадки/грозы): подложка OSM + полупрозрачный слой радара
/// RainViewer поверх. Кадр радара запрашивается один раз и переиспользуется
/// для всех 9 тайлов сетки.
class _RadarMap extends StatefulWidget {
  final WeatherMapLayer layer;
  final double lat;
  final double lon;
  final int zoom;

  const _RadarMap({
    required this.layer,
    required this.lat,
    required this.lon,
    required this.zoom,
  });

  @override
  State<_RadarMap> createState() => _RadarMapState();
}

class _RadarMapState extends State<_RadarMap> {
  late Future<RainViewerFrame?> _frameFuture;

  @override
  void initState() {
    super.initState();
    _frameFuture = RainViewerApi.latestFrame();
  }

  void _retry() {
    setState(() => _frameFuture = RainViewerApi.latestFrame());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _BaseMapGrid(lat: widget.lat, lon: widget.lon, zoom: widget.zoom),
        FutureBuilder<RainViewerFrame?>(
          future: _frameFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _LoadingOverlay();
            }
            final frame = snapshot.data;
            if (frame == null) {
              // Радар недоступен (нет сети / сервис не ответил) — не
              // показываем пустой слой поверх подложки, а даём понятный
              // текст вместо тихо "исчезнувших" данных, с возможностью
              // повторить запрос.
              return _ErrorNotice(
                text: AppLocalizations.of(context).mapDataUnavailable,
                onRetry: _retry,
              );
            }
            final radarGrid = GridView.count(
              crossAxisCount: 3,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 0,
              crossAxisSpacing: 0,
              children: [
                for (int dy = -1; dy <= 1; dy++)
                  for (int dx = -1; dx <= 1; dx++)
                    _RasterTile(
                      key: ValueKey(
                          'radar_${widget.layer}_${dx}_${dy}_${frame.tilePath}'),
                      url: RainViewerApi.tileUrl(
                        frame: frame,
                        lat: widget.lat,
                        lon: widget.lon,
                        zoom: widget.zoom,
                        dx: dx,
                        dy: dy,
                      ),
                      transparentOnError: true,
                    ),
              ],
            );

            if (widget.layer != WeatherMapLayer.storms) return radarGrid;

            // Отдельного слоя гроз/молний в бесплатном RainViewer API нет —
            // используются те же данные радара, что и для осадков, но с
            // усиленным контрастом/насыщенностью, чтобы визуально выделить
            // именно самые плотные (потенциально грозовые) зоны осадков.
            return ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                1.35, 0, 0, 0, 0,
                0, 1.1, 0, 0, 0,
                0, 0, 0.9, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: radarGrid,
            );
          },
        ),
        const _CenterMarker(),
      ],
    );
  }
}

/// Вид сетки значений (ветер/температура): подложка OSM + собственные
/// маркеры со значениями из Open-Meteo, размещённые по их реальным
/// координатам на карте.
class _GridValueMap extends StatefulWidget {
  final WeatherMapLayer layer;
  final double lat;
  final double lon;
  final int zoom;

  const _GridValueMap({
    required this.layer,
    required this.lat,
    required this.lon,
    required this.zoom,
  });

  @override
  State<_GridValueMap> createState() => _GridValueMapState();
}

class _GridValueMapState extends State<_GridValueMap> {
  late Future<List<WeatherGridPoint>> _gridFuture;

  // Тайлы 3x3 на зуме 7 покрывают очень большую площадь (сотни км), а живые
  // данные точками имеет смысл показывать в куда более компактном радиусе
  // вокруг города — иначе соседние точки сетки окажутся в других странах.
  // Поэтому сетка значений использует собственный, более узкий охват в
  // градусах, независимый от тайлового зума карты. При желании густоту
  // сетки легко увеличить, подняв _gridSize (например, до 5 — сетка 5x5).
  static const double _stepDegrees = 0.12;
  static const int _gridSize = 3;

  @override
  void initState() {
    super.initState();
    _gridFuture = OpenMeteoApi.fetchGrid(
      centerLat: widget.lat,
      centerLon: widget.lon,
      gridSize: _gridSize,
      stepDegrees: _stepDegrees,
    );
  }

  void _retry() {
    setState(() {
      _gridFuture = OpenMeteoApi.fetchGrid(
        centerLat: widget.lat,
        centerLon: widget.lon,
        gridSize: _gridSize,
        stepDegrees: _stepDegrees,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _BaseMapGrid(lat: widget.lat, lon: widget.lon, zoom: widget.zoom),
        // Лёгкое затемнение подложки — маркеры со значениями читаются
        // значительно лучше на приглушённой карте, чем на пёстрой OSM.
        Container(color: Colors.black.withOpacity(0.32)),
        FutureBuilder<List<WeatherGridPoint>>(
          future: _gridFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _LoadingOverlay();
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _ErrorNotice(
                text: AppLocalizations.of(context).mapDataUnavailable,
                onRetry: _retry,
              );
            }
            final points = snapshot.data!;
            return LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    for (final point in points)
                      _GridPointMarker(
                        point: point,
                        layer: widget.layer,
                        centerLat: widget.lat,
                        centerLon: widget.lon,
                        stepDegrees: _stepDegrees,
                        gridSize: _gridSize,
                        canvasSize: constraints.biggest,
                      ),
                  ],
                );
              },
            );
          },
        ),
        const _CenterMarker(),
      ],
    );
  }
}

/// Один маркер сетки ветра/температуры, спозиционированный по своим
/// реальным координатам относительно центра карты (простая линейная
/// проекция в пределах небольшого охвата — на масштабе в десятки км
/// кривизна Web Mercator не даёт заметной ошибки).
class _GridPointMarker extends StatelessWidget {
  final WeatherGridPoint point;
  final WeatherMapLayer layer;
  final double centerLat;
  final double centerLon;
  final double stepDegrees;
  final int gridSize;
  final Size canvasSize;

  const _GridPointMarker({
    required this.point,
    required this.layer,
    required this.centerLat,
    required this.centerLon,
    required this.stepDegrees,
    required this.gridSize,
    required this.canvasSize,
  });

  @override
  Widget build(BuildContext context) {
    final halfSpanDegrees = (gridSize - 1) / 2 * stepDegrees +
        stepDegrees / 2; // добавляем половину шага как поля по краям
    final dxDeg = point.lon - centerLon;
    final dyDeg = point.lat - centerLat;

    final normalizedX = (dxDeg / halfSpanDegrees) / 2 + 0.5;
    final normalizedY = 0.5 - (dyDeg / halfSpanDegrees) / 2;

    final left = normalizedX * canvasSize.width;
    final top = normalizedY * canvasSize.height;

    const markerSize = 56.0;

    return Positioned(
      left: left - markerSize / 2,
      top: top - markerSize / 2,
      width: markerSize,
      height: markerSize,
      child: layer == WeatherMapLayer.temperature
          ? _TemperatureMarker(point: point)
          : _WindMarker(point: point),
    );
  }
}

class _TemperatureMarker extends StatelessWidget {
  final WeatherGridPoint point;

  const _TemperatureMarker({required this.point});

  // Цвет от синего (холодно) к красному (жарко) — стандартная и
  // интуитивно понятная шкала температурных карт.
  Color _colorFor(double? tempC) {
    if (tempC == null) return Colors.white24;
    if (tempC <= 0) return const Color(0xFF3B82F6);
    if (tempC <= 10) return const Color(0xFF22C1C3);
    if (tempC <= 20) return const Color(0xFFFACC15);
    if (tempC <= 30) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final temp = point.temperatureC;
    final color = _colorFor(temp);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.92),
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Center(
        child: Text(
          temp != null ? '${temp.round()}°' : '—',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _WindMarker extends StatelessWidget {
  final WeatherGridPoint point;

  const _WindMarker({required this.point});

  // Цвет по силе ветра — от спокойного зелёного до тревожного красного.
  Color _colorFor(double? speedKmh) {
    if (speedKmh == null) return Colors.white24;
    if (speedKmh <= 10) return const Color(0xFF34D399);
    if (speedKmh <= 25) return const Color(0xFFFACC15);
    if (speedKmh <= 45) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final speed = point.windSpeedKmh;
    final direction = point.windDirectionDeg ?? 0;
    final color = _colorFor(speed);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.92),
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Стрелка направления ветра: метеорологический стандарт — угол
          // указывает, ОТКУДА дует ветер, поэтому саму стрелку разворачиваем
          // на 180° от wind_direction, чтобы она указывала КУДА дует.
          Transform.rotate(
            angle: (direction + 180) * math.pi / 180,
            child: const Icon(
              Icons.north_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          Text(
            speed != null ? '${speed.round()}' : '—',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterMarker extends StatelessWidget {
  const _CenterMarker();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.location_on_rounded,
        color: Color(0xFFEF4444),
        size: 28,
        shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _ErrorNotice({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF16213F).withOpacity(0.85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context).mapRetry,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Один растровый тайл (используется и для подложки OSM, и для радара
/// RainViewer). FilterQuality.high включает более качественную
/// интерполяцию при масштабировании, чем стандартная для Image.network,
/// поэтому карта выглядит заметно чётче при апскейле тайлов на весь экран.
class _RasterTile extends StatelessWidget {
  final String url;
  final bool transparentOnError;
  final Color placeholderColor;

  const _RasterTile({
    super.key,
    required this.url,
    this.transparentOnError = false,
    this.placeholderColor = const Color(0xFF16213F),
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(color: placeholderColor);
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: transparentOnError ? Colors.transparent : placeholderColor,
        );
      },
    );
  }
}
