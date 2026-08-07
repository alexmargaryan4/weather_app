import 'dart:ui';
import 'package:flutter/material.dart';

/// Общий "стеклянный" слой — единый стиль размытия/бликов/границ,
/// который используется и на статус-баре главного экрана, и на нижней
/// панели городов, и (теперь) на верхних панелях второстепенных экранов
/// (уведомления, настройка карточек), чтобы визуально всё выглядело как
/// один и тот же материал, а не набор разных полупрозрачных плашек.
///
/// [borderRadius] позволяет использовать этот же слой как для
/// прямоугольной полосы на всю ширину (статус-бар, шапка экрана), так и
/// для скруглённой капсулы (панель кнопок на главном экране).
/// [topHighlight]/[bottomHighlight] управляют тем, с какой стороны рисуется
/// тонкая граница-блик — сверху (как у нижней панели городов) или снизу
/// (как у статус-бара).
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double? height;
  final BorderRadius borderRadius;
  final bool topHighlight;
  final bool bottomHighlight;

  const GlassPanel({
    super.key,
    required this.child,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.topHighlight = false,
    this.bottomHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Основной стеклянный слой
              Container(color: Colors.white.withOpacity(0.025)),

              // Верхний блик
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.15, 0.4, 1.0],
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Лёгкая дымка
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withOpacity(0.015),
                      Colors.transparent,
                      Colors.white.withOpacity(0.015),
                    ],
                  ),
                ),
              ),

              if (bottomHighlight)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.025),
                        ],
                      ),
                    ),
                  ),
                ),

              if (bottomHighlight)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 0.5,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),

              if (bottomHighlight)
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),

              if (topHighlight)
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 0.5,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),

              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Готовая "стеклянная" шапка для второстепенных экранов (уведомления,
/// настройка карточек и т.д.) — той же высоты и с тем же стилем размытия,
/// что и статус-бар главного экрана: полоса на всю ширину, во всю высоту
/// системного статус-бара плюс стандартная высота панели навигации, с
/// заголовком по центру и опциональными leading/actions по краям.
class GlassStatusBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;

  const GlassStatusBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
  });

  /// Высота собственно панели навигации (без учёта системного статус-бара) —
  /// публичная, чтобы экраны могли рассчитать нужный верхний отступ для
  /// своего скроллящегося контента (тот же приём, что и с
  /// `statusBarHeight` на главном экране).
  static const double toolbarHeight = 56;

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final totalHeight = statusBarHeight + toolbarHeight;

    return GlassPanel(
      height: totalHeight,
      topHighlight: false,
      bottomHighlight: true,
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: SizedBox(
          height: toolbarHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (leading != null)
                Positioned(
                  left: 4,
                  child: leading!,
                ),
              if (actions != null)
                Positioned(
                  right: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
