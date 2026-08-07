import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../localization/app_localizations.dart';
import '../models/dashboard_card.dart';
import '../services/card_layout_service.dart';
import '../widgets/glass_panel.dart';

/// Экран редактирования набора карточек главного экрана — по образцу
/// "Пункта управления" на iOS: активные виджеты показаны сеткой сверху,
/// их можно перетаскивать (меняя порядок) и убирать кнопкой "–" в углу;
/// скрытые виджеты лежат отдельной сеткой ниже и добавляются обратно
/// кнопкой "+". Изменения применяются сразу же (сохраняются в
/// [CardLayoutService] при каждом действии), поэтому отдельной кнопки
/// "Сохранить" нет — только "Готово", чтобы закрыть экран.
class CustomizeCardsScreen extends StatefulWidget {
  const CustomizeCardsScreen({super.key});

  @override
  State<CustomizeCardsScreen> createState() => _CustomizeCardsScreenState();
}

class _CustomizeCardsScreenState extends State<CustomizeCardsScreen> {
  final CardLayoutService _layoutService = CardLayoutService();

  List<DashboardCard> _order = [];
  Set<DashboardCard> _hidden = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final order = await _layoutService.getOrder();
    final hidden = await _layoutService.getHidden();
    if (!mounted) return;
    setState(() {
      _order = order;
      _hidden = hidden;
      _loading = false;
    });
  }

  List<DashboardCard> get _activeCards =>
      _order.where((c) => !_hidden.contains(c)).toList();

  List<DashboardCard> get _hiddenCards =>
      _order.where((c) => _hidden.contains(c)).toList();

  Future<void> _persist() async {
    await _layoutService.setOrder(_order);
    await _layoutService.setHidden(_hidden);
  }

  void _removeCard(DashboardCard card) {
    HapticFeedback.mediumImpact();
    setState(() => _hidden.add(card));
    _persist();
  }

  void _addCard(DashboardCard card) {
    HapticFeedback.mediumImpact();
    setState(() => _hidden.remove(card));
    _persist();
  }

  void _reorderActive(int oldIndex, int newIndex) {
    HapticFeedback.selectionClick();
    final active = _activeCards;
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = active.removeAt(oldIndex);
    active.insert(newIndex, moved);
    // Пересобираем полный _order: активные в новом порядке + скрытые в
    // прежнем относительном порядке, дописанные в конец.
    setState(() {
      _order = [...active, ..._hiddenCards];
    });
    _persist();
  }

  Future<void> _reset() async {
    HapticFeedback.mediumImpact();
    await _layoutService.reset();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final statusBarHeight = MediaQuery.of(context).padding.top;
    final topInset = statusBarHeight + GlassStatusBar.toolbarHeight;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),
      extendBodyBehindAppBar: true,
      appBar: GlassStatusBar(
        title: l10n.customizeCardsTitle,
        leading: TextButton(
          onPressed: _reset,
          child: Text(
            l10n.customizeCardsReset,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.customizeCardsDone,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : ListView(
              padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 32),
              children: [
                Text(
                  l10n.customizeCardsSubtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                _SectionLabel(text: l10n.customizeCardsActive),
                const SizedBox(height: 10),
                if (_activeCards.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      l10n.customizeCardsEmpty,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  )
                else
                  _ReorderableCardGrid(
                    cards: _activeCards,
                    onReorder: _reorderActive,
                    onRemove: _removeCard,
                  ),
                if (_hiddenCards.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _SectionLabel(text: l10n.customizeCardsAddMore),
                  const SizedBox(height: 10),
                  _StaticCardGrid(
                    cards: _hiddenCards,
                    onAdd: _addCard,
                  ),
                ],
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Сетка активных карточек с поддержкой перетаскивания (long-press + drag)
/// и кнопкой "–" в углу каждой плитки для быстрого удаления без
/// перетаскивания. Используется [ReorderableWrap]-подобное поведение через
/// встроенный [ReorderableGridView]-эквивалент — здесь реализован вручную
/// поверх [ReorderableListView] в режиме сетки не требуется: используем
/// колонку с попарно сгруппированными строками, чтобы получить сетку 2xN
/// с полноценным drag & drop от [ReorderableListView].
class _ReorderableCardGrid extends StatelessWidget {
  final List<DashboardCard> cards;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(DashboardCard card) onRemove;

  const _ReorderableCardGrid({
    required this.cards,
    required this.onReorder,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: onReorder,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, c) {
            final t = Curves.easeOut.transform(animation.value);
            return Transform.scale(
              scale: 1.0 + 0.04 * t,
              child: Opacity(opacity: 0.9 + 0.1 * (1 - t), child: c),
            );
          },
          child: child,
        );
      },
      children: [
        for (int i = 0; i < cards.length; i++)
          Padding(
            key: ValueKey(cards[i]),
            padding: const EdgeInsets.only(bottom: 10),
            child: ReorderableDragStartListener(
              index: i,
              child: _CardTile(
                card: cards[i],
                trailing: _RemoveButton(onTap: () => onRemove(cards[i])),
              ),
            ),
          ),
      ],
    );
  }
}

/// Статичная (не перетаскиваемая) сетка скрытых карточек — плитки
/// расположены в 2 колонки, каждая с кнопкой "+" для возврата на главный
/// экран.
class _StaticCardGrid extends StatelessWidget {
  final List<DashboardCard> cards;
  final void Function(DashboardCard card) onAdd;

  const _StaticCardGrid({required this.cards, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.4,
      ),
      itemBuilder: (context, index) {
        final card = cards[index];
        return _CardTile(
          card: card,
          trailing: _AddButton(onTap: () => onAdd(card)),
        );
      },
    );
  }
}

/// Одна плитка карточки: иконка + название + кнопка действия (+/–) в углу.
/// Сам виджет не показывает реальные данные погоды — это лишь
/// "превью-ярлык" карточки на экране редактирования, как в iOS Control
/// Center, а не живой предпросмотр.
class _CardTile extends StatelessWidget {
  final DashboardCard card;
  final Widget trailing;

  const _CardTile({required this.card, required this.trailing});

  IconData _iconFor(DashboardCard card) {
    switch (card) {
      case DashboardCard.umbrellaReminder:
        return Icons.umbrella_rounded;
      case DashboardCard.hourlyForecast:
        return Icons.schedule_rounded;
      case DashboardCard.temperatureChart:
        return Icons.show_chart_rounded;
      case DashboardCard.precipitation:
        return Icons.water_drop_outlined;
      case DashboardCard.dailyForecast:
        return Icons.calendar_month_rounded;
      case DashboardCard.sunArc:
        return Icons.wb_sunny_outlined;
      case DashboardCard.moonPhase:
        return Icons.nightlight_round;
      case DashboardCard.comfortIndex:
        return Icons.favorite_border_rounded;
      case DashboardCard.airQuality:
        return Icons.air_rounded;
      case DashboardCard.weatherMaps:
        return Icons.map_outlined;
      case DashboardCard.details:
        return Icons.grid_view_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconFor(card), color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.cardDisplayName(card),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(width: 6),
          trailing,
        ],
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          color: Color(0xFFFF5B5B),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.remove_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(0.85),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add_rounded, color: Colors.black87, size: 18),
      ),
    );
  }
}
