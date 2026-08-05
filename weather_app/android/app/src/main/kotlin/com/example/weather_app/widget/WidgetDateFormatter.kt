package com.example.weather_app.widget

import android.content.Context
import com.example.weather_app.R
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Форматирует сегодняшнюю дату для виджета: "четверг, 5 августа" (ru),
 * "Thursday, August 5" (en) и т.д. Считается нативно по системной дате
 * устройства и локали устройства — не зависит от того, был ли открыт
 * Flutter-движок, поэтому дата остаётся верной, даже если у виджета
 * давно не было свежих данных о погоде.
 *
 * Поддерживаются только те языки, что и во всём приложении (en/ru/hy —
 * см. lib/localization/app_localizations.dart); для остальных языков
 * системы используется английский формат, т.к. остальные строки
 * виджета (widget_no_data и т.д.) тоже переведены только на эти три.
 */
object WidgetDateFormatter {
    fun formatToday(context: Context): String {
        val locale = currentSupportedLocale(context)
        val calendar = Calendar.getInstance()

        val dayOfWeek = SimpleDateFormat("EEEE", locale).format(calendar.time)
        val datePattern = if (locale.language == "en") "MMMM d" else "d MMMM"
        val date = SimpleDateFormat(datePattern, locale).format(calendar.time)

        val dayCapitalized = dayOfWeek.replaceFirstChar {
            if (it.isLowerCase()) it.titlecase(locale) else it.toString()
        }

        return context.getString(R.string.widget_date_format, dayCapitalized, date)
    }

    private fun currentSupportedLocale(context: Context): Locale {
        val deviceLanguage = context.resources.configuration.locales[0].language
        return when (deviceLanguage) {
            "ru" -> Locale("ru")
            "hy" -> Locale("hy")
            else -> Locale.ENGLISH
        }
    }
}
