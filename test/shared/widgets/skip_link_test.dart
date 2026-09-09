import 'package:app_flutter/shared/widgets/shell/skip_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// La misma estructura que el shell ancho: un menú a la izquierda, el
/// contenido dentro de un Navigator anidado —como el del ShellRoute— envuelto
/// en el ámbito de foco del contenido, un enlace «Ir al menú» dentro de ese
/// ámbito y otro «Saltar al contenido» superpuesto en la esquina del shell.
///
/// El Navigator anidado importa: cada ruta es un `FocusScope`, y en la build
/// release web Tab da vueltas dentro de la página sin llegar nunca al menú
/// —en la VM y en debug sí sale—. Lo que se fija aquí es lo que vale en los
/// dos casos: el enlace hacia el menú está dentro del ciclo de la página y
/// lleva al primer control del menú; desde el menú se entra en la página; y
/// «Saltar al contenido» lleva a un control de la página.
class _Shell extends StatelessWidget {
  const _Shell({
    required this.contentScope,
    required this.menuFocus,
    required this.contentButton,
  });

  final FocusScopeNode contentScope;
  final FocusNode menuFocus;
  final FocusNode contentButton;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Row(
              children: [
                Focus(
                  focusNode: menuFocus,
                  skipTraversal: true,
                  child: SizedBox(
                    width: 240,
                    child: Column(
                      children: [
                        const SizedBox(height: 60),
                        for (var i = 0; i < 3; i++)
                          TextButton(
                            focusNode: FocusNode(debugLabel: 'menú $i'),
                            onPressed: () {},
                            child: Text('menú $i'),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: FocusScope(
                    node: contentScope,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Navigator(
                          onGenerateRoute: (_) => MaterialPageRoute<void>(
                            builder: (_) => Column(
                              children: [
                                const SizedBox(height: 40),
                                TextButton(
                                  focusNode: contentButton,
                                  onPressed: () {},
                                  child: const Text('contenido'),
                                ),
                                TextButton(
                                  focusNode: FocusNode(
                                    debugLabel: 'contenido 2',
                                  ),
                                  onPressed: () {},
                                  child: const Text('contenido 2'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          child: SkipLink(
                            label: 'Ir al menú',
                            target: menuFocus,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              child: SkipLink(
                label: 'Saltar al contenido',
                target: contentScope,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _tab(WidgetTester tester, {bool back = false}) async {
  if (back) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  } else {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  }
  await tester.pump();
}

String _focused() => FocusManager.instance.primaryFocus?.debugLabel ?? '?';

// La opacidad que interesa es la del propio enlace, no la que [PrimaryButton]
// usa para su estado ocupado: se busca dentro del [SkipLink] y se toma la
// primera —la de fuera— en lugar de exigir que solo haya una.
double _opacityOf(WidgetTester tester, String label) => tester
    .widget<Opacity>(
      find
          .descendant(
            of: find.widgetWithText(SkipLink, label),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

bool _inPage(WidgetTester tester) =>
    const {'contenido', 'contenido 2'}.contains(_focused()) ||
    _opacityOf(tester, 'Ir al menú') == 1;

({FocusScopeNode scope, FocusNode menu, FocusNode button}) _nodes() {
  final scope = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );
  final menu = FocusNode(debugLabel: 'menú', skipTraversal: true);
  final button = FocusNode(debugLabel: 'contenido');
  addTearDown(scope.dispose);
  addTearDown(menu.dispose);
  addTearDown(button.dispose);
  return (scope: scope, menu: menu, button: button);
}

Future<({FocusScopeNode scope, FocusNode menu, FocusNode button})> _pump(
  WidgetTester tester,
) async {
  final n = _nodes();
  await tester.pumpWidget(
    _Shell(contentScope: n.scope, menuFocus: n.menu, contentButton: n.button),
  );
  await tester.pump();
  return n;
}

void main() {
  testWidgets('desde la página, Tab llega a «Ir al menú» y Enter entra en él', (
    tester,
  ) async {
    await _pump(tester);

    // Al cargar, el foco arranca dentro de la página.
    await _tab(tester);
    expect(_focused(), 'contenido');
    expect(_opacityOf(tester, 'Ir al menú'), 0);

    // El enlace forma parte del ciclo de la página: unas pocas paradas más y
    // aparece. Cuántas exactamente depende de cómo ordene Flutter el ámbito de
    // la ruta, que no es igual en release; por eso se busca, no se cuenta.
    var vueltas = 0;
    while (_opacityOf(tester, 'Ir al menú') == 0 && vueltas < 8) {
      await _tab(tester);
      vueltas++;
    }
    expect(_opacityOf(tester, 'Ir al menú'), 1, reason: 'no llegó al enlace');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_focused(), 'menú 0');
    expect(_opacityOf(tester, 'Ir al menú'), 0);
  });

  testWidgets('desde el menú se entra en la página', (tester) async {
    await _pump(tester);

    n0(tester);
    await tester.pump();
    expect(_focused(), 'menú 0');
    await _tab(tester);
    await _tab(tester);
    expect(_focused(), 'menú 2');

    // Tras el último elemento del menú viene la página.
    var dentro = false;
    for (var i = 0; i < 3 && !dentro; i++) {
      await _tab(tester);
      dentro = _inPage(tester);
    }
    expect(dentro, isTrue, reason: 'Tab no entró en la página desde el menú');
  });

  testWidgets('«Saltar al contenido» precede al menú y lleva a la página', (
    tester,
  ) async {
    await _pump(tester);

    // Está justo antes del primer elemento del menú: Shift+Tab desde él.
    n0(tester);
    await tester.pump();
    await _tab(tester, back: true);
    expect(_opacityOf(tester, 'Saltar al contenido'), 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_opacityOf(tester, 'Saltar al contenido'), 0);
    // El foco cae en un control de la página, o en su ámbito y el siguiente
    // Tab entra; las dos cosas dependen del orden del ámbito de la ruta.
    if (!_inPage(tester)) await _tab(tester);
    expect(_inPage(tester), isTrue);
  });
}

/// Deja el foco en «menú 0».
void n0(WidgetTester tester) {
  final button = find.widgetWithText(TextButton, 'menú 0');
  tester.widget<TextButton>(button).focusNode!.requestFocus();
}
