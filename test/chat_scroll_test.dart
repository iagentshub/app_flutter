import 'package:app_flutter/features/agents/widgets/chat_message_list.dart';
import 'package:app_flutter/models/chat/chat_models.dart';
import 'package:app_flutter/shared/utils/scroll_to_end.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El chat llamaba a `scrollToEnd(..., animate: false)` tras cada token, y eso
/// es un `jumpTo(maxScrollExtent)` incondicional: si el usuario subía a releer
/// un mensaje mientras llegaba la respuesta, la vista lo devolvía al final
/// varias veces por segundo. Releer durante una respuesta larga era imposible.
void main() {
  Future<ScrollController> montarLista(WidgetTester tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: ListView.builder(
              controller: controller,
              itemCount: 60,
              itemBuilder: (_, i) => SizedBox(height: 50, child: Text('$i')),
            ),
          ),
        ),
      ),
    );
    return controller;
  }

  testWidgets('maybeScrollToEnd sigue el final si el usuario está abajo', (
    tester,
  ) async {
    final controller = await montarLista(tester);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    // Llega contenido nuevo y con él la petición de seguir al final.
    maybeScrollToEnd(controller);
    await tester.pump();

    expect(isAtEnd(controller), isTrue);
    expect(controller.position.pixels, controller.position.maxScrollExtent);
  });

  testWidgets('maybeScrollToEnd respeta al que se ha ido a releer', (
    tester,
  ) async {
    final controller = await montarLista(tester);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    // El usuario sube a releer.
    controller.jumpTo(controller.position.maxScrollExtent - 400);
    await tester.pump();
    final posicionLeyendo = controller.position.pixels;
    expect(isAtEnd(controller), isFalse);

    // Siguen llegando tokens: la posición no se toca.
    maybeScrollToEnd(controller);
    await tester.pump();
    expect(controller.position.pixels, posicionLeyendo);

    // Y bajar a mano sigue funcionando. El salto va en un `addPostFrameCallback`
    // y aquí no hay nada sucio que provoque el frame siguiente —en la app lo
    // provoca el propio toque del chip—, así que se pide a mano.
    scrollToEnd(controller, animate: false);
    tester.binding.scheduleFrame();
    await tester.pump(const Duration(milliseconds: 16));
    expect(isAtEnd(controller), isTrue);
  });

  testWidgets('un arrastre mínimo no cuenta como haberse separado', (
    tester,
  ) async {
    final controller = await montarLista(tester);
    controller.jumpTo(controller.position.maxScrollExtent - 20);
    await tester.pump();

    expect(isAtEnd(controller), isTrue);
  });

  testWidgets('la respuesta en curso se pinta desde su ValueNotifier', (
    tester,
  ) async {
    final reply = ValueNotifier<String>('');
    addTearDown(reply.dispose);
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageList(
            messages: const [ChatMessage(role: 'user', content: 'Hola')],
            streaming: true,
            thinking: true,
            streamingReply: reply,
            scrollController: controller,
            onReply: (_) {},
            copyCodeTooltip: 'Copiar código',
            replyActionLabel: 'Responder',
            copyActionLabel: 'Copiar',
            messageCopiedLabel: 'Mensaje copiado',
            interruptedLabel: 'Respuesta interrumpida',
            estimatedUsageLabel: 'Uso estimado',
          ),
        ),
      ),
    );

    expect(find.text('Hola'), findsOneWidget);

    // Cada token solo cambia el notifier: no hay setState de la página.
    reply.value = 'Voy respon';
    await tester.pump();
    expect(find.textContaining('Voy respon'), findsOneWidget);

    reply.value = 'Voy respondiendo';
    await tester.pump();
    expect(find.textContaining('Voy respondiendo'), findsOneWidget);
  });
}
