package com.example.weather_app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import com.example.weather_app.MainActivity
import com.example.weather_app.R
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import kotlin.math.roundToInt

/**
 * Главный провайдер домашних виджетов погоды.
 *
 * Один провайдер обслуживает сразу три размера (маленький / средний /
 * большой) — Android сам выбирает нужный layout в зависимости от того,
 * сколько места выделил лаунчер.
 *
 * Данные читаются из SharedPreferences, куда их кладёт [WidgetService]
 * (Dart-сторона) через плагин home_widget. Ключи совпадают с
 * константами в [WidgetKeys].
 *
 * Переключение города в виджете не требует запуска Flutter: нативная
 * сторона сама читает нужную запись из SharedPreferences и перерисовывает
 * виджет — это быстро и работает при отключённой сети.
 */
class WeatherWidgetProvider : AppWidgetProvider() {

    companion object {
        /** Intent-экшн, который бросают чипсы городов внутри виджета. */
        private const val ACTION_SELECT_CITY = "com.example.weather_app.ACTION_SELECT_CITY"

        /** Ключ extra для передачи выбранного ключа города в Intent'е чипса. */
        private const val EXTRA_CITY_KEY = "city_key"

        /** Максимум отображаемых чипсов городов (medium / large виджет). */
        private const val MAX_CHIPS = 4

        /** Максимум «часовых» столбиков в большом виджете. */
        private const val MAX_HOURLY = 4

        // ID чипсов в XML (соответствуют widget_chip_0..3 в layout'ах).
        private val CHIP_IDS = intArrayOf(
            R.id.widget_chip_0,
            R.id.widget_chip_1,
            R.id.widget_chip_2,
            R.id.widget_chip_3,
        )
    }

    // -------------------------------------------------------------------------
    // AppWidgetProvider callbacks
    // -------------------------------------------------------------------------

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_SELECT_CITY) {
            val cityKey = intent.getStringExtra(EXTRA_CITY_KEY) ?: return
            handleCitySelection(context, cityKey)
        }
    }

    // -------------------------------------------------------------------------
    // Основная логика обновления
    // -------------------------------------------------------------------------

    /**
     * Собирает RemoteViews и применяет их к одному конкретному виджету.
     */
    private fun updateWidget(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
    ) {
        val prefs = HomeWidgetPlugin.getData(context)

        // Читаем JSON со всеми городами.
        val citiesRaw = prefs.getString(WidgetKeys.CITIES_JSON, null)
        val cities = parseCities(citiesRaw)

        if (cities.isEmpty()) {
            // Данных ещё нет — показываем «пустой» экран с подсказкой.
            val emptyViews = RemoteViews(context.packageName, R.layout.weather_widget_empty)
            emptyViews.setOnClickPendingIntent(
                R.id.widget_root,
                launchAppIntent(context),
            )
            manager.updateAppWidget(widgetId, emptyViews)
            return
        }

        val selectedKey = prefs.getString(WidgetKeys.SELECTED_CITY, null)
            ?: cities.keys.firstOrNull()
            ?: return
        val useFahrenheit = prefs.getBoolean(WidgetKeys.USE_FAHRENHEIT, false)

        // Выбираем данные для отображения.
        val city = cities[selectedKey] ?: cities.values.first()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+: передаём несколько RemoteViews и система сама
            // подбирает лучший по размеру виджета.
            val viewMapping = mapOf(
                SizeF(110f, 40f) to buildSmallViews(context, city, useFahrenheit),
                SizeF(220f, 100f) to buildMediumViews(context, city, cities, selectedKey, useFahrenheit),
                SizeF(220f, 160f) to buildLargeViews(context, city, cities, selectedKey, useFahrenheit),
            )
            manager.updateAppWidget(widgetId, RemoteViews(viewMapping))
        } else {
            // До Android 12: один layout, выбираем по текущим размерам.
            val options = manager.getAppWidgetOptions(widgetId)
            val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            val views = chooseLayout(
                context, widthDp, heightDp, city, cities, selectedKey, useFahrenheit,
            )
            manager.updateAppWidget(widgetId, views)
        }
    }

    /**
     * Выбирает подходящий layout по размерам (для API < 31).
     */
    private fun chooseLayout(
        context: Context,
        widthDp: Int,
        heightDp: Int,
        city: WidgetCityData,
        cities: Map<String, WidgetCityData>,
        selectedKey: String,
        useFahrenheit: Boolean,
    ): RemoteViews {
        return when {
            heightDp >= 160 -> buildLargeViews(context, city, cities, selectedKey, useFahrenheit)
            widthDp >= 200 && heightDp >= 100 -> buildMediumViews(context, city, cities, selectedKey, useFahrenheit)
            else -> buildSmallViews(context, city, useFahrenheit)
        }
    }

    // -------------------------------------------------------------------------
    // Построение RemoteViews для каждого размера
    // -------------------------------------------------------------------------

    /** Маленький виджет (~2×1): иконка + температура + дата. */
    private fun buildSmallViews(
        context: Context,
        city: WidgetCityData,
        useFahrenheit: Boolean,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.weather_widget_small)

        views.setImageViewResource(R.id.widget_icon, WidgetIconMapper.iconFor(city.iconCode))
        views.setTextViewText(R.id.widget_temp, formatTemp(city.tempCelsius, useFahrenheit))
        views.setTextViewText(R.id.widget_date, WidgetDateFormatter.formatToday(context))

        // Тап по виджету — открыть приложение на текущем городе.
        views.setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context, city.key))

        return views
    }

    /** Средний виджет (~4×2): город, погода, описание + переключатель городов. */
    private fun buildMediumViews(
        context: Context,
        city: WidgetCityData,
        cities: Map<String, WidgetCityData>,
        selectedKey: String,
        useFahrenheit: Boolean,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.weather_widget_medium)

        views.setTextViewText(R.id.widget_city_name, cityDisplayName(context, city))
        views.setTextViewText(R.id.widget_date, WidgetDateFormatter.formatToday(context))
        views.setImageViewResource(R.id.widget_icon, WidgetIconMapper.iconFor(city.iconCode))
        views.setTextViewText(R.id.widget_temp, formatTemp(city.tempCelsius, useFahrenheit))
        views.setTextViewText(R.id.widget_description, city.description)

        views.setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context, city.key))

        fillCityChips(context, views, cities, selectedKey, useFahrenheit)

        return views
    }

    /**
     * Большой виджет (~4×3+): то же, что средний, плюс почасовой прогноз.
     *
     * Примечание: home_widget не передаёт часовой прогноз в SharedPreferences
     * по умолчанию — для этого нужно расширить [WidgetService] (Dart) и здесь
     * добавить чтение. Пока что, если данных нет, строка прогноза скрывается.
     */
    private fun buildLargeViews(
        context: Context,
        city: WidgetCityData,
        cities: Map<String, WidgetCityData>,
        selectedKey: String,
        useFahrenheit: Boolean,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.weather_widget_large)

        views.setTextViewText(R.id.widget_city_name, cityDisplayName(context, city))
        views.setTextViewText(R.id.widget_date, WidgetDateFormatter.formatToday(context))
        views.setImageViewResource(R.id.widget_icon, WidgetIconMapper.iconFor(city.iconCode))
        views.setTextViewText(R.id.widget_temp, formatTemp(city.tempCelsius, useFahrenheit))
        views.setTextViewText(R.id.widget_description, city.description)

        views.setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context, city.key))

        fillCityChips(context, views, cities, selectedKey, useFahrenheit)
        fillHourlyRow(context, views, city, useFahrenheit)

        return views
    }

    // -------------------------------------------------------------------------
    // Переключатель городов (чипсы)
    // -------------------------------------------------------------------------

    /**
     * Заполняет строку чипсов городов.
     * Первым всегда идёт геолокация (если есть запись с ключом [WidgetKeys.GEO_KEY]),
     * затем остальные города — в порядке появления в [cities].
     */
    private fun fillCityChips(
        context: Context,
        views: RemoteViews,
        cities: Map<String, WidgetCityData>,
        selectedKey: String,
        useFahrenheit: Boolean,
    ) {
        // Сортируем: геолокация первой, затем остальные.
        val orderedKeys = cities.keys
            .sortedWith(compareBy { if (it == WidgetKeys.GEO_KEY) 0 else 1 })
            .take(MAX_CHIPS)

        for (i in 0 until MAX_CHIPS) {
            val chipId = CHIP_IDS[i]
            if (i >= orderedKeys.size) {
                // Лишние чипсы скрываем.
                views.setViewVisibility(chipId, View.GONE)
                continue
            }

            val key = orderedKeys[i]
            val cityData = cities[key] ?: continue
            val isSelected = key == selectedKey

            views.setViewVisibility(chipId, View.VISIBLE)

            // Текст чипса: короткое имя + температура.
            val label = buildChipLabel(context, cityData, useFahrenheit)
            views.setTextViewText(chipId, label)

            // Фон: выбранный — акцентный (жёлтый), остальные — полупрозрачные.
            views.setInt(
                chipId, "setBackgroundResource",
                if (isSelected) R.drawable.widget_chip_selected_background
                else R.drawable.widget_chip_background,
            )
            // Цвет текста: выбранный — тёмный (чтобы читался на жёлтом), остальные — белый.
            views.setInt(
                chipId, "setTextColor",
                if (isSelected)
                    context.getColor(android.R.color.black)
                else
                    0xFFFFFFFF.toInt(),
            )

            // Клик по чипсу — переключить город без открытия приложения.
            views.setOnClickPendingIntent(chipId, selectCityIntent(context, key))
        }
    }

    /**
     * Строит подпись чипса. Для геолокации — «📍 ...°», для городов — «Мск ...°».
     */
    private fun buildChipLabel(
        context: Context,
        city: WidgetCityData,
        useFahrenheit: Boolean,
    ): String {
        val temp = formatTemp(city.tempCelsius, useFahrenheit)
        val name = if (city.key == WidgetKeys.GEO_KEY) {
            // Иконка-метка вместо названия, чтобы сэкономить место.
            "📍"
        } else {
            // Первые ~4 символа названия — достаточно, чтобы отличить города,
            // и помещается в узкий чипс.
            city.displayName.take(4).trimEnd()
        }
        return "$name $temp"
    }

    // -------------------------------------------------------------------------
    // Почасовой прогноз (большой виджет)
    // -------------------------------------------------------------------------

    /**
     * Заполняет строку с почасовым прогнозом в большом виджете.
     *
     * Данные берутся из SharedPreferences по ключу «widget_hourly_<cityKey>»
     * (JSON-массив объектов {time, iconCode, tempCelsius}).
     * Если данных нет — строка скрывается.
     *
     * Чтобы это заработало, в WidgetService.dart нужно добавить сохранение
     * почасового прогноза (пример в комментарии ниже класса).
     */
    private fun fillHourlyRow(
        context: Context,
        views: RemoteViews,
        city: WidgetCityData,
        useFahrenheit: Boolean,
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val hourlyRaw = prefs.getString("widget_hourly_${city.key}", null)

        if (hourlyRaw.isNullOrEmpty()) {
            views.setViewVisibility(R.id.widget_hourly_row, View.GONE)
            return
        }

        try {
            val arr = org.json.JSONArray(hourlyRaw)
            views.setViewVisibility(R.id.widget_hourly_row, View.VISIBLE)
            // Сначала очищаем строку от предыдущего содержимого.
            views.removeAllViews(R.id.widget_hourly_row)

            val count = minOf(arr.length(), MAX_HOURLY)
            for (i in 0 until count) {
                val item = arr.getJSONObject(i)
                val time = item.optString("time", "—")
                val iconCode = item.optString("iconCode", "")
                val tempC = item.optDouble("tempCelsius", Double.NaN)

                val itemViews = RemoteViews(context.packageName, R.layout.weather_widget_hour_item)
                itemViews.setTextViewText(R.id.hour_item_time, time)
                itemViews.setImageViewResource(R.id.hour_item_icon, WidgetIconMapper.iconFor(iconCode))
                itemViews.setTextViewText(
                    R.id.hour_item_temp,
                    if (tempC.isNaN()) "—°" else formatTemp(tempC, useFahrenheit),
                )
                views.addView(R.id.widget_hourly_row, itemViews)
            }
        } catch (_: Exception) {
            // Битые данные — скрываем блок, не ломаем весь виджет.
            views.setViewVisibility(R.id.widget_hourly_row, View.GONE)
        }
    }

    // -------------------------------------------------------------------------
    // Обработка выбора города
    // -------------------------------------------------------------------------

    /**
     * Вызывается при тапе на чипс города. Обновляет SharedPreferences и
     * перерисовывает все виджеты — без запуска Flutter-движка.
     */
    private fun handleCitySelection(context: Context, cityKey: String) {
        val prefs = HomeWidgetPlugin.getData(context)
        prefs.edit()
            .putString(WidgetKeys.SELECTED_CITY, cityKey)
            .apply()

        // Перерисовываем все размещённые виджеты этого приложения.
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, WeatherWidgetProvider::class.java),
        )
        onUpdate(context, manager, ids)
    }

    // -------------------------------------------------------------------------
    // PendingIntent'ы
    // -------------------------------------------------------------------------

    /**
     * PendingIntent для запуска MainActivity с выбранным городом.
     * [cityKey] передаётся в URI через параметр query, чтобы home_widget
     * мог прочитать его через [HomeWidget.initiallyLaunchedFromHomeWidget].
     */
    private fun launchAppIntent(context: Context, cityKey: String? = null): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = "es.antonborri.home_widget.action.LAUNCH"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (cityKey != null) {
                data = android.net.Uri.parse(
                    "weather_app://widget?city_key=${android.net.Uri.encode(cityKey)}"
                )
            }
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getActivity(context, cityKey.hashCode(), intent, flags)
    }

    /**
     * PendingIntent для смены выбранного города прямо в виджете (без открытия
     * приложения). Отправляет broadcast в этот же провайдер.
     */
    private fun selectCityIntent(context: Context, cityKey: String): PendingIntent {
        val intent = Intent(context, WeatherWidgetProvider::class.java).apply {
            action = ACTION_SELECT_CITY
            putExtra(EXTRA_CITY_KEY, cityKey)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getBroadcast(context, cityKey.hashCode(), intent, flags)
    }

    // -------------------------------------------------------------------------
    // Вспомогательные функции
    // -------------------------------------------------------------------------

    /**
     * Читает и разбирает JSON со всеми сохранёнными городами.
     * Возвращает пустую Map, если данных нет или JSON повреждён.
     */
    private fun parseCities(raw: String?): Map<String, WidgetCityData> {
        if (raw.isNullOrEmpty()) return emptyMap()
        return try {
            val json = JSONObject(raw)
            buildMap {
                for (key in json.keys()) {
                    put(key, WidgetCityData.fromJson(json.getJSONObject(key)))
                }
            }
        } catch (_: Exception) {
            emptyMap()
        }
    }

    /**
     * Форматирует температуру в градусах с символом единицы измерения.
     */
    private fun formatTemp(tempC: Double, useFahrenheit: Boolean): String {
        return if (useFahrenheit) {
            val f = (tempC * 9.0 / 5.0 + 32).roundToInt()
            "$f°F"
        } else {
            val c = tempC.roundToInt()
            "$c°C"
        }
    }

    /**
     * Возвращает отображаемое название города. Для геолокации берёт
     * строку из ресурсов ("Текущее местоположение" / "Current location" / ...).
     */
    private fun cityDisplayName(context: Context, city: WidgetCityData): String {
        return if (city.key == WidgetKeys.GEO_KEY) {
            context.getString(R.string.widget_current_location)
        } else {
            city.displayName
        }
    }
}

/*
 * ═══════════════════════════════════════════════════════════════════════════
 *  КАК ДОБАВИТЬ ПОЧАСОВОЙ ПРОГНОЗ
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * 1. В lib/services/widget_service.dart добавить метод:
 *
 *    Future<void> updateHourly({
 *      required String key,
 *      required List<HourlyPoint> points,   // свой тип с полями time/icon/tempC
 *    }) async {
 *      final arr = points.take(4).map((p) => {
 *        'time': p.timeLabel,               // строка: "14:00"
 *        'iconCode': p.iconCode,            // "01d", "10n", ...
 *        'tempCelsius': p.tempCelsius,
 *      }).toList();
 *      await HomeWidget.saveWidgetData<String>(
 *        'widget_hourly_$key',
 *        jsonEncode(arr),
 *      );
 *    }
 *
 * 2. Вызывать updateHourly(...) рядом с updateCity(...) при загрузке погоды
 *    (например, в HomeScreen._loadWeatherByCity / _loadWeatherByLocation).
 *
 * Без этого шага строка прогноза в большом виджете остаётся скрытой,
 * всё остальное работает штатно.
 * ═══════════════════════════════════════════════════════════════════════════
 */
