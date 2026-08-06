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
    'noCitiesFound': {
      'en': 'No cities found',
      'ru': 'Города не найдены',
      'hy': 'Քաղաքներ չեն գտնվել',
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

    // --- Фаза луны ---
    'moonPhase': {
      'en': 'MOON PHASE',
      'ru': 'ФАЗА ЛУНЫ',
      'hy': 'ԼՈՒՍՆԻ ՓՈՒԼԸ',
    },
    'moonNew': {
      'en': 'New Moon',
      'ru': 'Новолуние',
      'hy': 'Նորալուսին',
    },
    'moonWaxingCrescent': {
      'en': 'Waxing Crescent',
      'ru': 'Растущий серп',
      'hy': 'Աճող մանգաղ',
    },
    'moonFirstQuarter': {
      'en': 'First Quarter',
      'ru': 'Первая четверть',
      'hy': 'Առաջին քառորդ',
    },
    'moonWaxingGibbous': {
      'en': 'Waxing Gibbous',
      'ru': 'Растущая луна',
      'hy': 'Աճող լուսին',
    },
    'moonFull': {
      'en': 'Full Moon',
      'ru': 'Полнолуние',
      'hy': 'Լիալուսին',
    },
    'moonWaningGibbous': {
      'en': 'Waning Gibbous',
      'ru': 'Убывающая луна',
      'hy': 'Նվազող լուսին',
    },
    'moonLastQuarter': {
      'en': 'Last Quarter',
      'ru': 'Последняя четверть',
      'hy': 'Վերջին քառորդ',
    },
    'moonWaningCrescent': {
      'en': 'Waning Crescent',
      'ru': 'Убывающий серп',
      'hy': 'Նվազող մանգաղ',
    },
    'moonIllumination': {
      'en': 'illumination',
      'ru': 'освещённость',
      'hy': 'լուսավորվածություն',
    },

    // --- Вероятность осадков ---
    'precipitationChance': {
      'en': 'CHANCE OF RAIN',
      'ru': 'ВЕРОЯТНОСТЬ ОСАДКОВ',
      'hy': 'ՏԵՂՈՒՄՆԵՐԻ ՀԱՎԱՆԱԿԱՆՈՒԹՅՈՒՆ',
    },
    'precipitationNow': {
      'en': 'Right now',
      'ru': 'Прямо сейчас',
      'hy': 'Հենց հիմա',
    },

    // --- График температуры ---
    'temperatureTrend': {
      'en': 'TEMPERATURE TREND',
      'ru': 'ИЗМЕНЕНИЕ ТЕМПЕРАТУРЫ',
      'hy': 'ՋԵՐՄԱՍՏԻՃԱՆԻ ՓՈՓՈԽՈՒԹՅՈՒՆ',
    },

    // --- Карты погоды ---
    'weatherMaps': {
      'en': 'WEATHER MAPS',
      'ru': 'КАРТЫ ПОГОДЫ',
      'hy': 'ԵՂԱՆԱԿԻ ՔԱՐՏԵԶՆԵՐ',
    },
    'mapPrecipitation': {
      'en': 'Precipitation',
      'ru': 'Осадки',
      'hy': 'Տեղումներ',
    },
    'mapWind': {
      'en': 'Wind',
      'ru': 'Ветер',
      'hy': 'Քամի',
    },
    'mapStorms': {
      'en': 'Storms',
      'ru': 'Грозы',
      'hy': 'Ամպրոպներ',
    },
    'mapTemperature': {
      'en': 'Temperature',
      'ru': 'Температура',
      'hy': 'Ջերմաստիճան',
    },
    'mapStormsNote': {
      'en': 'Storm activity is shown as areas of high-intensity radar precipitation (no dedicated lightning layer in the free tier).',
      'ru': 'Грозовая активность показана как зоны осадков высокой интенсивности на радаре (отдельного слоя молний на бесплатном тарифе нет).',
      'hy': 'Ամպրոպային ակտիվությունը ցուցադրված է որպես բարձր ինտենսիվության տեղումների գոտիներ ռադարի վրա (անվճար սակագնի դեպքում կայծակի առանձին շերտ չկա)։',
    },
    'mapDataUnavailable': {
      'en': 'Map data is temporarily unavailable. Please check your connection and try again.',
      'ru': 'Данные карты временно недоступны. Проверьте соединение и попробуйте снова.',
      'hy': 'Քարտեզի տվյալները ժամանակավորապես անհասանելի են։ Ստուգեք կապը և փորձեք կրկին։',
    },
    'mapRetry': {
      'en': 'Retry',
      'ru': 'Повторить',
      'hy': 'Կրկին փորձել',
    },
    'openInBrowser': {
      'en': 'Open full map',
      'ru': 'Открыть полную карту',
      'hy': 'Բացել ամբողջական քարտեզը',
    },

    // --- Напоминание про зонт ---
    'umbrellaReminderTitle': {
      'en': 'Take an umbrella',
      'ru': 'Возьмите зонт',
      'hy': 'Վերցրեք հովանոց',
    },
    'umbrellaReminderBody': {
      'en': 'High chance of rain today — better take an umbrella with you.',
      'ru': 'Сегодня высокая вероятность дождя — лучше взять зонт с собой.',
      'hy': 'Այսօր անձրևի հավանականությունը մեծ է․ ավելի լավ է հովանոց վերցնել։',
    },

    // --- Индекс комфорта ---
    'comfortIndex': {
      'en': 'COMFORT INDEX',
      'ru': 'ИНДЕКС КОМФОРТА',
      'hy': 'ՀԱՐՄԱՐԱՎԵՏՈՒԹՅԱՆ ԻՆԴԵՔՍ',
    },
    'comfortExcellent': {
      'en': 'Excellent for a walk',
      'ru': 'Отлично для прогулки',
      'hy': 'Հիանալի է զբոսանքի համար',
    },
    'comfortGood': {
      'en': 'Good conditions outside',
      'ru': 'Хорошие условия на улице',
      'hy': 'Լավ պայմաններ դրսում',
    },
    'comfortModerate': {
      'en': 'Moderately comfortable',
      'ru': 'Умеренно комфортно',
      'hy': 'Չափավոր հարմարավետ',
    },
    'comfortPoor': {
      'en': 'Not very comfortable',
      'ru': 'Не очень комфортно',
      'hy': 'Այնքան էլ հարմարավետ չէ',
    },
    'comfortBad': {
      'en': 'Uncomfortable outside',
      'ru': 'Некомфортно на улице',
      'hy': 'Անհարմար է դրսում',
    },
    'comfortFactorTemp': {
      'en': 'Temperature',
      'ru': 'Температура',
      'hy': 'Ջերմաստիճան',
    },
    'comfortFactorHumidity': {
      'en': 'Humidity',
      'ru': 'Влажность',
      'hy': 'Խոնավություն',
    },
    'comfortFactorWind': {
      'en': 'Wind',
      'ru': 'Ветер',
      'hy': 'Քամի',
    },
    'comfortFactorUv': {
      'en': 'UV index',
      'ru': 'УФ-индекс',
      'hy': 'ՈՒՄ ինդեքս',
    },
    'comfortFactorRain': {
      'en': 'Rain chance',
      'ru': 'Вероятность дождя',
      'hy': 'Անձրևի հավանականություն',
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
  String get noCitiesFound => _t('noCitiesFound');
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

  // --- Фаза луны ---
  String get moonPhase => _t('moonPhase');
  String get moonNew => _t('moonNew');
  String get moonWaxingCrescent => _t('moonWaxingCrescent');
  String get moonFirstQuarter => _t('moonFirstQuarter');
  String get moonWaxingGibbous => _t('moonWaxingGibbous');
  String get moonFull => _t('moonFull');
  String get moonWaningGibbous => _t('moonWaningGibbous');
  String get moonLastQuarter => _t('moonLastQuarter');
  String get moonWaningCrescent => _t('moonWaningCrescent');
  String get moonIllumination => _t('moonIllumination');

  // --- Вероятность осадков ---
  String get precipitationChance => _t('precipitationChance');
  String get precipitationNow => _t('precipitationNow');

  // --- График температуры ---
  String get temperatureTrend => _t('temperatureTrend');

  // --- Карты погоды ---
  String get weatherMaps => _t('weatherMaps');
  String get mapPrecipitation => _t('mapPrecipitation');
  String get mapWind => _t('mapWind');
  String get mapStorms => _t('mapStorms');
  String get mapTemperature => _t('mapTemperature');
  String get mapDataUnavailable => _t('mapDataUnavailable');
  String get mapRetry => _t('mapRetry');
  String get mapStormsNote => _t('mapStormsNote');
  String get openInBrowser => _t('openInBrowser');

  // --- Напоминание про зонт ---
  String get umbrellaReminderTitle => _t('umbrellaReminderTitle');
  String get umbrellaReminderBody => _t('umbrellaReminderBody');

  // --- Индекс комфорта ---
  String get comfortIndex => _t('comfortIndex');
  String get comfortExcellent => _t('comfortExcellent');
  String get comfortGood => _t('comfortGood');
  String get comfortModerate => _t('comfortModerate');
  String get comfortPoor => _t('comfortPoor');
  String get comfortBad => _t('comfortBad');
  String get comfortFactorTemp => _t('comfortFactorTemp');
  String get comfortFactorHumidity => _t('comfortFactorHumidity');
  String get comfortFactorWind => _t('comfortFactorWind');
  String get comfortFactorUv => _t('comfortFactorUv');
  String get comfortFactorRain => _t('comfortFactorRain');

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
