import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';

/// Простая (без кодогенерации) локализация приложения.
///
/// Поддерживаются: русский (ru), английский (en, значение по умолчанию),
/// армянский (hy). Язык определяется автоматически по локали устройства
/// (см. [AppLocalizations.delegate] и `supportedLocales` в main.dart) —
/// если язык устройства не входит в список поддерживаемых, используется
/// английский.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const supportedLocales = [
    Locale('en'),
    Locale('ru'),
    Locale('hy'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String get _lang => locale.languageCode;

  // Код языка для передачи в OpenWeatherMap API (параметр lang).
  // У армянского нет прямой поддержки на стороне OpenWeatherMap, поэтому
  // для него описание погоды запрашивается на английском.
  String get weatherApiLangCode => _lang == 'ru' ? 'ru' : 'en';

  static const Map<String, Map<String, String>> _strings = {
    'appTitle': {
      'en': 'Weather+',
      'ru': 'Погода+',
      'hy': 'Եղանակ+',
    },
    'splashTagline': {
      'en': 'Accurate forecast every day',
      'ru': 'Точный прогноз каждый день',
      'hy': 'Ճշգրիտ կանխատեսում ամեն օր',
    },
    'tryAgain': {
      'en': 'Try again',
      'ru': 'Попробовать снова',
      'hy': 'Փորձել կրկին',
    },
    'chooseCityManually': {
      'en': 'Or choose a city manually',
      'ru': 'Или выбрать город вручную',
      'hy': 'Կամ ընտրել քաղաքը ձեռքով',
    },
    'feelsLike': {
      'en': 'Feels like',
      'ru': 'Ощущается как',
      'hy': 'Զգացվում է որպես',
    },
    'wind': {
      'en': 'Wind',
      'ru': 'Ветер',
      'hy': 'Քամի',
    },
    'humidity': {
      'en': 'Humidity',
      'ru': 'Влажность',
      'hy': 'Խոնավություն',
    },
    'pressure': {
      'en': 'Pressure',
      'ru': 'Давление',
      'hy': 'Ճնշում',
    },
    'visibility': {
      'en': 'Visibility',
      'ru': 'Видимость',
      'hy': 'Տեսանելիություն',
    },
    'noData': {
      'en': 'No data',
      'ru': 'Нет данных',
      'hy': 'Տվյալներ չկան',
    },
    'unitsTooltip': {
      'en': 'Units',
      'ru': 'Единицы измерения',
      'hy': 'Չափման միավորներ',
    },
    'hourlyForecast': {
      'en': 'HOURLY FORECAST',
      'ru': 'ПОЧАСОВОЙ ПРОГНОЗ',
      'hy': 'ԺԱՄԱՅԻՆ ԿԱՆԽԱՏԵՍՈՒՄ',
    },
    'now': {
      'en': 'Now',
      'ru': 'Сейчас',
      'hy': 'Հիմա',
    },
    'fiveDayForecast': {
      'en': '5-DAY FORECAST',
      'ru': 'ПРОГНОЗ НА 5 ДНЕЙ',
      'hy': '5-ՕՐՅԱ ԿԱՆԽԱՏԵՍՈՒՄ',
    },
    'today': {
      'en': 'Today',
      'ru': 'Сегодня',
      'hy': 'Այսօր',
    },
    'sun': {
      'en': 'SUN',
      'ru': 'СОЛНЦЕ',
      'hy': 'ԱՐԵՎ',
    },
    'sunrise': {
      'en': 'Sunrise',
      'ru': 'Восход',
      'hy': 'Արևածագ',
    },
    'sunset': {
      'en': 'Sunset',
      'ru': 'Закат',
      'hy': 'Մայրամուտ',
    },
    'airQuality': {
      'en': 'AIR QUALITY',
      'ru': 'КАЧЕСТВО ВОЗДУХА',
      'hy': 'ՕԴԻ ՈՐԱԿԸ',
    },
    'aqiExcellent': {
      'en': 'Excellent',
      'ru': 'Отличное',
      'hy': 'Գերազանց',
    },
    'aqiGood': {
      'en': 'Good',
      'ru': 'Хорошее',
      'hy': 'Լավ',
    },
    'aqiModerate': {
      'en': 'Moderate',
      'ru': 'Среднее',
      'hy': 'Միջին',
    },
    'aqiPoor': {
      'en': 'Poor',
      'ru': 'Плохое',
      'hy': 'Վատ',
    },
    'aqiVeryPoor': {
      'en': 'Very poor',
      'ru': 'Очень плохое',
      'hy': 'Շատ վատ',
    },
    'changeCity': {
      'en': 'Change city',
      'ru': 'Изменить город',
      'hy': 'Փոխել քաղաքը',
    },
    'enterCityName': {
      'en': 'Enter city name',
      'ru': 'Введите название города',
      'hy': 'Մուտքագրեք քաղաքի անունը',
    },
    'useMyLocation': {
      'en': 'Use my location',
      'ru': 'Использовать мою геолокацию',
      'hy': 'Օգտագործել իմ գտնվելու վայրը',
    },
    'favoriteCities': {
      'en': 'FAVORITE CITIES',
      'ru': 'ИЗБРАННЫЕ ГОРОДА',
      'hy': 'ԸՆՏՐԱՆԻ ՔԱՂԱՔՆԵՐ',
    },
    'myLocation': {
      'en': 'My location',
      'ru': 'Моя геолокация',
      'hy': 'Իմ գտնվելու վայրը',
    },
    'goToCity': {
      'en': 'Go to city',
      'ru': 'Перейти к городу',
      'hy': 'Անցնել քաղաք',
    },
    'removeFromFavorites': {
      'en': 'Remove from favorites',
      'ru': 'Удалить из избранного',
      'hy': 'Հեռացնել ընտրանիից',
    },
    'errorAuth': {
      'en': 'API authorization error. Check your OpenWeatherMap key.',
      'ru': 'Ошибка авторизации API. Проверьте ключ OpenWeatherMap.',
      'hy': 'API-ի լիազորման սխալ։ Ստուգեք OpenWeatherMap բանալին։',
    },
    'errorNotFound': {
      'en': 'Data not found.',
      'ru': 'Данные не найдены.',
      'hy': 'Տվյալները չեն գտնվել։',
    },
    'errorCityNotFound': {
      'en': 'City not found. Check the name.',
      'ru': 'Город не найден. Проверьте название.',
      'hy': 'Քաղաքը չի գտնվել։ Ստուգեք անունը։',
    },
    'errorRateLimit': {
      'en': 'Weather service request limit exceeded. Try again later.',
      'ru': 'Превышен лимит запросов к погодному сервису. Попробуйте позже.',
      'hy': 'Եղանակի ծառայության հարցումների սահմանաչափը գերազանցվել է։ Փորձեք ավելի ուշ։',
    },
    'errorGeneric': {
      'en': 'Failed to load weather. Code: {code}',
      'ru': 'Не удалось загрузить погоду. Код: {code}',
      'hy': 'Չհաջողվեց բեռնել եղանակը։ Կոդ՝ {code}',
    },
    'errorForecastLoad': {
      'en': 'Failed to load forecast for this city',
      'ru': 'Не удалось загрузить прогноз для этого города',
      'hy': 'Չհաջողվեց բեռնել այս քաղաքի կանխատեսումը',
    },
    'errorNoInternet': {
      'en': 'No internet connection. Check your network and try again.',
      'ru': 'Нет соединения с интернетом. Проверьте сеть и попробуйте снова.',
      'hy': 'Ինտերնետ կապ չկա։ Ստուգեք ցանցը և փորձեք կրկին։',
    },
    'errorLocationServiceDisabled': {
      'en': 'Location services are disabled. Enable them in settings.',
      'ru': 'Службы геолокации отключены. Включите их в настройках.',
      'hy': 'Դիրքորոշման ծառայությունները անջատված են։ Միացրեք դրանք կարգավորումներում։',
    },
    'errorLocationDenied': {
      'en': 'Location access denied by user.',
      'ru': 'Доступ к геолокации отклонён пользователем.',
      'hy': 'Օգտատերը մերժել է դիրքորոշման հասանելիությունը։',
    },
    'errorLocationDeniedForever': {
      'en': 'Location access permanently blocked. Allow it in phone settings.',
      'ru': 'Доступ к геолокации заблокирован навсегда. Разрешите в настройках телефона.',
      'hy': 'Դիրքորոշման հասանելիությունը մշտապես արգելափակված է։ Թույլատրեք հեռախոսի կարգավորումներում։',
    },
    'windUnit': {
      'en': 'm/s',
      'ru': 'м/с',
      'hy': 'մ/վ',
    },
    'pressureUnit': {
      'en': 'mmHg',
      'ru': 'мм',
      'hy': 'մմ',
    },
    'visibilityUnit': {
      'en': 'km',
      'ru': 'км',
      'hy': 'կմ',
    },
    'myLocationTooltip': {
      'en': 'My location',
      'ru': 'Моя геолокация',
      'hy': 'Իմ գտնվելու վայրը',
    },
  };

  String _t(String key) {
    final entry = _strings[key];
    if (entry == null) return key;
    return entry[_lang] ?? entry['en']!;
  }

  String get appTitle => _t('appTitle');
  String get splashTagline => _t('splashTagline');
  String get tryAgain => _t('tryAgain');
  String get chooseCityManually => _t('chooseCityManually');
  String get feelsLike => _t('feelsLike');
  String get wind => _t('wind');
  String get humidity => _t('humidity');
  String get pressure => _t('pressure');
  String get visibility => _t('visibility');
  String get noData => _t('noData');
  String get unitsTooltip => _t('unitsTooltip');
  String get hourlyForecast => _t('hourlyForecast');
  String get now => _t('now');
  String get fiveDayForecast => _t('fiveDayForecast');
  String get today => _t('today');
  String get sun => _t('sun');
  String get sunrise => _t('sunrise');
  String get sunset => _t('sunset');
  String get airQuality => _t('airQuality');
  String get aqiExcellent => _t('aqiExcellent');
  String get aqiGood => _t('aqiGood');
  String get aqiModerate => _t('aqiModerate');
  String get aqiPoor => _t('aqiPoor');
  String get aqiVeryPoor => _t('aqiVeryPoor');
  String get changeCity => _t('changeCity');
  String get enterCityName => _t('enterCityName');
  String get useMyLocation => _t('useMyLocation');
  String get favoriteCities => _t('favoriteCities');
  String get myLocation => _t('myLocation');
  String get goToCity => _t('goToCity');
  String get removeFromFavorites => _t('removeFromFavorites');
  String get errorAuth => _t('errorAuth');
  String get errorNotFound => _t('errorNotFound');
  String get errorCityNotFound => _t('errorCityNotFound');
  String get errorRateLimit => _t('errorRateLimit');
  String errorGeneric(int code) => _t('errorGeneric').replaceAll('{code}', '$code');
  String get errorForecastLoad => _t('errorForecastLoad');
  String get errorNoInternet => _t('errorNoInternet');
  String get errorLocationServiceDisabled => _t('errorLocationServiceDisabled');
  String get errorLocationDenied => _t('errorLocationDenied');
  String get errorLocationDeniedForever => _t('errorLocationDeniedForever');
  String get windUnit => _t('windUnit');
  String get pressureUnit => _t('pressureUnit');
  String get visibilityUnit => _t('visibilityUnit');
  String get myLocationTooltip => _t('myLocationTooltip');

  // Локализованный ярлык дня недели для DateFormat.E(locale) — используется
  // в daily_forecast.dart, чтобы формат даты тоже уважал выбранный язык.
  String get dateFormatLocale => _lang;

  // Переводит исключение WeatherService в готовый локализованный текст
  // для показа пользователю на экране ошибки.
  String messageForWeatherError(WeatherServiceException e) {
    switch (e.type) {
      case WeatherErrorType.auth:
        return errorAuth;
      case WeatherErrorType.notFound:
        return errorNotFound;
      case WeatherErrorType.cityNotFound:
        return errorCityNotFound;
      case WeatherErrorType.rateLimit:
        return errorRateLimit;
      case WeatherErrorType.noInternet:
        return errorNoInternet;
      case WeatherErrorType.forecastLoad:
        return errorForecastLoad;
      case WeatherErrorType.generic:
        return errorGeneric(e.statusCode ?? 0);
    }
  }

  // Переводит исключение LocationService в готовый локализованный текст.
  String messageForLocationError(LocationServiceException e) {
    switch (e.type) {
      case LocationErrorType.serviceDisabled:
        return errorLocationServiceDisabled;
      case LocationErrorType.permissionDenied:
        return errorLocationDenied;
      case LocationErrorType.permissionDeniedForever:
        return errorLocationDeniedForever;
    }
  }

  // Единая точка перевода любой ошибки, пойманной в HomeScreen, в текст.
  // Падает обратно на errorGeneric с кодом 0, если тип исключения неизвестен
  // (например, неожиданная ошибка платформы геолокации).
  String messageForError(Object e) {
    if (e is WeatherServiceException) return messageForWeatherError(e);
    if (e is LocationServiceException) return messageForLocationError(e);
    return errorGeneric(0);
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // Если язык устройства не входит в поддерживаемые, используем английский.
    final isSupported =
        AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);
    return AppLocalizations(isSupported ? locale : const Locale('en'));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
