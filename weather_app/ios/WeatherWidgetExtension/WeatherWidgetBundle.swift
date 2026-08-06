import SwiftUI
import WidgetKit

/// Точка входа виджета. `kind` должен совпадать со значением `iOSName`,
/// которое передаётся в `HomeWidget.updateWidget(iOSName: "WeatherWidget")`
/// на Dart-стороне (lib/services/widget_service.dart) — иначе запрос на
/// перерисовку от Flutter не найдёт этот виджет.
struct WeatherWidget: Widget {
    let kind: String = "WeatherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherWidgetProvider()) { entry in
            WeatherWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName(widgetDisplayName())
        .description(widgetDescription())
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Выбирает View по текущему размеру семейства — аналог того, как Android
/// сам подбирает layout по SizeF/ширине-высоте (см. chooseLayout в
/// WeatherWidgetProvider.kt), только здесь выбор идёт по WidgetFamily,
/// который WidgetKit определяет сам.
private struct WeatherWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WeatherWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWeatherWidgetView(entry: entry)
        case .systemLarge:
            LargeWeatherWidgetView(entry: entry)
        default:
            MediumWeatherWidgetView(entry: entry)
        }
    }
}

private func widgetDisplayName() -> String {
    let language = Locale.preferredLanguages.first.flatMap { Locale(identifier: $0).language.languageCode?.identifier } ?? "en"
    switch language {
    case "ru": return "Погода+"
    case "hy": return "Եղանակ+"
    default: return "Weather+"
    }
}

private func widgetDescription() -> String {
    let language = Locale.preferredLanguages.first.flatMap { Locale(identifier: $0).language.languageCode?.identifier } ?? "en"
    switch language {
    case "ru": return "Текущая погода и краткий прогноз для избранных городов."
    case "hy": return "Ընթացիկ եղանակը և կարճ կանխատեսումը ընտրյալ քաղաքների համար։"
    default: return "Current weather and a short forecast for your favorite cities."
    }
}

@main
struct WeatherWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeatherWidget()
    }
}
