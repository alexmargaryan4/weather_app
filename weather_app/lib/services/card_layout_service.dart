import 'package:shared_preferences/shared_preferences.dart';
import '../models/dashboard_card.dart';

/// Хранит расположение карточек главного экрана между запусками:
/// — порядок всех карточек (включая скрытые — им просто не находится
///   места в списке "активных", но позиция запоминается на случай
///   возврата);
/// — набор скрытых (удалённых пользователем) карточек.
///
/// Формат хранения: два списка имён enum-констант в SharedPreferences —
/// `dashboard_card_order` (полный порядок) и `dashboard_hidden_cards`
/// (подмножество скрытых). Порядок хранится отдельно от видимости, чтобы
/// при повторном включении карточка вставала туда, где была, а не в конец
/// списка.
class CardLayoutService {
  static const _keyOrder = 'dashboard_card_order';
  static const _keyHidden = 'dashboard_hidden_cards';

  /// Возвращает полный порядок карточек (активные + скрытые вперемешку,
  /// как их расположил пользователь). Если сохранённых данных нет
  /// (первый запуск) или сохранённый список повреждён/устарел —
  /// возвращает [defaultCardOrder].
  ///
  /// Новые карточки, добавленные в приложение уже после того, как
  /// пользователь настроил порядок (то есть отсутствующие в сохранённом
  /// списке), дописываются в конец — иначе они были бы недоступны для
  /// показа до тех пор, пока пользователь не сбросит настройки.
  Future<List<DashboardCard>> getOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_keyOrder);
    if (saved == null || saved.isEmpty) return List.of(defaultCardOrder);

    final byName = {for (final c in DashboardCard.values) c.name: c};
    final result = <DashboardCard>[];
    for (final name in saved) {
      final card = byName[name];
      if (card != null && !result.contains(card)) result.add(card);
    }
    // Довавляем карточки, которых не было в сохранённом списке (новые
    // версии приложения могли добавить новые виды карточек).
    for (final card in defaultCardOrder) {
      if (!result.contains(card)) result.add(card);
    }
    return result;
  }

  Future<void> setOrder(List<DashboardCard> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _keyOrder, order.map((c) => c.name).toList());
  }

  Future<Set<DashboardCard>> getHidden() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_keyHidden) ?? const [];
    final byName = {for (final c in DashboardCard.values) c.name: c};
    return saved.map((n) => byName[n]).whereType<DashboardCard>().toSet();
  }

  Future<void> setHidden(Set<DashboardCard> hidden) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _keyHidden, hidden.map((c) => c.name).toList());
  }

  /// Удобный комбинированный геттер: возвращает только видимые карточки,
  /// уже в правильном порядке — то, что нужно главному экрану для рендера.
  Future<List<DashboardCard>> getVisibleOrder() async {
    final order = await getOrder();
    final hidden = await getHidden();
    return order.where((c) => !hidden.contains(c)).toList();
  }

  /// Сбросить расположение к значению по умолчанию (используется кнопкой
  /// "Сбросить" на экране кастомизации).
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOrder);
    await prefs.remove(_keyHidden);
  }
}
