import 'dart:ui';
import 'dart:math';
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
  final bool animated;

  const GlassPanel({
    super.key,
    required this.child,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.topHighlight = false,
    this.bottomHighlight = false,
    this.animated = false,
  });


  @override
  Widget build(BuildContext context) {

    final Widget panel = ClipRRect(
    borderRadius: borderRadius,

      child: BackdropFilter(

        filter: ImageFilter.blur(
          sigmaX: 22,
          sigmaY: 22,
        ),


        child: SizedBox(
          height: height,
          width: double.infinity,


          child: Stack(
            fit: StackFit.expand,


            children: [


              // Основной материал стекла
              Container(
                color:
                    Colors.white.withOpacity(0.025),
              ),



              // Верхний объемный свет
              Container(

                decoration: BoxDecoration(

                  gradient: LinearGradient(

                    begin:
                        Alignment.topCenter,

                    end:
                        Alignment.bottomCenter,


                    stops: const [
                      0.0,
                      0.12,
                      0.45,
                      1.0,
                    ],


                    colors: [

                      Colors.white.withOpacity(0.28),

                      Colors.white.withOpacity(0.10),

                      Colors.white.withOpacity(0.02),

                      Colors.transparent,

                    ],
                  ),
                ),
              ),



              // Световой блик слева сверху
              Container(

                decoration: BoxDecoration(

                  gradient: RadialGradient(

                    center:
                        const Alignment(
                          -0.55,
                          -0.8,
                        ),


                    radius: 1.3,


                    colors: [

                      Colors.white.withOpacity(0.22),

                      Colors.transparent,

                    ],
                  ),
                ),
              ),




              // Мягкое отражение снизу
              Container(

                decoration: BoxDecoration(

                  gradient: RadialGradient(

                    center:
                        const Alignment(
                          0.7,
                          0.8,
                        ),


                    radius: 1.4,


                    colors: [

                      Colors.white.withOpacity(0.06),

                      Colors.transparent,

                    ],
                  ),
                ),
              ),




              // Цветовой перелив Liquid Glass
              Container(

                decoration: BoxDecoration(

                  gradient: LinearGradient(

                    begin:
                        Alignment.topLeft,

                    end:
                        Alignment.bottomRight,


                    colors: [

                      Colors.cyan.withOpacity(0.018),

                      Colors.transparent,

                      Colors.purple.withOpacity(0.018),

                    ],
                  ),
                ),
              ),




              // Затемнение краев для глубины
              Container(

                decoration: BoxDecoration(

                  gradient: RadialGradient(

                    radius: 1.25,


                    colors: [

                      Colors.transparent,

                      Colors.black.withOpacity(0.045),

                    ],
                  ),
                ),
              ),




              // Процедурный шум
              IgnorePointer(
                child: Opacity(

                  opacity: 0.025,

                  child: CustomPaint(

                    painter:
                        GlassNoisePainter(),

                  ),
                ),
              ),




              // Внешняя кромка стекла
              Container(

                decoration: BoxDecoration(

                  border: Border.all(

                    color:
                        Colors.white.withOpacity(0.20),

                    width:
                        0.7,

                  ),
                ),
              ),




              // Верхняя линия блика
              if (topHighlight)

                Align(

                  alignment:
                      Alignment.topCenter,


                  child: Container(

                    height:
                        1,


                    color:
                        Colors.white.withOpacity(0.35),

                  ),
                ),




              // Нижняя линия блика
              if (bottomHighlight)

                Align(

                  alignment:
                      Alignment.bottomCenter,


                  child: Container(

                    height:
                        1,


                    color:
                        Colors.white.withOpacity(0.25),

                  ),
                ),




              // Внутренняя тень снизу
              if (bottomHighlight)
                Align(

                alignment:
                    Alignment.bottomCenter,


                child: Container(

                  height:
                      18,


                  decoration:
                      BoxDecoration(

                    gradient:
                        LinearGradient(

                      begin:
                          Alignment.topCenter,

                      end:
                          Alignment.bottomCenter,


                      colors: [

                        Colors.transparent,

                        Colors.black.withOpacity(0.035),

                      ],
                    ),
                  ),
                ),
              ),




               child,

            ],
          ),
        ),
      ),
    );

    if (!animated) return panel;
    return AnimatedGlassOverlay(child: panel);
  }
}

class GlassNoisePainter extends CustomPainter {


  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {


    final random = Random();


    final paint = Paint()
      ..color =
          Colors.white.withOpacity(0.8);



    for (int i = 0; i < 700; i++) {


      final x =
          random.nextDouble() *
              size.width;


      final y =
          random.nextDouble() *
              size.height;



      canvas.drawCircle(

        Offset(x, y),

        0.45,

        paint,

      );
    }
  }



  @override
  bool shouldRepaint(
      CustomPainter oldDelegate) {

    return false;
  }
}
/// Готовая "стеклянная" шапка для второстепенных экранов (уведомления,
/// настройка карточек и т.д.) — той же высоты и с тем же стилем размытия,
/// что и статус-бар главного экрана: полоса на всю ширину, во всю высоту
/// системного статус-бара плюс стандартная высота панели навигации, с
/// заголовком по центру и опциональными leading/actions по краям.
class GlassStatusBar extends StatelessWidget
    implements PreferredSizeWidget {

  final String title;
  final Widget? leading;
  final List<Widget>? actions;


  const GlassStatusBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
  });



  static const double toolbarHeight = 56;



  @override
  Size get preferredSize =>
      const Size.fromHeight(toolbarHeight);



  @override
  Widget build(BuildContext context) {


    final statusHeight =
        MediaQuery.of(context).padding.top;



    return GlassPanel(

      height:
          statusHeight + toolbarHeight,


      bottomHighlight:
          true,

      animated: true,


      child: Padding(

        padding:
            EdgeInsets.only(
              top: statusHeight,
            ),



        child: SizedBox(

          height:
              toolbarHeight,



          child: Stack(

            alignment:
                Alignment.center,



            children: [



              // Центральный заголовок
              Center(

                child: Text(

                  title,


                  style:
                      const TextStyle(

                    color:
                        Colors.white,


                    fontSize:
                        17,


                    fontWeight:
                        FontWeight.w600,


                    letterSpacing:
                        -0.25,

                  ),
                ),
              ),




              // Левая кнопка

              if (leading != null)

                Positioned(

                  left:
                      8,


                  child: SizedBox(

                    height:
                        44,


                    child: Center(

                      child:
                          leading,

                    ),
                  ),
                ),





              // Правые кнопки

              if (actions != null)

                Positioned(

                  right:
                      8,


                  child: Row(

                    mainAxisSize:
                        MainAxisSize.min,


                    children:
                        actions!,

                  ),
                ),


            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedGlassOverlay extends StatefulWidget {

  final Widget child;


  const AnimatedGlassOverlay({
    super.key,
    required this.child,
  });



  @override
  State<AnimatedGlassOverlay> createState() =>
      _AnimatedGlassOverlayState();
}




class _AnimatedGlassOverlayState
    extends State<AnimatedGlassOverlay>
    with SingleTickerProviderStateMixin {


  late AnimationController controller;



  @override
  void initState() {

    super.initState();


    controller = AnimationController(

      vsync: this,

      duration:
          const Duration(seconds: 10),

    )..repeat();

  }




  @override
  void dispose() {

    controller.dispose();

    super.dispose();

  }




  @override
  Widget build(BuildContext context) {


    return AnimatedBuilder(

      animation:
          controller,


      builder:
          (context, child) {


        final value =
            sin(
              controller.value *
              pi *
              2,
            );



        return Stack(

          fit:
              StackFit.expand,


          children: [


            widget.child,




            IgnorePointer(

              child: Opacity(

                opacity:
                    0.035 +
                    value.abs() * 0.025,



                child: Container(

                  decoration:
                      BoxDecoration(


                    gradient:
                        LinearGradient(


                      begin:
                          Alignment(
                            -1 +
                            value * 0.25,

                            -1,
                          ),



                      end:
                          const Alignment(
                            1,
                            1,
                          ),



                      colors: [


                        Colors.white
                            .withOpacity(0.22),



                        Colors.transparent,



                      ],
                    ),
                  ),
                ),
              ),
            ),

          ],
        );
      },
    );
  }
}
