import SwiftUI
import WidgetKit

/// Строит deep-link URL для открытия приложения на конкретном городе.
/// Схема совпадает с тем, что уже использует Android-версия
/// (WeatherWidgetProvider.kt.launchAppIntent): weather_app://widget?city_key=...
/// Обрабатывается на Dart-стороне через app_links в main.dart.
private func launchURL(cityKey: String?) -> URL {
    if let key = cityKey, let encoded = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
        return URL(string: "weather_app://widget?city_key=\(encoded)")!
    }
    return URL(string: "weather_app://widget")!
}

/// Пустое состояние — нет ни одного сохранённого города (свежая установка).
/// Портировано из weather_widget_empty.xml.
private struct EmptyWidgetView: View {
    var body: some View {
        Text(emptyMessage())
            .font(.system(size: 13))
            .foregroundColor(WidgetPalette.textDescription)
            .multilineTextAlignment(.center)
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyMessage() -> String {
        let language = Locale.preferredLanguages.first.flatMap { Locale(identifier: $0).language.languageCode?.identifier } ?? "en"
        switch language {
        case "ru": return "Откройте приложение, чтобы загрузить погоду"
        case "hy": return "Բացեք հավելվածը՝ եղանակը բեռնելու համար"
        default: return "Open the app to load weather"
        }
    }
}

/// Маленький виджет: иконка + температура + дата. Портирован из
/// weather_widget_small.xml. Весь виджет — одна тап-зона (как и на
/// Android, где для small нет переключателя городов).
struct SmallWeatherWidgetView: View {
    let entry: WeatherWidgetEntry

    var body: some View {
        if entry.cities.isEmpty {
            EmptyWidgetView()
        } else {
            let city = selectedCity(entry)
            HStack(spacing: 8) {
                WeatherWidgetIcon.view(for: city.iconCode)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatWidgetTemp(city.tempCelsius, useFahrenheit: entry.useFahrenheit))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(WidgetPalette.textPrimary)
                    Text(formatWidgetDate())
                        .font(.system(size: 11))
                        .foregroundColor(WidgetPalette.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .widgetURL(launchURL(cityKey: city.key))
        }
    }
}

/// Средний виджет: город, погода, описание + переключатель городов.
/// Портирован из weather_widget_medium.xml.
struct MediumWeatherWidgetView: View {
    let entry: WeatherWidgetEntry

    var body: some View {
        if entry.cities.isEmpty {
            EmptyWidgetView()
        } else {
            let city = selectedCity(entry)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(widgetCityDisplayName(city))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(WidgetPalette.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(formatWidgetDate())
                        .font(.system(size: 12))
                        .foregroundColor(WidgetPalette.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 10) {
                    WeatherWidgetIcon.view(for: city.iconCode)
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatWidgetTemp(city.tempCelsius, useFahrenheit: entry.useFahrenheit))
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(WidgetPalette.textPrimary)
                        Text(city.description)
                            .font(.system(size: 12))
                            .foregroundColor(WidgetPalette.textDescription)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .frame(maxHeight: .infinity)

                CitySwitcherRow(entry: entry)
            }
            .padding(14)
            .widgetURL(launchURL(cityKey: city.key))
        }
    }
}

/// Большой виджет: то же, что средний, плюс почасовой прогноз.
/// Портирован из weather_widget_large.xml.
struct LargeWeatherWidgetView: View {
    let entry: WeatherWidgetEntry

    var body: some View {
        if entry.cities.isEmpty {
            EmptyWidgetView()
        } else {
            let city = selectedCity(entry)
            let hourly = readHourly(for: city.key)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(widgetCityDisplayName(city))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(WidgetPalette.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(formatWidgetDate())
                        .font(.system(size: 12))
                        .foregroundColor(WidgetPalette.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 10) {
                    WeatherWidgetIcon.view(for: city.iconCode)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatWidgetTemp(city.tempCelsius, useFahrenheit: entry.useFahrenheit))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(WidgetPalette.textPrimary)
                        Text(city.description)
                            .font(.system(size: 12))
                            .foregroundColor(WidgetPalette.textDescription)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                if !hourly.isEmpty {
                    HourlyRow(points: hourly, useFahrenheit: entry.useFahrenheit)
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer()
                }

                CitySwitcherRow(entry: entry)
            }
            .padding(14)
            .widgetURL(launchURL(cityKey: city.key))
        }
    }
}

/// Строка переключателя городов — общая для medium/large. На iOS каждый
/// чипс — это `Link` с собственным URL (доступно для systemMedium/
/// systemLarge), поэтому тап по чипсу открывает приложение сразу на этом
/// городе. В отличие от Android, где чипс переключает город прямо в
/// виджете без открытия приложения — на iOS такое мгновенное
/// (без-сетевое) переключение потребовало бы App Intents с фоновым
/// запуском движка Flutter, что не входит в этот дизайн; открытие
/// приложения — стандартное и ожидаемое поведение для WidgetKit.
private struct CitySwitcherRow: View {
    let entry: WeatherWidgetEntry

    var body: some View {
        let keys = orderedCityKeys(entry.cities, limit: 4)
        HStack(spacing: 6) {
            ForEach(keys, id: \.self) { key in
                if let city = entry.cities[key] {
                    Link(destination: launchURL(cityKey: key)) {
                        CityChip(
                            label: chipLabel(for: city, useFahrenheit: entry.useFahrenheit),
                            isSelected: key == entry.selectedKey
                        )
                    }
                }
            }
        }
    }
}

/// Полоса почасового прогноза (только большой виджет) — портирована из
/// weather_widget_hour_item.xml, до 4 точек.
private struct HourlyRow: View {
    let points: [WidgetHourlyPoint]
    let useFahrenheit: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(points.prefix(4).enumerated()), id: \.offset) { _, point in
                VStack(spacing: 2) {
                    Text(point.time)
                        .font(.system(size: 10))
                        .foregroundColor(WidgetPalette.textSecondary)
                    WeatherWidgetIcon.view(for: point.iconCode)
                        .frame(width: 20, height: 20)
                    Text(point.tempCelsius.map { formatWidgetTemp($0, useFahrenheit: useFahrenheit) } ?? "—°")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(WidgetPalette.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Выбирает город для отображения: явно выбранный, иначе первый доступный.
private func selectedCity(_ entry: WeatherWidgetEntry) -> WidgetCityData {
    if let key = entry.selectedKey, let city = entry.cities[key] {
        return city
    }
    return entry.cities.values.first!
}
