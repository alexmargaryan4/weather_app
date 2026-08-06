import SwiftUI

/// Единая цветовая палитра виджета — портирована из
/// android/.../res/drawable/widget_background.xml и widget_chip_*.xml,
/// а также цветов текста, захардкоженных прямо в weather_widget_*.xml,
/// чтобы дизайн на iOS выглядел так же, как на Android.
enum WidgetPalette {
    /// Начало градиента фона — #1B3B7A.
    static let backgroundStart = Color(red: 0x1B / 255, green: 0x3B / 255, blue: 0x7A / 255)
    /// Конец градиента фона — #0F1C3F.
    static let backgroundEnd = Color(red: 0x0F / 255, green: 0x1C / 255, blue: 0x3F / 255)

    /// Основной текст (температура, город) — белый.
    static let textPrimary = Color.white
    /// Вторичный текст (дата) — #B8C4E0.
    static let textSecondary = Color(red: 0xB8 / 255, green: 0xC4 / 255, blue: 0xE0 / 255)
    /// Текст описания погоды — #D3DBEF.
    static let textDescription = Color(red: 0xD3 / 255, green: 0xDB / 255, blue: 0xEF / 255)

    /// Акцентный жёлтый для выбранного чипса — #FFC94A.
    static let accent = Color(red: 0xFF / 255, green: 0xC9 / 255, blue: 0x4A / 255)
    /// Фон невыбранного чипса — полупрозрачный белый (#26FFFFFF ~ 15% альфа).
    static let chipBackground = Color.white.opacity(0.15)
    /// Текст выбранного чипса — тёмный, чтобы читался на жёлтом фоне.
    static let chipSelectedText = Color.black
}

/// Фон-градиент виджета: диагональный (135°), тёмно-синий,
/// со скруглением углов 24pt — то же самое, что widget_background.xml.
struct WidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [WidgetPalette.backgroundStart, WidgetPalette.backgroundEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Один чипс переключателя городов — портирован из style
/// "WidgetCityChip" + widget_chip_background/widget_chip_selected_background.
/// На iOS 17+ виджеты не поддерживают собственные тап-обработчики на
/// произвольных подэлементах без App Intents (в отличие от Android
/// RemoteViews, где у каждого чипса свой PendingIntent) — поэтому здесь
/// чипс только визуальный индикатор выбранного города, а не кнопка.
/// Тап по всему виджету открывает приложение (см. WidgetURL в каждом View).
struct CityChip: View {
    let label: String
    let isSelected: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(isSelected ? WidgetPalette.chipSelectedText : WidgetPalette.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? WidgetPalette.accent : WidgetPalette.chipBackground)
            )
    }
}

/// Строит подпись чипса: "📍 12°" для геолокации, "Мск 12°" для города —
/// та же логика, что buildChipLabel в WeatherWidgetProvider.kt.
func chipLabel(for city: WidgetCityData, useFahrenheit: Bool) -> String {
    let temp = formatWidgetTemp(city.tempCelsius, useFahrenheit: useFahrenheit)
    let name: String
    if city.key == WidgetKeys.geoKey {
        name = "📍"
    } else {
        name = String(city.displayName.prefix(4)).trimmingCharacters(in: .whitespaces)
    }
    return "\(name) \(temp)"
}

/// Строит упорядоченный список городов для чипсов: геолокация первой,
/// затем остальные — та же сортировка, что и fillCityChips на Android.
func orderedCityKeys(_ cities: [String: WidgetCityData], limit: Int) -> [String] {
    let keys = cities.keys.sorted { a, b in
        let aIsGeo = a == WidgetKeys.geoKey
        let bIsGeo = b == WidgetKeys.geoKey
        if aIsGeo != bIsGeo { return aIsGeo }
        return a < b
    }
    return Array(keys.prefix(limit))
}
