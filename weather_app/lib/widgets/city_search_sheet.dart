import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/settings_service.dart';

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
  List<String> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
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
  }

  Future<void> _removeFavorite(String city) async {
    await _settings.removeFavoriteCity(city);
    _loadFavorites();
  }

  void _selectCity(String city) {
    widget.onCitySelected(city);
    Navigator.pop(context);
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
