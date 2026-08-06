import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../localization/app_localizations.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../services/analytics_service.dart';
import '../services/widget_service.dart';
import '../utils/temperature_utils.dart';
import '../widgets/animated_background.dart';
import '../widgets/hourly_forecast.dart';
import '../widgets/daily_forecast.dart';
import '../widgets/city_search_sheet.dart';
import '../widgets/sun_arc.dart';
import '../widgets/air_quality_card.dart';
import '../widgets/city_page_bar.dart';
import '../widgets/moon_phase_card.dart';
import '../widgets/precipitation_card.dart';
import '../widgets/temperature_chart.dart';
import '../widgets/umbrella_reminder_banner.dart';
import '../widgets/comfort_index_card.dart';
import '../widgets/weather_maps_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WeatherService _weatherService = WeatherService();
  final LocationService _locationService = LocationService();
  final SettingsService _settingsService = SettingsService();
  final WidgetService _widgetService = WidgetService();

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

  // Подписка на клики по виджету, пока приложение уже открыто (например,
  // свёрнуто в фон, а не полностью закрыто). initiallyLaunchedFromHomeWidget
  // ниже покрывает холодный запуск — этот стрим нужен для тёплого.
  StreamSubscription<Uri?>? _widgetClickSubscription;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final useFahrenheit = await _settingsService.getUseFahrenheit();
    final favorites = await _settingsService.getFavoriteCities();
    setState(() {
      _useFahrenheit = useFahrenheit;
      _favoriteCities = favorites;
    });

    // Если приложение открыто тапом по конкретному городу в виджете —
    // сразу переходим на этот город вместо геолокации по умолчанию.
    final cityFromWidget = await _cityKeyFromWidgetLaunch();

    _widgetClickSubscription =
        HomeWidget.widgetClicked.listen(_handleWidgetClickUri);

    if (cityFromWidget != null && cityFromWidget != WidgetService.geoKey) {
      await _loadWeatherByCity(cityFromWidget);
      // Экран открыт сразу на конкретном городе (тап по чипсу в виджете),
      // поэтому _loadWeatherByLocation() выше не вызывается и геолокация
      // никогда не попадёт в данные виджета — из-за этого при запуске
      // только через чипсы городов чипс геолокации в виджете не появлялся
      // вообще, даже если разрешение есть и всё бы отработало. Подгружаем
      // её отдельно в фоне, не блокируя показ уже выбранного города.
      _preloadLocationForWidget();
    } else {
      await _loadWeatherByLocation();
    }
    _preloadFavorites();
    unawaited(_widgetService.syncFavorites(
      favoriteKeysLowercase: favorites.map((c) => c.toLowerCase()).toList(),
    ));

    // Аналитика отключена — AnalyticsService теперь ничего не делает и
    // никуда не отправляет данные (см. services/analytics_service.dart).
    AnalyticsService.instance.trackAppOpen(
      countryCode: _weatherData?.countryCode,
      cityName: _weatherData?.cityName,
    );
  }

  // Определяет, каким городом было запущено приложение — либо холодным
  // стартом через тап по виджету (initiallyLaunchedFromHomeWidget), либо
  // просто читает последний выбранный в виджете город как запасной
  // вариант. Возвращает null, если приложение открыто обычным способом
  // (с рабочего стола/из списка приложений, а не из виджета).
  Future<String?> _cityKeyFromWidgetLaunch() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (uri != null) {
        // Ключ параметра должен совпадать с тем, что кладёт
        // WeatherWidgetProvider.launchAppIntent на нативной стороне
        // ("weather_app://widget?city_key=..."), а не "city".
        final city = uri.queryParameters['city_key'];
        if (city != null && city.isNotEmpty) return city;
      }
    } catch (_) {
      // Плагин недоступен (например, платформа без поддержки) — просто
      // продолжаем обычный запуск по геолокации.
    }
    return null;
  }

  void _handleWidgetClickUri(Uri? uri) {
    // См. комментарий в _cityKeyFromWidgetLaunch — параметр называется
    // "city_key" на нативной стороне, а не "city".
    final city = uri?.queryParameters['city_key'];
    if (city == null || city.isEmpty) return;
    if (city == WidgetService.geoKey) {
      _loadWeatherByLocation();
    } else {
      _loadWeatherByCity(city);
    }
  }

  Future<void> _toggleUnits() async {
    HapticFeedback.selectionClick();
    final next = !_useFahrenheit;
    setState(() => _useFahrenheit = next);
    await _settingsService.setUseFahrenheit(next);
    unawaited(_widgetService.setUseFahrenheit(next));
  }

  // Заранее (в фоне, не блокируя интерфейс) подгружает погоду для всех
  // избранных городов, чтобы при переключении на них через нижнюю панель
  // или свайп данные уже лежали в кэше и показывались мгновенно.
  //
  // Также передаёт каждый результат в WidgetService: раньше это делалось
  // только при реальном открытии города на экране, поэтому виджет "не
  // всегда" знал погоду избранных городов — если пользователь их давно
  // не открывал вручную, чипсы в виджете показывали устаревшие данные
  // или не показывали их вовсе.
  void _preloadFavorites() {
    for (final city in _favoriteCities) {
      final key = city.toLowerCase();
      _weatherService.getWeatherByCityName(city).then((weather) {
        unawaited(_widgetService.updateCity(
          key: key,
          weather: weather,
          displayName: weather.cityName,
        ));
      }).catchError((_) {
        // Тихо игнорируем — это лишь предзагрузка, ошибка не критична
        // и будет видна пользователю, если он реально откроет этот город.
        return null;
      });
    }
  }

  // Тихо подгружает геолокацию в фоне и передаёт результат в WidgetService,
  // не трогая экран (в отличие от _loadWeatherByLocation, здесь нет setState
  // и нет своего _requestId — экран в этот момент уже занят другим городом,
  // на который приложение было открыто через виджет).
  //
  // Нужен только для одного сценария: приложение запущено тапом по чипсу
  // конкретного города в виджете, из-за чего _loadWeatherByLocation() в
  // _init() не вызывается вовсе. Без этого геолокация не появлялась бы в
  // данных виджета, пока пользователь ни разу не откроет приложение
  // "обычным способом" — с рабочего стола, а не через сам виджет.
  //
  // Если геолокация недоступна (нет разрешения, служба выключена и т.п.),
  // ошибка молча проглатывается — мы уже показываем выбранный виджетом
  // город, и это лишь фоновая попытка, а не то, чего ждёт пользователь на
  // экране прямо сейчас.
  void _preloadLocationForWidget() {
    // Если для геолокации уже есть недавние данные, не дёргаем сеть — это
    // лишь предзагрузка, а не показ на экране.
    if (_weatherService.isFresh('geo')) return;
    _locationService.getCurrentLocation().then((position) async {
      if (!mounted) return;
      final langCode = AppLocalizations.of(context).weatherApiLangCode;
      final weather = await _weatherService.getWeatherByCoordinates(
        position.latitude,
        position.longitude,
        cacheKey: 'geo',
        langCode: langCode,
      );
      unawaited(_widgetService.updateCity(
        key: WidgetService.geoKey,
        weather: weather,
        displayName: weather.cityName,
      ));
    }).catchError((_) {
      // Нет доступа/разрешения — по договорённости просто не показываем
      // чипс геолокации в виджете, пока запрос не пройдёт успешно.
      return null;
    });
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
    // расходует лимит API и трафик. Но виджет всё равно нужно уведомить,
    // что сейчас на экране геолокация — иначе при возврате на неё внутри
    // одной сессии (например, свайпнули на другой город и обратно) виджет
    // остаётся выбранным на прежнем городе, хотя экран уже показывает
    // геопозицию.
    if (cached != null && hasFreshCache) {
      unawaited(_widgetService.setSelectedCity(WidgetService.geoKey));
      return;
    }

    try {
      final position = await _locationService.getCurrentLocation();
      if (!mounted) return;
      final langCode = AppLocalizations.of(context).weatherApiLangCode;
      final weather = await _weatherService.getWeatherByCoordinates(
        position.latitude,
        position.longitude,
        cacheKey: 'geo',
        langCode: langCode,
      );
      if (myRequestId != _requestId) return; // пользователь уже переключился
      setState(() {
        _weatherData = weather;
        _isLoading = false;
      });
      _settingsService.setLastCity(weather.cityName);
      AnalyticsService.instance.trackWeatherRequest(
        cityName: weather.cityName,
        countryCode: weather.countryCode,
        source: 'geolocation',
      );
      unawaited(_widgetService.updateCity(
        key: WidgetService.geoKey,
        weather: weather,
        displayName: weather.cityName,
      ));
      unawaited(_widgetService.setSelectedCity(WidgetService.geoKey));
    } catch (e) {
      if (myRequestId != _requestId) return;
      // Если уже показали данные из кэша, при ошибке фонового обновления
      // молча остаёмся на них — не выбиваем пользователя на экран ошибки
      // ради устаревшего, но всё ещё полезного прогноза.
      if (cached != null) return;
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(context).messageForError(e);
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
      final langCode = AppLocalizations.of(context).weatherApiLangCode;
      final weather = await _weatherService.getWeatherByCityName(cityName,
          langCode: langCode);
      if (myRequestId != _requestId) return;
      setState(() {
        _weatherData = weather;
        _isLoading = false;
      });
      _settingsService.setLastCity(weather.cityName);
      AnalyticsService.instance.trackWeatherRequest(
        cityName: weather.cityName,
        countryCode: weather.countryCode,
        source: 'search',
      );
      // Ключ виджета для города — тот же lowercase-ключ, что использует
      // WeatherService для кэша, чтобы избранное и виджет ссылались на
      // одни и те же записи.
      unawaited(_widgetService.updateCity(
        key: key,
        weather: weather,
        displayName: weather.cityName,
      ));
      // Раньше виджет переключался на открытый город, только если он уже
      // был в избранном — если пользователь просто посмотрел город через
      // поиск, виджет продолжал показывать что-то другое, хотя человек
      // только что открыл именно этот город. Виджет должен отражать то,
      // что видно на экране в момент выхода из приложения, вне
      // зависимости от того, добавлен город в избранное или нет.
      unawaited(_widgetService.setSelectedCity(key));
    } catch (e) {
      if (myRequestId != _requestId) return;
      if (cached != null) return;
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(context).messageForError(e);
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
    AnalyticsService.instance.trackFavoriteRemoved(city);
    unawaited(_widgetService.removeCity(city.toLowerCase()));
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
      unawaited(_widgetService.syncFavorites(
        favoriteKeysLowercase:
            favorites.map((c) => c.toLowerCase()).toList(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Высота системного статус-бара (время/батарея/индикаторы) — контент
    // теперь физически скроллится под эту зону (не обрезается SafeArea
    // сверху), а поверх неё лежит размытая полупрозрачная панель, поэтому
    // при скролле текст не "пропадает в пустоте", а виден сквозь блюр,
    // как в iOS/большинстве нативных приложений.
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),
      body: SizedBox.expand(
        child: AnimatedWeatherBackground(
          iconCode: _weatherData?.iconCode ?? '01d',
          child: Stack(
            children: [
              // Основной контент — начинается от самого верха экрана (под
              // статус-бар), поэтому при скролле карточки/текст проезжают
              // под блюр-панелью ниже, а не под "пустым" пространством.
              SafeArea(
                top: false,
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
                          child: _buildBody(statusBarHeight),
                        ),
                      ),
                    ),
                    // Нижняя панель переключения городов — самолётик для
                    // геолокации и кружок на каждый сохранённый город, как
                    // страничный индикатор в приложении погоды Apple. Панель
                    // видна всегда (даже без избранных городов), а город,
                    // совпадающий с текущим геолокационным, не дублируется
                    // отдельным кружком — самолётик и так его показывает.
                    
                  ],
                ),
              ),
              // Размытая полупрозрачная панель поверх статус-бара. Лежит
              // над скролл-контентом (выше него в Stack), поэтому всё, что
              // проезжает под ней при скролле, видно приглушённо сквозь
              // блюр, а не резко обрезается. Positioned явно прибивает её
              // к верхнему краю на всю ширину, независимо от того, как
              // именно распределены размеры внутри Stack.
              Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: CityPageBar(
        currentIndex: _currentPageIndex,
        favoriteCities: _favoriteCities,
        geoCityName: _weatherService.peekCache('geo')?.cityName,
        onSelect: _selectPage,
        onRemoveFavorite: _removeFavoriteFromBar,
      ),
    ),

    Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: _StatusBarBlur(height: statusBarHeight),
      ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(double statusBarHeight) {
    final l10n = AppLocalizations.of(context);
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
                child: Text(l10n.tryAgain),
              ),
              TextButton(
                onPressed: _openCitySearch,
                child: Text(
                  l10n.chooseCityManually,
                  style: const TextStyle(color: Colors.white70),
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
        padding: EdgeInsets.fromLTRB(
            16, statusBarHeight + 12, 16, 20),
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
                    tooltip: l10n.unitsTooltip,
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
                    '${l10n.feelsLike} ${TemperatureUtils.format(weather.feelsLike, _useFahrenheit)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Напоминание про зонт — показывается только когда вероятность
            // дождя в ближайшие часы достаточно высокая, чтобы не мозолить
            // глаза лишним баннером в солнечную погоду.
            if (_shouldShowUmbrellaReminder(weather)) ...[
              const UmbrellaReminderBanner(),
              const SizedBox(height: 16),
            ],

            HourlyForecastList(
                hourly: weather.hourly, useFahrenheit: _useFahrenheit),
            const SizedBox(height: 16),

            TemperatureChart(
                hourly: weather.hourly, useFahrenheit: _useFahrenheit),
            const SizedBox(height: 16),

            PrecipitationCard(
              currentProbability: weather.precipitationProbability,
              hourly: weather.hourly,
            ),
            const SizedBox(height: 16),

            DailyForecastList(
                daily: weather.daily, useFahrenheit: _useFahrenheit),

            const SizedBox(height: 16),

            SunArcCard(sunrise: weather.sunrise, sunset: weather.sunset),

            const SizedBox(height: 16),

            MoonPhaseCard(date: DateTime.now()),

            const SizedBox(height: 16),

            ComfortIndexCard(
              tempCelsius: weather.temp,
              humidityPercent: weather.humidity,
              windSpeedMs: weather.windSpeed,
              uvIndex: weather.uvIndex,
              precipitationProbability: weather.precipitationProbability,
            ),

            const SizedBox(height: 16),

            AirQualityCard(aqi: weather.airQualityIndex),

            const SizedBox(height: 16),

            WeatherMapsSection(lat: weather.lat, lon: weather.lon),

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
                  label: l10n.wind,
                  value: '${weather.windSpeed.round()} ${l10n.windUnit}',
                ),
                _buildInfoCard(
                  icon: Icons.water_drop_outlined,
                  label: l10n.humidity,
                  value: '${weather.humidity}%',
                ),
                _buildInfoCard(
                  icon: Icons.speed_rounded,
                  label: l10n.pressure,
                  value:
                      '${(weather.pressure * 0.750062).round()} ${l10n.pressureUnit}',
                ),
                _buildInfoCard(
                  icon: Icons.visibility_outlined,
                  label: l10n.visibility,
                  value: weather.visibility != null
                      ? '${(weather.visibility! / 1000).toStringAsFixed(1)} ${l10n.visibilityUnit}'
                      : l10n.noData,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Показывать баннер "возьмите зонт", если вероятность осадков прямо
  // сейчас высокая, либо она станет высокой в ближайшие несколько часов —
  // человеку нужно предупреждение до выхода из дома, а не только когда
  // дождь уже идёт.
  bool _shouldShowUmbrellaReminder(WeatherData weather) {
    const threshold = 0.4;
    if ((weather.precipitationProbability ?? 0) >= threshold) return true;
    final nextHours = weather.hourly.take(4);
    return nextHours.any((h) => h.pop >= threshold);
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

/// Размытая полупрозрачная панель поверх системного статус-бара.
///
/// Раньше статус-бар просто был пустой зоной над контентом (SafeArea
/// отступал контент вниз), и при скролле текст/карточки резко "выныривали"
/// прямо под системными часами/батареей. Теперь контент скроллится под всю
/// эту зону, а данный виджет лежит поверх неё в Stack и размывает всё, что
/// проезжает под ним — как статус-бар в iOS и большинстве нативных
/// Android-приложений.
class _StatusBarBlur extends StatelessWidget {
  final double height;

  const _StatusBarBlur({
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (height <= 0) {
      return const SizedBox.shrink();
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 4.0,
          sigmaY: 4.0,
        ),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Основной стеклянный слой
              Container(
                color: Colors.white.withOpacity(0.025),
              ),

              // Верхний блик
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [
                      0.0,
                      0.15,
                      0.4,
                      1.0,
                    ],
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Лёгкая дымка
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withOpacity(0.015),
                      Colors.transparent,
                      Colors.white.withOpacity(0.015),
                    ],
                  ),
                ),
              ),

              // Нижнее затемнение
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.025),
                      ],
                    ),
                  ),
                ),
              ),

              // Нижняя граница
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 0.5,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),

              // Верхний внутренний блик
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: 1,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ],
          ),
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
