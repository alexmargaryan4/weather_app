import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/city_page_bar.dart';

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

  // true, если текущие данные на экране получены по геолокации (значок
  // самолётика в нижней панели), а не по названию сохранённого города.
  // Хранится отдельным флагом, а не выводится из имени города, потому что
  // геолокация иногда может совпасть по названию с избранным городом
  // (например, живёшь в том же городе, что и сохранил вручную) — в этом
  // случае сравнение только по имени выбрало бы не ту страницу.
  bool _isCurrentLocationPage = true;

  // Индекс текущей страницы. null (геолокация) считается страницей 0,
  // если название текущего города не совпадает ни с одним избранным —
  // это также покрывает случай, когда город открыт через поиск и не сохранён.
  int get _currentPageIndex {
    if (_isCurrentLocationPage) return 0;
    final currentName = _weatherData?.cityName;
    final index = _favoriteCities
        .indexWhere((c) => c.toLowerCase() == currentName?.toLowerCase());
    return index == -1 ? 0 : index + 1;
  }

  // Счётчик "поколений" запроса. Нужен, чтобы при быстром переключении
  // городов ответ от предыдущего (уже неактуального) запроса не перезаписал
  // экран поверх того города, на который пользователь уже переключился.
  int _requestId = 0;

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
    _preloadFavorites();
  }

  Future<void> _toggleUnits() async {
    HapticFeedback.selectionClick();
    final next = !_useFahrenheit;
    setState(() => _useFahrenheit = next);
    await _settingsService.setUseFahrenheit(next);
  }

  // Заранее (в фоне, не блокируя интерфейс) подгружает погоду для всех
  // избранных городов, чтобы при переключении на них через нижнюю панель
  // или свайп данные уже лежали в кэше и показывались мгновенно.
  void _preloadFavorites() {
    for (final city in _favoriteCities) {
      _weatherService.getWeatherByCityName(city).catchError((_) {
        // Тихо игнорируем — это лишь предзагрузка, ошибка не критична
        // и будет видна пользователю, если он реально откроет этот город.
        return Future.value(null);
      });
    }
  }

  Future<void> _loadWeatherByLocation() async {
    final myRequestId = ++_requestId;

    // Кэш-first: если для геолокации уже есть сохранённые данные (например,
    // после возврата с другого города), показываем их сразу без спиннера,
    // а свежие данные подгружаем в фоне и подменяем, когда придут.
    final cached = _weatherService.peekCache('geo');
    final hasFreshCache = _weatherService.isFresh('geo');
    setState(() {
      _isCurrentLocationPage = true;
      if (cached != null) {
        _weatherData = cached;
        _isLoading = false;
      } else {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    // Если кэш уже свежий (моложе 10 минут), не дёргаем сеть заново —
    // город и так переключился мгновенно, а повторный запрос только зря
    // расходует лимит API и трафик.
    if (cached != null && hasFreshCache) return;

    try {
      final position = await _locationService.getCurrentLocation();
      final weather = await _weatherService.getWeatherByCoordinates(
        position.latitude,
        position.longitude,
        cacheKey: 'geo',
      );
      if (myRequestId != _requestId) return; // пользователь уже переключился
      setState(() {
        _weatherData = weather;
        _isLoading = false;
      });
      _settingsService.setLastCity(weather.cityName);
    } catch (e) {
      if (myRequestId != _requestId) return;
      // Если уже показали данные из кэша, при ошибке фонового обновления
      // молча остаёмся на них — не выбиваем пользователя на экран ошибки
      // ради устаревшего, но всё ещё полезного прогноза.
      if (cached != null) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWeatherByCity(String cityName) async {
    final myRequestId = ++_requestId;
    final key = cityName.toLowerCase();

    // Тот же кэш-first подход, что и для геолокации: сразу показываем
    // последний известный результат по этому городу (если есть), а затем
    // обновляем в фоне — переключение между сохранёнными городами ощущается
    // мгновенным вместо ожидания нескольких секунд на каждый тап/свайп.
    final cached = _weatherService.peekCache(key);
    final hasFreshCache = _weatherService.isFresh(key);
    setState(() {
      _isCurrentLocationPage = false;
      if (cached != null) {
        _weatherData = cached;
        _isLoading = false;
      } else {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    if (cached != null && hasFreshCache) return;

    try {
      final weather = await _weatherService.getWeatherByCityName(cityName);
      if (myRequestId != _requestId) return;
      setState(() {
        _weatherData = weather;
        _isLoading = false;
      });
      _settingsService.setLastCity(weather.cityName);
    } catch (e) {
      if (myRequestId != _requestId) return;
      if (cached != null) return;
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
    HapticFeedback.lightImpact();
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

  // Переключение по индексу страницы — используется нижней панелью городов
  // (CityPageBar). Индекс 0 — геолокация, дальше — избранные по порядку.
  Future<void> _selectPage(int index) async {
    if (index == _currentPageIndex) return;
    if (index == 0) {
      await _loadWeatherByLocation();
    } else {
      final city = _favoriteCities[index - 1];
      await _loadWeatherByCity(city);
    }
  }

  Future<void> _removeFavoriteFromBar(String city) async {
    HapticFeedback.mediumImpact();
    await _settingsService.removeFavoriteCity(city);
    final favorites = await _settingsService.getFavoriteCities();
    setState(() => _favoriteCities = favorites);
  }

  void _openCitySearch() {
    HapticFeedback.lightImpact();
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
      _preloadFavorites();
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
            child: Column(
              children: [
                Expanded(
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
                // Нижняя панель переключения городов — самолётик для
                // геолокации и кружок на каждый сохранённый город, как
                // страничный индикатор в приложении погоды Apple. Панель
                // видна всегда (даже без избранных городов), а город,
                // совпадающий с текущим геолокационным, не дублируется
                // отдельным кружком — самолётик и так его показывает.
                CityPageBar(
                  currentIndex: _currentPageIndex,
                  favoriteCities: _favoriteCities,
                  geoCityName: _weatherService.peekCache('geo')?.cityName,
                  onSelect: _selectPage,
                  onRemoveFavorite: _removeFavoriteFromBar,
                ),
              ],
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
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        await _loadWeatherByLocation();
      },
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
              childAspectRatio: 1.15,
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
                  value: weather.visibility != null
                      ? '${(weather.visibility! / 1000).toStringAsFixed(1)} км'
                      : 'Нет данных',
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
    return _PressableScale(
      onTap: () => HapticFeedback.selectionClick(),
      child: Container(
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
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Небольшой переиспользуемый виджет, который слегка "сжимается" при нажатии
/// (как карточки в iOS) и даёт лёгкий тактильный отклик.
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressableScale({required this.child, this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
