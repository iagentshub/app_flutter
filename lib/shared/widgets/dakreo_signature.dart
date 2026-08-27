import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../../app/theme/fnc_fonts.dart';

/// Firma de la empresa desarrolladora. El símbolo `<·>` se abre y su punto
/// revela el nombre de Datakreo.
class DakreoSignature extends StatelessWidget {
  const DakreoSignature({Animation<double>? animation, super.key})
    : animation = animation ?? const AlwaysStoppedAnimation<double>(1);

  final Animation<double> animation;

  static const _markWidth = 42.0;
  static const _word = 'DATAKREO';
  static final _wordStyle = FncFonts.code.copyWith(
    color: FncColors.white,
    fontSize: FncFonts.size14,
    fontWeight: FontWeight.w500,
    letterSpacing: 4,
  );

  @override
  Widget build(BuildContext context) {
    // Medido en vez de fijado a mano: con el ancho literal anterior, cambiar
    // el largo de la palabra dejaba el cursor y el recorte fuera de sitio.
    final wordWidth =
        (TextPainter(
              text: TextSpan(text: _word, style: _wordStyle),
              textDirection: TextDirection.ltr,
              textScaler: MediaQuery.textScalerOf(context),
            )..layout())
            .width;

    return Semantics(
      label: 'By Datakreo',
      image: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final progress = animation.value;
            final opacity = Curves.easeOut.transform(
              const Interval(0, 0.16).transform(progress),
            );
            final expansion = Curves.easeInOutCubic.transform(
              const Interval(0.24, 0.86).transform(progress),
            );
            final markExit = Curves.easeInOutCubic.transform(
              const Interval(0.24, 0.72).transform(progress),
            );
            final wordReveal = Curves.easeOutCubic.transform(
              const Interval(0.34, 0.94).transform(progress),
            );
            final cursorExit = Curves.easeIn.transform(
              const Interval(0.88, 1).transform(progress),
            );
            final contentWidth =
                _markWidth + ((wordWidth - _markWidth) * expansion);
            final cursorLeft =
                (_markWidth * 0.5) +
                (((wordWidth - 7) - (_markWidth * 0.5)) * wordReveal);

            return Opacity(
              key: const Key('dakreo-signature-opacity'),
              opacity: opacity,
              child: Row(
                key: const Key('dakreo-signature'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'By',
                    style: FncFonts.codeMicro.copyWith(
                      color: FncColors.grayD0D0D0,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 9),
                  SizedBox(
                    width: contentWidth,
                    height: 24,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        Opacity(
                          key: const Key('dakreo-mark-opacity'),
                          opacity: 1 - markExit,
                          child: SizedBox(
                            width: _markWidth,
                            height: 24,
                            child: CustomPaint(
                              painter: _DakreoMarkPainter(
                                exitProgress: markExit,
                              ),
                            ),
                          ),
                        ),
                        ClipRect(
                          child: Align(
                            key: const Key('dakreo-word-reveal'),
                            alignment: Alignment.centerLeft,
                            widthFactor: wordReveal,
                            child: Text(
                              _word,
                              key: const Key('dakreo-word'),
                              maxLines: 1,
                              softWrap: false,
                              style: _wordStyle,
                            ),
                          ),
                        ),
                        Positioned(
                          left: cursorLeft - 3.5,
                          top: 8.5,
                          child: Opacity(
                            key: const Key('dakreo-cursor-opacity'),
                            opacity: 1 - cursorExit,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: FncColors.purple,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox.square(dimension: 7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DakreoMarkPainter extends CustomPainter {
  const _DakreoMarkPainter({required this.exitProgress});

  final double exitProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = FncColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final left = Path()
      ..moveTo(size.width * 0.34, size.height * 0.18)
      ..lineTo(size.width * 0.16, size.height * 0.5)
      ..lineTo(size.width * 0.34, size.height * 0.82);
    final right = Path()
      ..moveTo(size.width * 0.66, size.height * 0.18)
      ..lineTo(size.width * 0.84, size.height * 0.5)
      ..lineTo(size.width * 0.66, size.height * 0.82);

    canvas
      ..save()
      ..translate(-size.width * 0.18 * exitProgress, 0)
      ..drawPath(left, stroke)
      ..restore()
      ..save()
      ..translate(size.width * 0.18 * exitProgress, 0)
      ..drawPath(right, stroke)
      ..restore();
  }

  @override
  bool shouldRepaint(_DakreoMarkPainter oldDelegate) =>
      oldDelegate.exitProgress != exitProgress;
}
