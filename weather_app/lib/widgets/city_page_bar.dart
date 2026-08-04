import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Нижняя панель переключения городов — как страничный индикатор в
/// приложении погоды Apple: слева самолётик (город по геолокации),
/// дальше по кружку на каждый сохранённый город. Тап переключает,
/// долгое нажатие на кружок города открывает меню (перейти / удалить
/// из избранного).
///
/// [currentIndex] совпадает с `_currentPageIndex` в HomeScreen:
/// индекс 0 — геолокация, дальше — favoriteCities по порядку.
class CityPageBar extends StatelessWidget {
  final int currentIndex;
  final List<String> favoriteCities;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onRemoveFavorite;

  const CityPageBar({
    super.key,
    required this.currentIndex,
    required this.favoriteCities,
    required this.onSelect,
    required this.onRemoveFavorite,
  });

  @override
  Widget build(BuildContext context) {
    // Если избранных городов нет, показывать нечего — переключаться не между чем.
    if (favoriteCities.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _GeoDot(
            selected: currentIndex == 0,
            onTap: () => onSelect(0),
          ),
          for (int i = 0; i < favoriteCities.length; i++)
            _CityDot(
              cityName: favoriteCities[i],
              selected: currentIndex == i + 1,
              onTap: () => onSelect(i + 1),
              onLongPress: () =>
                  _showCityMenu(context, favoriteCities[i], i + 1),
            ),
        ],
      ),
    );
  }

  Future<void> _showCityMenu(
      BuildContext context, String city, int index) async {
    HapticFeedback.mediumImpact();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _CityQuickMenu(cityName: city),
    );
    if (action == 'open') {
      onSelect(index);
    } else if (action == 'remove') {
      onRemoveFavorite(city);
    }
  }
}

/// Кружок-иконка самолётика — текущее местоположение пользователя.
class _GeoDot extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _GeoDot({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _DotButton(
      selected: selected,
      tooltip: 'Моя геолокация',
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Icon(
        Icons.airplanemode_active_rounded,
        size: 18,
        color: selected ? const Color(0xFF0F1C3F) : Colors.white,
      ),
    );
  }
}

/// Кружок с первой буквой сохранённого города.
class _CityDot extends StatelessWidget {
  final String cityName;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CityDot({
    required this.cityName,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final letter = cityName.trim().isNotEmpty
        ? cityName.trim()[0].toUpperCase()
        : '?';
    return _DotButton(
      selected: selected,
      tooltip: cityName,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      onLongPress: onLongPress,
      child: Text(
        letter,
        style: TextStyle(
          color: selected ? const Color(0xFF0F1C3F) : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

/// Общий круглый "чип"-кнопка для панели: активная страница выделена
/// белой заливкой (как активная точка в системном пейджере Apple),
/// неактивные — полупрозрачные.
class _DotButton extends StatefulWidget {
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  const _DotButton({
    required this.selected,
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.onLongPress,
  });

  @override
  State<_DotButton> createState() => _DotButtonState();
}

class _DotButtonState extends State<_DotButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.selected
                    ? Colors.white
                    : Colors.white.withOpacity(0.16),
                border: Border.all(
                  color: Colors.white.withOpacity(widget.selected ? 0 : 0.28),
                  width: 1,
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Маленькая шторка, открывающаяся по долгому нажатию на город в панели:
/// быстрый переход или удаление из избранного, без похода в общий поиск.
class _CityQuickMenu extends StatelessWidget {
  final String cityName;

  const _CityQuickMenu({required this.cityName});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2A47),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.location_city_rounded,
                      color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cityName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white70),
              title: const Text('Перейти к городу',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'open'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent),
              title: const Text('Удалить из избранного',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );
  }
}
