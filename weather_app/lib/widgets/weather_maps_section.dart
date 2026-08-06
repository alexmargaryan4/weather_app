import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../utils/weather_map_utils.dart';

/// Секция с переключаемыми картами погоды вокруг текущего города:
/// осадки, ветер, грозы (через плотность облачности) и температура.
/// Карта собирается как сетка 3x3 PNG-тайлов OpenWeatherMap — без
/// сторонних пакетов карт и без интерактивности (не требуется для
/// простого просмотра ситуации вокруг города).
class WeatherMapsSection extends StatefulWidget {
  final double lat;
  final double lon;

  const WeatherMapsSection({super.key, required this.lat, required this.lon});

  @override
  State<WeatherMapsSection> createState() => _WeatherMapsSectionState();
}

class _WeatherMapsSectionState extends State<WeatherMapsSection> {
  WeatherMapLayer _selectedLayer = WeatherMapLayer.precipitation;

  // Зум 10 даёт разумный баланс между детализацией и охватом области вокруг
  // города на квадрате 3x3 тайла. Поднят с 8 до 10: при зуме 8 каждый тайл
  // 256x256 растягивался на весь экран (особенно на HiDPI-экранах), из-за
  // чего карта выглядела мутной/заблюренной. На зуме 10 тайлы плотнее
  // покрывают ту же физическую область экрана, и апскейл почти не заметен.
  static const int _zoom = 10;

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
              child: _MapTileGrid(
                key: ValueKey(_selectedLayer),
                layer: _selectedLayer,
                lat: widget.lat,
                lon: widget.lon,
                zoom: _zoom,
              ),
            ),
          ),
          if (_selectedLayer == WeatherMapLayer.storms) ...[
            const SizedBox(height: 10),
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
                size: 15, color: selected ? const Color(0xFF1E2A47) : Colors.white70),
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

/// Сетка 3x3 тайлов вокруг центральной точки (город) для выбранного слоя.
/// Рисуется поверх плейсхолдера тёмного фона (не настоящей карты местности —
/// без ключа картографического провайдера у нас нет подложки с улицами,
/// только сама метеорологическая накладка), что всё равно передаёт форму
/// осадков/облачности вокруг города.
class _MapTileGrid extends StatelessWidget {
  final WeatherMapLayer layer;
  final double lat;
  final double lon;
  final int zoom;

  const _MapTileGrid({
    super.key,
    required this.layer,
    required this.lat,
    required this.lon,
    required this.zoom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF16213F),
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
        children: [
          for (int dy = -1; dy <= 1; dy++)
            for (int dx = -1; dx <= 1; dx++)
              _MapTile(
                url: WeatherMapUtils.tileUrl(
                  layer: layer,
                  lat: lat,
                  lon: lon,
                  zoom: zoom,
                  dx: dx,
                  dy: dy,
                ),
                isCenter: dx == 0 && dy == 0,
              ),
        ],
      ),
    );
  }
}

class _MapTile extends StatelessWidget {
  final String url;
  final bool isCenter;

  const _MapTile({required this.url, required this.isCenter});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          // По умолчанию Flutter рисует Image.network с FilterQuality.low,
          // что при увеличении растрового тайла на весь экран даёт заметное
          // размытие. FilterQuality.high использует бикубическую
          // интерполяцию — картинка выглядит значительно чётче.
          filterQuality: FilterQuality.high,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: const Color(0xFF16213F),
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(color: const Color(0xFF16213F));
          },
        ),
        if (isCenter)
          const Center(
            child: Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 22,
              shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
            ),
          ),
      ],
    );
  }
}
