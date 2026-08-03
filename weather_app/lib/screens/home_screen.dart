import 'package:flutter/material.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../utils/temperature_utils.dart';
import '../widgets/animated_background.dart';
import '../widgets/hourly_forecast.dart';
import '../widgets/daily_forecast.dart';
import '../widgets/city_search_sheet.dart';
import '../widgets/sun_arc.dart';
import '../widgets/air_quality_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WeatherService _weatherService = WeatherService();
  final LocationService _locationService = LocationService();
  final SettingsService _settingsService = SettingsService();

  WeatherData? _weatherData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _useFahrenheit = false;
  List<String> _favoriteCities = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final useFahrenheit = await _settingsService.getUseFahrenheit();
    final favorites = await _settingsService.getFavoriteCities();
    setState(() {
      _useFahrenheit = useFahrenheit;
      _favoriteCities = favorites;
    });
    await _loadWeatherByLocation();
  }

  Future<void> _toggleUnits() async {
    final next = !_useFahrenheit;
    setState(() => _useFahrenheit = next);
    await _settingsService.setUseFahrenheit(next);
  }

  Future<void> _loadWeatherByLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final position = await _locationService.getCurrentLocation();
      final weather = await _weatherService.getWeatherByCoordinates(
        position.latitude,
        position.longitude,
      );
      setState(() {
        _weatherData = weather;
        _isLoading = false;
      });
      _settingsService.setLastCity(weather.cityName);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWeatherByCity(String cityName) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final weather = await _weatherService.getWeatherByCityName(cityName);
      setState(() {
        _weatherData = weather;
        _isLoading = false;
      });
      _settingsService.setLastCity(weather.cityName);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // Переключиться на соседний избранный город свайпом (после текущего города,
  // если он тоже в избранном, иначе просто по кругу избранных).
  Future<void> _switchFavorite(int direction) async {
    if (_favoriteCities.isEmpty) return;
    final currentName = _weatherData?.cityName;
    int currentIndex = _favoriteCities
        .indexWhere((c) => c.toLowerCase() == currentName?.toLowerCase());
    int nextIndex;
    if (currentIndex == -1) {
      nextIndex = direction > 0 ? 0 : _favoriteCities.length - 1;
    } else {
      nextIndex =
          (currentIndex + direction) % _favoriteCities.length;
      if (nextIndex < 0) nextIndex += _favoriteCities.length;
    }
    await _loadWeatherByCity(_favoriteCities[nextIndex]);
  }

  void _openCitySearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CitySearchSheet(
        currentCity: _weatherData?.cityName,
        onCitySelected: _loadWeatherByCity,
        onUseCurrentLocation: _loadWeatherByLocation,
      ),
    ).whenComplete(() async {
      // Обновляем список избранных на случай, если что-то поменялось в шторке
      final favorites = await _settingsService.getFavoriteCities();
      setState(() => _favoriteCities = favorites);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),
      body: SizedBox.expand(
        child: AnimatedWeatherBackground(
          iconCode: _weatherData?.iconCode ?? '01d',
          child: SafeArea(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() < 200) return;
                if (velocity < 0) {
                  _switchFavorite(1); // свайп влево -> следующий город
                } else {
                  _switchFavorite(-1); // свайп вправо -> предыдущий город
                }
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _buildBody(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return Center(
        key: const ValueKey('error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 56),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadWeatherByLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text('Попробовать снова'),
              ),
              TextButton(
                onPressed: _openCitySearch,
                child: const Text(
                  'Или выбрать город вручную',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final weather = _weatherData!;

    return RefreshIndicator(
      key: const ValueKey('content'),
      onRefresh: _loadWeatherByLocation,
      color: Colors.white,
      backgroundColor: Colors.blueGrey,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            // Верхняя панель с названием города и кнопками действий
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weather.cityName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Material(
                  color: Colors.white.withOpacity(0.14),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: _openCitySearch,
                    icon: const Icon(Icons.add_location_alt_outlined,
                        color: Colors.white70, size: 20),
                  ),
                ),
                Material(
                  color: Colors.white.withOpacity(0.14),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: _toggleUnits,
                    tooltip: 'Единицы измерения',
                    icon: Text(
                      _useFahrenheit ? '°F' : '°C',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Крупная температура с плавным появлением
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Column(
                children: [
                  Text(
                    TemperatureUtils.format(weather.temp, _useFahrenheit),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 88,
                      fontWeight: FontWeight.w200,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    weather.description[0].toUpperCase() +
                        weather.description.substring(1),
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ощущается как ${TemperatureUtils.format(weather.feelsLike, _useFahrenheit)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            HourlyForecastList(
                hourly: weather.hourly, useFahrenheit: _useFahrenheit),
            const SizedBox(height: 16),
            DailyForecastList(
                daily: weather.daily, useFahrenheit: _useFahrenheit),

            const SizedBox(height: 16),

            SunArcCard(sunrise: weather.sunrise, sunset: weather.sunset),

            const SizedBox(height: 16),

            AirQualityCard(aqi: weather.airQualityIndex),

            const SizedBox(height: 16),

            // Доп. параметры: ветер, влажность, давление, видимость
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildInfoCard(
                  icon: Icons.air_rounded,
                  label: 'Ветер',
                  value: '${weather.windSpeed.round()} м/с',
                ),
                _buildInfoCard(
                  icon: Icons.water_drop_outlined,
                  label: 'Влажность',
                  value: '${weather.humidity}%',
                ),
                _buildInfoCard(
                  icon: Icons.speed_rounded,
                  label: 'Давление',
                  value: '${(weather.pressure * 0.750062).round()} мм',
                ),
                _buildInfoCard(
                  icon: Icons.visibility_outlined,
                  label: 'Видимость',
                  value: '${(weather.visibility / 1000).toStringAsFixed(1)} км',
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      {required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
