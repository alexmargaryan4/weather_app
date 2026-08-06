/// Идентификаторы всех карточек-виджетов, которые можно расположить на
/// главном экране. Порядок объявления здесь не имеет значения — реальный
/// порядок и видимость хранятся в [CardLayoutService] (shared_preferences)
/// и передаются в [HomeScreen] отдельным списком.
///
/// Значения сериализуются в SharedPreferences по имени (DashboardCard.name),
/// поэтому переименовывать существующие константы нельзя — только
/// добавлять новые в конец. Если константу всё же нужно убрать, добавьте её
/// имя в CardLayoutService._legacyKeys, чтобы миграция не падала на старых
/// сохранённых списках.
enum DashboardCard {
  umbrellaReminder,
  hourlyForecast,
  temperatureChart,
  precipitation,
  dailyForecast,
  sunArc,
  moonPhase,
  comfortIndex,
  airQuality,
  weatherMaps,
  details, // сетка 2x2: ветер, влажность, давление, видимость
}

/// Карточки, которые нельзя скрыть — они несут критичную информацию
/// (предупреждение о дожде) или не имеют смысла как самостоятельная
/// "скрываемая" единица. Такие карточки не показываются в экране
/// кастомизации вовсе.
const Set<DashboardCard> nonRemovableCards = {
  DashboardCard.umbrellaReminder,
};

/// Карточки, включённые по умолчанию для нового пользователя (первый
/// запуск, ещё нет сохранённых настроек) — совпадает с прежним жёстко
/// заданным порядком на главном экране, чтобы поведение не изменилось для
/// существующих пользователей после обновления.
const List<DashboardCard> defaultCardOrder = [
  DashboardCard.umbrellaReminder,
  DashboardCard.hourlyForecast,
  DashboardCard.temperatureChart,
  DashboardCard.precipitation,
  DashboardCard.dailyForecast,
  DashboardCard.sunArc,
  DashboardCard.moonPhase,
  DashboardCard.comfortIndex,
  DashboardCard.airQuality,
  DashboardCard.weatherMaps,
  DashboardCard.details,
];
