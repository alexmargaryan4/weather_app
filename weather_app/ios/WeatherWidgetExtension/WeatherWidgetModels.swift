import Foundation

/// Данные по одному городу, как их сохраняет `WidgetService` (Flutter) через
/// плагин `home_widget` в App Group UserDefaults, в виде JSON-объекта внутри
/// общего JSON-словаря по ключу `WidgetKeys.citiesJson`.
///
/// Формат должен один-в-один совпадать с `_WidgetCityEntry.toJson()` в
/// lib/services/widget_service.dart — это тот же контракт, что уже
/// используется на Android-стороне в WidgetCityData.kt.
struct WidgetCityData: Decodable {
    let key: String
    let displayName: String
    let tempCelsius: Double
    let iconCode: String
    let description: String
}

/// Одна точка почасового прогноза (используется в большом виджете).
/// Формат совпадает с тем, что сохраняет WidgetService.updateHourly (Dart)
/// и что уже читает WeatherWidgetProvider.kt на Android под ключом
/// "widget_hourly_<cityKey>".
struct WidgetHourlyPoint: Decodable {
    let time: String
    let iconCode: String
    let tempCelsius: Double?

    enum CodingKeys: String, CodingKey {
        case time, iconCode, tempCelsius
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        time = try container.decodeIfPresent(String.self, forKey: .time) ?? "—"
        iconCode = try container.decodeIfPresent(String.self, forKey: .iconCode) ?? ""
        tempCelsius = try container.decodeIfPresent(Double.self, forKey: .tempCelsius)
    }
}

/// Имена ключей App Group UserDefaults, под которыми `home_widget` хранит
/// данные, записанные Flutter-стороной. Должны точно совпадать со
/// строковыми константами в lib/services/widget_service.dart (тот же
/// контракт, что и WidgetKeys в WidgetCityData.kt на Android).
enum WidgetKeys {
    static let citiesJson = "widget_cities_json"
    static let selectedCity = "widget_selected_city"
    static let useFahrenheit = "widget_use_fahrenheit"

    /// Специальное значение ключа для записи геолокации — должно совпадать
    /// с WidgetService.geoKey во Flutter-коде.
    static let geoKey = "__geo__"

    /// Префикс ключа почасового прогноза; полный ключ — "widget_hourly_<cityKey>".
    static let hourlyPrefix = "widget_hourly_"
}

/// App Group, через который Runner и это расширение обмениваются данными.
/// Должен совпадать с group ID, прописанным в entitlements обоих таргетов
/// и с тем, что передаётся в `HomeWidget.setAppGroupId(...)` в main.dart.
let widgetAppGroupId = "group.com.example.weatherApp"

/// Читает и разбирает данные всех городов из общего хранилища.
/// Возвращает пустой словарь, если данных ещё нет или JSON повреждён —
/// расширение никогда не должно падать из-за плохих/отсутствующих данных.
func readWidgetCities() -> [String: WidgetCityData] {
    guard let defaults = UserDefaults(suiteName: widgetAppGroupId),
          let raw = defaults.string(forKey: WidgetKeys.citiesJson),
          let data = raw.data(using: .utf8)
    else {
        return [:]
    }
    guard let decoded = try? JSONDecoder().decode([String: WidgetCityData].self, from: data) else {
        return [:]
    }
    return decoded
}

/// Читает выбранный в виджете город (или геолокацию).
func readSelectedCityKey() -> String? {
    UserDefaults(suiteName: widgetAppGroupId)?.string(forKey: WidgetKeys.selectedCity)
}

/// Читает настройку единиц измерения температуры (°F, если true).
func readUseFahrenheit() -> Bool {
    UserDefaults(suiteName: widgetAppGroupId)?.bool(forKey: WidgetKeys.useFahrenheit) ?? false
}

/// Читает почасовой прогноз для конкретного города (до 4 точек).
/// Возвращает пустой массив, если данных нет — вызывающая сторона должна
/// скрыть соответствующий блок, как это делает Android-версия.
func readHourly(for cityKey: String) -> [WidgetHourlyPoint] {
    guard let defaults = UserDefaults(suiteName: widgetAppGroupId),
          let raw = defaults.string(forKey: WidgetKeys.hourlyPrefix + cityKey),
          let data = raw.data(using: .utf8)
    else {
        return []
    }
    return (try? JSONDecoder().decode([WidgetHourlyPoint].self, from: data)) ?? []
}

/// Форматирует температуру в градусах с символом единицы измерения.
/// Логика идентична WeatherWidgetProvider.formatTemp на Android.
func formatWidgetTemp(_ tempCelsius: Double, useFahrenheit: Bool) -> String {
    if useFahrenheit {
        let f = Int((tempCelsius * 9.0 / 5.0 + 32).rounded())
        return "\(f)°F"
    } else {
        let c = Int(tempCelsius.rounded())
        return "\(c)°C"
    }
}

/// Возвращает отображаемое название города. Для геолокации использует
/// локализованную строку "Текущее местоположение" / "Current location" /
/// "Ընթացիկ գտնվելու վայրը" — та же логика, что и cityDisplayName на Android,
/// но со строками, локализованными по языку устройства (en/ru/hy),
/// поскольку у Widget Extension нет доступа к строковым ресурсам приложения.
func widgetCityDisplayName(_ city: WidgetCityData) -> String {
    if city.key == WidgetKeys.geoKey {
        return currentLocationLabel()
    }
    return city.displayName
}

private func currentLocationLabel() -> String {
    let language = Locale.preferredLanguages.first.flatMap { Locale(identifier: $0).language.languageCode?.identifier } ?? "en"
    switch language {
    case "ru": return "Текущее местоположение"
    case "hy": return "Ընթացիկ գտնվելու վայրը"
    default: return "Current location"
    }
}

/// Форматирует сегодняшнюю дату для виджета: "четверг, 5 августа" (ru),
/// "Thursday, August 5" (en) и т.д. — портированная логика
/// WidgetDateFormatter.kt (Android). Считается по системной дате и языку
/// устройства, не зависит от того, когда в последний раз обновлялись
/// данные о погоде.
func formatWidgetDate(_ date: Date = Date()) -> String {
    let language = Locale.preferredLanguages.first.flatMap { Locale(identifier: $0).language.languageCode?.identifier } ?? "en"
    let supported = ["ru", "hy", "en"].contains(language) ? language : "en"
    let locale = Locale(identifier: supported)

    let dayFormatter = DateFormatter()
    dayFormatter.locale = locale
    dayFormatter.dateFormat = "EEEE"
    let day = dayFormatter.string(from: date).prefix(1).uppercased() + dayFormatter.string(from: date).dropFirst()

    let dateFormatter = DateFormatter()
    dateFormatter.locale = locale
    dateFormatter.dateFormat = supported == "en" ? "MMMM d" : "d MMMM"
    let dateString = dateFormatter.string(from: date)

    return "\(day), \(dateString)"
}
