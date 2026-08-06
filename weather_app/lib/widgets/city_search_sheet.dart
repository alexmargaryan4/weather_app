import 'dart:async';
import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/settings_service.dart';
import '../services/analytics_service.dart';
import '../services/weather_service.dart';

class CitySearchSheet extends StatefulWidget {
  final Function(String) onCitySelected;
  final VoidCallback onUseCurrentLocation;
  final String? currentCity;

  const CitySearchSheet({
    super.key,
    required this.onCitySelected,
    required this.onUseCurrentLocation,
    this.currentCity,
  });

  @override
  State<CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<CitySearchSheet> {
  final TextEditingController _controller = TextEditingController();
  final SettingsService _settings = SettingsService();
  final WeatherService _weatherService = WeatherService();
  List<String> _favorites = [];

  // Подсказки городов, появляющиеся под полем ввода по мере набора текста.
  List<CitySuggestion> _suggestions = [];
  bool _isSearching = false;
  Timer? _debounce;
  // Увеличивается на каждый новый запрос — нужно, чтобы устаревший
  // (медленно ответивший) запрос не перезаписал результат более нового.
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _controller.text.trim();
    _debounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    // Debounce — ждём паузу в наборе текста, чтобы не слать запрос на
    // каждую введённую букву.
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    final requestId = ++_searchRequestId;
    final langCode = AppLocalizations.of(context).weatherApiLangCode;
    final results =
        await _weatherService.searchCities(query, langCode: langCode);

    // Если пользователь успел напечатать что-то ещё, пока ждали ответ —
    // этот результат уже неактуален, игнорируем его.
    if (!mounted || requestId != _searchRequestId) return;

    setState(() {
      _suggestions = results;
      _isSearching = false;
    });
  }

  Future<void> _loadFavorites() async {
    final favorites = await _settings.getFavoriteCities();
    setState(() => _favorites = favorites);
  }

  Future<void> _addCurrentCityToFavorites() async {
    final city = widget.currentCity;
    if (city == null || city.trim().isEmpty) return;
    await _settings.addFavoriteCity(city);
    _loadFavorites();
    AnalyticsService.instance.trackFavoriteAdded(city);
  }

  Future<void> _removeFavorite(String city) async {
    await _settings.removeFavoriteCity(city);
    _loadFavorites();
    AnalyticsService.instance.trackFavoriteRemoved(city);
  }

  void _selectCity(String city) {
    widget.onCitySelected(city);
    Navigator.pop(context);
  }

  void _selectSuggestion(CitySuggestion suggestion) {
    // Передаём "Город,Страна" — так getWeatherByCityName находит точный
    // город, а не первый попавшийся с таким именем в другой стране.
    _selectCity(suggestion.queryString);
  }

  // Блок с подсказками под полем поиска: спиннер во время загрузки,
  // список найденных городов, либо сообщение "ничего не найдено".
  Widget _buildSuggestionsList() {
    final l10n = AppLocalizations.of(context);

    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
            ),
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Text(
          l10n.noCitiesFound,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListTile(
              dense: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              leading: const Icon(Icons.location_on_outlined,
                  color: Colors.white54, size: 20),
              title: Text(
                suggestion.displayLabel,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              onTap: () => _selectSuggestion(suggestion),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final alreadyFavorite = widget.currentCity != null &&
        _favorites
            .any((c) => c.toLowerCase() == widget.currentCity!.toLowerCase());

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2A47),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.changeCity,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.currentCity != null)
                Material(
                  color: Colors.white.withOpacity(0.12),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: alreadyFavorite
                        ? () => _removeFavorite(widget.currentCity!)
                        : _addCurrentCityToFavorites,
                    icon: Icon(
                      alreadyFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: alreadyFavorite
                          ? const Color(0xFFFFD166)
                          : Colors.white70,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: l10n.enterCityName,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                _selectCity(value.trim());
              }
            },
          ),
          // Список подсказок городов/стран, появляющийся по мере набора
          // текста. Показывается только пока есть текст в поле поиска —
          // не мешает избранным городам, когда поле пустое.
          if (_controller.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSuggestionsList(),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              widget.onUseCurrentLocation();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.my_location),
            label: Text(l10n.useMyLocation),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.15),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          if (_favorites.isNotEmpty) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.favoriteCities,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _favorites.length,
                itemBuilder: (context, index) {
                  final city = _favorites[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      leading: const Icon(Icons.location_city_rounded,
                          color: Colors.white70),
                      title: Text(
                        city,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () => _selectCity(city),
                      trailing: IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white38, size: 20),
                        onPressed: () => _removeFavorite(city),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
