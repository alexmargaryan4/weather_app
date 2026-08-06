import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../models/weather_model.dart';

/// Отвечает за передачу данных о погоде в домашние виджеты Android
/// (App Widgets на рабочем столе) через плагин `home_widget`.
///
/// Виджет — это отдельный нативный (Kotlin) компонент, который не может
/// напрямую читать память Flutter-приложения. Обмен данными идёт через
/// общее хранилище (на Android это SharedPreferences с именем
/// `HomeWidgetPreferences`), в которое пишет этот сервис через
/// [HomeWidget.saveWidgetData], а читает WeatherWidgetProvider.kt на
/// нативной стороне (тем же самым SharedPreferences напрямую).
///
/// Чтобы в самом виджете можно было переключаться между городами без
/// захода в приложение и без сети, сюда сохраняются данные не только по
/// текущему городу, но и по всем избранным — виджет просто выбирает
/// нужную запись из уже сохранённого набора.
class WidgetService {
  // Имена ключей должны совпадать один-в-один со строками, которые
  // читает нативный код в
  // android/app/src/main/kotlin/.../WeatherWidgetProvider.kt
  // (см. константы WidgetKeys в этом файле).
  static const String _keyCitiesJson = 'widget_cities_json';
  static const String _keySelectedCity = 'widget_selected_city';
  static const String _keyUseFahrenheit = 'widget_use_fahrenheit';

  // Имя класса Kotlin-провайдера виджета. Используется, чтобы после
  // записи данных явно попросить систему перерисовать уже размещённые
  // виджеты (см. android/.../widget/WeatherWidgetProvider.kt).
  //
  // ВАЖНО: home_widget строит имя класса Android-получателя как
  // "<applicationId>.<androidName>", если передан только androidName —
  // то есть "com.example.weather_app.WeatherWidgetProvider". Но
  // провайдер лежит в подпакете widget:
  // com.example.weather_app.widget.WeatherWidgetProvider.
  // Из-за этого несовпадения ComponentName не находит ни один
  // размещённый виджет, и updateAppWidget по факту ни на что не
  // действует — виджет остаётся с прежним (пустым) содержимым сколько
  // ни заходи в приложение. Поэтому здесь передаётся полный путь через
  // qualifiedAndroidName, который home_widget использует как есть, без
  // подстановки packageName.
  static const String _androidWidgetProviderName = 'WeatherWidgetProvider';
  static const String _qualifiedAndroidWidgetProviderName =
      'com.example.weather_app.widget.WeatherWidgetProvider';

  // Имя (kind) iOS-виджета. Должно совпадать один-в-один с
  // `kind` в ios/WeatherWidgetExtension/WeatherWidgetBundle.swift —
  // home_widget на iOS ищет WidgetKit-конфигурацию по этому имени, а не
  // по имени класса (на iOS нет отдельного "провайдера", как на Android).
  static const String _iOSWidgetName = 'WeatherWidget';

  /// Ключ записи для геолокации — используется тем же способом, что и
  /// WeatherService.peekCache('geo'), чтобы виджет мог показать понятную
  /// подпись "Текущее местоположение" вместо названия города.
  static const String geoKey = '__geo__';

  // Все операции, которые читают-меняют-пишут общий JSON с городами
  // (updateCity/removeCity/syncFavorites), должны выполняться строго по
  // очереди. Раньше они запускались параллельно (HomeScreen дергает их
  // через unawaited из разных мест: _loadWeatherByLocation,
  // _loadWeatherByCity, _init -> syncFavorites), и два одновременных
  // read-modify-write могли затереть результат друг друга — например,
  // геолокация успевала записаться, но следом syncFavorites читал ещё
  // старую версию (без гео) и сохранял её обратно, стирая только что
  // записанные данные. Отсюда и ощущение "виджет то показывает, то нет".
  // _queue гарантирует, что каждая операция видит результат предыдущей.
  Future<void> _queue = Future.value();

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    // Ошибка одной операции не должна блокировать очередь для следующих.
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Сохраняет данные по одному городу (или по геолокации, если [key] ==
  /// [geoKey]) в набор, доступный виджету. Не трогает записи по другим
  /// городам — так набор пополняется постепенно, по мере того как
  /// пользователь открывает разные города в самом приложении.
  Future<void> updateCity({
    required String key,
    required WeatherData weather,
    required String displayName,
  }) {
    return _enqueue(() async {
      final cities = await _readCities();
      cities[key] = _WidgetCityEntry(
        key: key,
        displayName: displayName,
        tempCelsius: weather.temp,
        iconCode: weather.iconCode,
        description: weather.description,
      );
      await _writeCities(cities);
      await _requestWidgetUpdate();
    });
  }

  /// Убирает запись о городе из набора, доступного виджету (например,
  /// когда пользователь удалил город из избранного).
  Future<void> removeCity(String key) {
    return _enqueue(() async {
      final cities = await _readCities();
      cities.remove(key);
      await _writeCities(cities);
      await _requestWidgetUpdate();
    });
  }

  /// Убирает из набора виджета города, которые пользователь явно удалил
  /// из избранного. geoKey и любые другие ключи (в том числе города,
  /// которые сейчас не в избранном, но были недавно открыты через поиск)
  /// не трогаются — пользователю нет причин ожидать, что просто открытый
  /// город исчезнет из виджета сам по себе. Единственная цель этой
  /// функции — очистить записи по городам, убранным из избранного, что
  /// корректно делает removeCity при явном удалении; syncFavorites
  /// оставлен как более лёгкая "уборка" на случай рассинхронизации
  /// (например, после переустановки/обновления приложения), а не как
  /// фильтр "показывать только избранное".
  Future<void> syncFavorites({
    required List<String> favoriteKeysLowercase,
  }) {
    return _enqueue(() async {
      final cities = await _readCities();
      // Убираем только явно удалённые из избранного города. Текущий
      // выбранный в виджете город (или геолокация) не удаляется, даже
      // если он не в списке избранного — иначе виджет может остаться
      // совсем без данных для отображения.
      final selected = await HomeWidget.getWidgetData<String>(_keySelectedCity);
      cities.removeWhere((key, _) =>
          key != geoKey &&
          key != selected &&
          !favoriteKeysLowercase.contains(key));
      await _writeCities(cities);
      await _requestWidgetUpdate();
    });
  }

  /// Устанавливает, какой город виджет должен показывать "по умолчанию".
  /// Обычно совпадает с тем, что видно на главном экране в момент выхода
  /// из приложения. Пользователь может переключить это прямо в виджете —
  /// тогда нативная сторона сама обновит этот ключ.
  Future<void> setSelectedCity(String key) {
    return _enqueue(() async {
      await HomeWidget.saveWidgetData<String>(_keySelectedCity, key);
      await _requestWidgetUpdate();
    });
  }

  Future<void> setUseFahrenheit(bool value) {
    return _enqueue(() async {
      await HomeWidget.saveWidgetData<bool>(_keyUseFahrenheit, value);
      await _requestWidgetUpdate();
    });
  }

  /// Читает город, который в данный момент выбран в виджете (пользователь
  /// мог переключить его прямо там, без открытия приложения). Используется
  /// при обработке тапа по виджету, чтобы открыть приложение сразу на
  /// нужном городе. Возвращает null, если данных ещё нет.
  Future<String?> getSelectedCityFromWidget() async {
    return HomeWidget.getWidgetData<String>(_keySelectedCity);
  }

  Future<Map<String, _WidgetCityEntry>> _readCities() async {
    final raw = await HomeWidget.getWidgetData<String>(_keyCitiesJson);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, _WidgetCityEntry.fromJson(value)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeCities(Map<String, _WidgetCityEntry> cities) async {
    final encoded = jsonEncode(
      cities.map((key, value) => MapEntry(key, value.toJson())),
    );
    await HomeWidget.saveWidgetData<String>(_keyCitiesJson, encoded);
  }

  /// Просит систему перерисовать все размещённые виджеты этого приложения
  /// с уже сохранёнными данными — на Android через ComponentName
  /// нативного провайдера, на iOS через kind WidgetKit-конфигурации.
  Future<void> _requestWidgetUpdate() async {
    await HomeWidget.updateWidget(
      name: _androidWidgetProviderName,
      androidName: _androidWidgetProviderName,
      qualifiedAndroidName: _qualifiedAndroidWidgetProviderName,
      iOSName: _iOSWidgetName,
    );
  }
}

/// Данные по одному городу в компактном виде, достаточном для отрисовки
/// в виджете (без часового/дневного прогноза — они там не показываются).
class _WidgetCityEntry {
  final String key;
  final String displayName;
  final double tempCelsius;
  final String iconCode;
  final String description;

  _WidgetCityEntry({
    required this.key,
    required this.displayName,
    required this.tempCelsius,
    required this.iconCode,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'displayName': displayName,
        'tempCelsius': tempCelsius,
        'iconCode': iconCode,
        'description': description,
      };

  factory _WidgetCityEntry.fromJson(Map<String, dynamic> json) =>
      _WidgetCityEntry(
        key: json['key'] as String,
        displayName: json['displayName'] as String,
        tempCelsius: (json['tempCelsius'] as num).toDouble(),
        iconCode: json['iconCode'] as String,
        description: json['description'] as String,
      );
}
