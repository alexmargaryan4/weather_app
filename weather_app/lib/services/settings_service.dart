import 'package:shared_preferences/shared_preferences.dart';

/// Хранит настройки пользователя между запусками: единицы измерения
/// и список избранных городов.
class SettingsService {
  static const _keyUseFahrenheit = 'use_fahrenheit';
  static const _keyFavoriteCities = 'favorite_cities';
  static const _keyLastCity = 'last_city';

  Future<bool> getUseFahrenheit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUseFahrenheit) ?? false;
  }

  Future<void> setUseFahrenheit(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseFahrenheit, value);
  }

  Future<List<String>> getFavoriteCities() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyFavoriteCities) ?? [];
  }

  Future<void> addFavoriteCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    final cities = prefs.getStringList(_keyFavoriteCities) ?? [];
    if (!cities.any((c) => c.toLowerCase() == city.toLowerCase())) {
      cities.add(city);
      await prefs.setStringList(_keyFavoriteCities, cities);
    }
  }

  Future<void> removeFavoriteCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    final cities = prefs.getStringList(_keyFavoriteCities) ?? [];
    cities.removeWhere((c) => c.toLowerCase() == city.toLowerCase());
    await prefs.setStringList(_keyFavoriteCities, cities);
  }

  Future<String?> getLastCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastCity);
  }

  Future<void> setLastCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastCity, city);
  }
}
