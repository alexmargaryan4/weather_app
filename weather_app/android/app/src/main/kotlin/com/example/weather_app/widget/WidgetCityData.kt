package com.example.weather_app.widget

import org.json.JSONObject

/**
 * Данные по одному городу, как их сохраняет `WidgetService` (Flutter)
 * в виде JSON-объекта внутри общего JSON-словаря по ключу
 * [WidgetKeys.CITIES_JSON]. Формат должен один-в-один совпадать с
 * `_WidgetCityEntry.toJson()` в lib/services/widget_service.dart.
 */
data class WidgetCityData(
    val key: String,
    val displayName: String,
    val tempCelsius: Double,
    val iconCode: String,
    val description: String
) {
    companion object {
        fun fromJson(json: JSONObject): WidgetCityData = WidgetCityData(
            key = json.getString("key"),
            displayName = json.getString("displayName"),
            tempCelsius = json.getDouble("tempCelsius"),
            iconCode = json.getString("iconCode"),
            description = json.getString("description")
        )
    }
}

/**
 * Имена ключей SharedPreferences, под которыми `home_widget` хранит
 * данные, записанные Flutter-стороной. Должны точно совпадать со
 * строковыми константами в lib/services/widget_service.dart.
 */
object WidgetKeys {
    const val CITIES_JSON = "widget_cities_json"
    const val SELECTED_CITY = "widget_selected_city"
    const val USE_FAHRENHEIT = "widget_use_fahrenheit"

    // Специальное значение ключа для записи геолокации — должно совпадать
    // с WidgetService.geoKey во Flutter-коде.
    const val GEO_KEY = "__geo__"
}
