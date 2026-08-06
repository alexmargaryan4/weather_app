import WidgetKit

/// Один "снимок" состояния виджета на конкретный момент времени.
struct WeatherWidgetEntry: TimelineEntry {
    let date: Date
    let cities: [String: WidgetCityData]
    let selectedKey: String?
    let useFahrenheit: Bool
}

/// Источник данных для WidgetKit. Данные читаются из App Group UserDefaults
/// при каждом запросе таймлайна — это тот же принцип, что и у Android-
/// провайдера (WeatherWidgetProvider.kt), который тоже читает
/// SharedPreferences заново при каждой перерисовке, без собственного кеша.
///
/// updatePeriodMillis на Android выставлен в 0 (обновление только по
/// запросу из Dart-кода через HomeWidget.updateWidget), поэтому здесь тоже
/// не строим длинный таймлайн наперёд — возвращаем одну запись с текущими
/// данными и просим систему перезапросить таймлайн через WidgetCenter
/// reloadTimelines, вызываемый Dart-стороной (см. WidgetService).
/// `.never()` политика освежения означает "жди явного reload", а не то,
/// что виджет не обновляется — если данные не меняются часами, потому что
/// пользователь не открывал приложение, это ожидаемо: как и на Android,
/// виджет не тянет сеть сам, а лишь показывает последний снимок.
struct WeatherWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherWidgetEntry {
        WeatherWidgetEntry(
            date: Date(),
            cities: [:],
            selectedKey: nil,
            useFahrenheit: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherWidgetEntry>) -> Void) {
        let entry = currentEntry()
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func currentEntry() -> WeatherWidgetEntry {
        let cities = readWidgetCities()
        let selectedKey = readSelectedCityKey() ?? cities.keys.first
        return WeatherWidgetEntry(
            date: Date(),
            cities: cities,
            selectedKey: selectedKey,
            useFahrenheit: readUseFahrenheit()
        )
    }
}
