package com.example.weather_app.widget

import com.example.weather_app.R

/**
 * Переводит код иконки погоды от OpenWeatherMap (например "01d", "10n")
 * в нативный drawable-ресурс виджета. Логика соответствует
 * lib/widgets/weather_icon.dart на Flutter-стороне (тот же набор групп
 * кодов), но там иконки — это Material Icons, а тут — свои vector
 * drawable, потому что RemoteViews не умеют рендерить шрифт иконок.
 */
object WidgetIconMapper {
    fun iconFor(iconCode: String): Int {
        if (iconCode.isEmpty()) return R.drawable.ic_widget_clear_day
        val isNight = iconCode.endsWith("n")
        val code = iconCode.take(2)
        return when (code) {
            "01" -> if (isNight) R.drawable.ic_widget_clear_night else R.drawable.ic_widget_clear_day
            "02" -> if (isNight) R.drawable.ic_widget_partly_cloudy_night else R.drawable.ic_widget_partly_cloudy_day
            "03", "04" -> R.drawable.ic_widget_cloudy
            "09", "10" -> R.drawable.ic_widget_rain
            "11" -> R.drawable.ic_widget_thunderstorm
            "13" -> R.drawable.ic_widget_snow
            "50" -> R.drawable.ic_widget_fog
            else -> R.drawable.ic_widget_clear_day
        }
    }
}
