class WeatherData {
  final String cityName;
  // Код страны ISO 3166 (например, "RU", "AM"), приходит от OpenWeatherMap
  // в поле sys.country. Может быть null, если API его не вернул.
  final String? countryCode;
  final double lat;
  final double lon;
  final double temp;
  final double feelsLike;
  final String description;
  final String iconCode;
  final double windSpeed;
  final int humidity;
  final int pressure;
  final int? visibility;
  final DateTime sunrise;
  final DateTime sunset;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;
  // Индекс качества воздуха (1 = отлично ... 5 = очень плохо), null пока не загружен
  final int? airQualityIndex;

  WeatherData({
    required this.cityName,
    this.countryCode,
    required this.lat,
    required this.lon,
    required this.temp,
    required this.feelsLike,
    required this.description,
    required this.iconCode,
    required this.windSpeed,
    required this.humidity,
    required this.pressure,
    required this.visibility,
    required this.sunrise,
    required this.sunset,
    required this.hourly,
    required this.daily,
    this.airQualityIndex,
  });

  // Возвращает копию с обновлённым индексом качества воздуха
  WeatherData copyWithAirQuality(int? aqi) {
    return WeatherData(
      cityName: cityName,
      countryCode: countryCode,
      lat: lat,
      lon: lon,
      temp: temp,
      feelsLike: feelsLike,
      description: description,
      iconCode: iconCode,
      windSpeed: windSpeed,
      humidity: humidity,
      pressure: pressure,
      visibility: visibility,
      sunrise: sunrise,
      sunset: sunset,
      hourly: hourly,
      daily: daily,
      airQualityIndex: aqi,
    );
  }

  // Возвращает копию с обновлённой видимостью (используется, когда видимость
  // приходит отдельным запросом от другого источника — см. WeatherService).
  WeatherData copyWithVisibility(int? newVisibility) {
    return WeatherData(
      cityName: cityName,
      countryCode: countryCode,
      lat: lat,
      lon: lon,
      temp: temp,
      feelsLike: feelsLike,
      description: description,
      iconCode: iconCode,
      windSpeed: windSpeed,
      humidity: humidity,
      pressure: pressure,
      visibility: newVisibility,
      sunrise: sunrise,
      sunset: sunset,
      hourly: hourly,
      daily: daily,
      airQualityIndex: airQualityIndex,
    );
  }

  factory WeatherData.fromJson(
    Map<String, dynamic> currentJson,
    Map<String, dynamic> forecastJson,
  ) {
    // Список всех точек прогноза (каждые 3 часа, на 5 дней = 40 точек)
    final List<dynamic> list = forecastJson['list'];

    // Почасовой блок - берём первые 8 точек (24 часа = 8 * 3ч)
    List<HourlyForecast> hourlyList =
        list.take(8).map((h) => HourlyForecast.fromJson(h)).toList();

    // Дневной блок - группируем по дате, берём мин/макс за день
    Map<String, List<dynamic>> groupedByDay = {};
    for (var item in list) {
      final date = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
      final dayKey = '${date.year}-${date.month}-${date.day}';
      groupedByDay.putIfAbsent(dayKey, () => []).add(item);
    }

    List<DailyForecast> dailyList = groupedByDay.entries.map((entry) {
      final items = entry.value;
      double maxTemp = items
          .map((e) => (e['main']['temp_max'] as num).toDouble())
          .reduce((a, b) => a > b ? a : b);
      double minTemp = items
          .map((e) => (e['main']['temp_min'] as num).toDouble())
          .reduce((a, b) => a < b ? a : b);

      // Берём иконку и описание из точки, ближайшей к полудню
      final midDayItem = items.reduce((a, b) {
        final aHour = DateTime.fromMillisecondsSinceEpoch(a['dt'] * 1000).hour;
        final bHour = DateTime.fromMillisecondsSinceEpoch(b['dt'] * 1000).hour;
        return (aHour - 12).abs() < (bHour - 12).abs() ? a : b;
      });

      return DailyForecast(
        date: DateTime.fromMillisecondsSinceEpoch(items.first['dt'] * 1000),
        tempMax: maxTemp,
        tempMin: minTemp,
        iconCode: midDayItem['weather'][0]['icon'],
        description: midDayItem['weather'][0]['description'],
      );
    }).take(5).toList();

    return WeatherData(
      cityName: currentJson['name'],
      countryCode: currentJson['sys']?['country'] as String?,
      lat: (currentJson['coord']['lat'] as num).toDouble(),
      lon: (currentJson['coord']['lon'] as num).toDouble(),
      temp: (currentJson['main']['temp'] as num).toDouble(),
      feelsLike: (currentJson['main']['feels_like'] as num).toDouble(),
      description: currentJson['weather'][0]['description'],
      iconCode: currentJson['weather'][0]['icon'],
      windSpeed: (currentJson['wind']['speed'] as num).toDouble(),
      humidity: currentJson['main']['humidity'],
      pressure: currentJson['main']['pressure'] ?? 1013,
      visibility: (currentJson['visibility'] as num?)?.toInt(),
      sunrise: DateTime.fromMillisecondsSinceEpoch(
          ((currentJson['sys']?['sunrise'] ?? 0) as int) * 1000),
      sunset: DateTime.fromMillisecondsSinceEpoch(
          ((currentJson['sys']?['sunset'] ?? 0) as int) * 1000),
      hourly: hourlyList,
      daily: dailyList,
    );
  }
}

class HourlyForecast {
  final DateTime time;
  final double temp;
  final String iconCode;

  HourlyForecast({
    required this.time,
    required this.temp,
    required this.iconCode,
  });

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    return HourlyForecast(
      time: DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000),
      temp: (json['main']['temp'] as num).toDouble(),
      iconCode: json['weather'][0]['icon'],
    );
  }
}

class DailyForecast {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final String iconCode;
  final String description;

  DailyForecast({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.iconCode,
    required this.description,
  });
}