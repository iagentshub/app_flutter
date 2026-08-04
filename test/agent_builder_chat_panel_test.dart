import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/features/agents/widgets/agent_builder_chat_panel.dart';
import 'package:app_flutter/models/chat/chat_models.dart';

void main() {
  late TextEditingController textController;
  late ScrollController scrollController;

  setUp(() {
    textController = TextEditingController();
    scrollController = ScrollController();
  });

  tearDown(() {
    textController.dispose();
    scrollController.dispose();
  });

  Widget subject({
    List<ChatMessage> messages = const [],
    bool streaming = false,
    bool thinking = false,
    bool enabled = true,
    String partialReply = '',
    Map<String, dynamic>? draft,
    VoidCallback? onReviewDraft,
    String? error,
    ValueChanged<String>? onSuggestion,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 390,
            height: 650,
            child: AgentBuilderChatPanel(
              messages: messages,
              streaming: streaming,
              thinking: thinking,
              enabled: enabled,
              textController: textController,
              scrollController: scrollController,
              onSend: () {},
              onStop: () {},
              onSuggestion: onSuggestion ?? (_) {},
              partialReply: partialReply,
              draft: draft,
              draftTitle: 'Borrador propuesto',
              draftActionLabel: 'Revisar y crear',
              onReviewDraft: onReviewDraft,
              intro: 'Describe el agente que quieres crear.',
              inputHint: 'Escribe tu idea',
              sendTooltip: 'Enviar mensaje',
              stopTooltip: 'Detener respuesta',
              suggestions: const ['Atender clientes', 'Cualificar leads'],
              error: error,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('mantiene visible el compositor antes del primer mensaje', (
    tester,
  ) async {
    await tester.pumpWidget(subject());

    expect(
      find.byKey(const ValueKey('agent-builder-composer')),
      findsOneWidget,
    );
    expect(find.text('Describe el agente que quieres crear.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('las sugerencias inician la conversacion', (tester) async {
    String? selected;
    await tester.pumpWidget(subject(onSuggestion: (value) => selected = value));

    await tester.tap(find.text('Atender clientes'));

    expect(selected, 'Atender clientes');
  });

  testWidgets('presenta mensajes, espera y error sin desbordarse', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        messages: const [
          ChatMessage(role: 'user', content: 'Necesito un agente de soporte'),
          ChatMessage(role: 'assistant', content: 'Que canales atendera?'),
        ],
        streaming: true,
        thinking: true,
        error: 'No se pudo completar la respuesta',
      ),
    );

    expect(find.text('Necesito un agente de soporte'), findsOneWidget);
    expect(find.text('Que canales atendera?'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No se pudo completar la respuesta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('presenta identidad y estructura legible en las respuestas', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        messages: const [
          ChatMessage(role: 'user', content: 'Necesito un agente profesional'),
          ChatMessage(
            role: 'assistant',
            content: '# Propuesta\n\n- Objetivo claro\n- Límites definidos',
          ),
        ],
      ),
    );

    expect(find.text('Tú'), findsOneWidget);
    expect(find.text('Asistente IA'), findsOneWidget);
    expect(find.text('Propuesta'), findsOneWidget);
    expect(find.text('Objetivo claro'), findsOneWidget);
    expect(find.text('Límites definidos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el texto parcial sustituye al indicador de espera', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        messages: const [
          ChatMessage(role: 'user', content: 'Necesito un agente de soporte'),
        ],
        streaming: true,
        thinking: true,
        partialReply: 'He preparado el bo',
      ),
    );

    expect(find.text('He preparado el bo'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('al cerrar el turno no queda una burbuja de espera vacia', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        messages: const [
          ChatMessage(role: 'user', content: 'Necesito un agente de soporte'),
          ChatMessage(role: 'assistant', content: 'He preparado el borrador.'),
        ],
      ),
    );

    expect(find.text('Asistente IA'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el borrador se revisa solo cuando el usuario lo pide', (
    tester,
  ) async {
    var reviewed = 0;
    await tester.pumpWidget(
      subject(
        messages: const [
          ChatMessage(role: 'assistant', content: 'He preparado el borrador.'),
        ],
        draft: const {
          'name': 'Asistente de soporte',
          'description': 'Atiende consultas de clientes',
        },
        onReviewDraft: () => reviewed += 1,
      ),
    );

    expect(find.byKey(const ValueKey('builder-draft-card')), findsOneWidget);
    expect(find.text('Asistente de soporte'), findsOneWidget);
    expect(find.text('Atiende consultas de clientes'), findsOneWidget);
    expect(reviewed, 0);

    await tester.tap(find.text('Revisar y crear'));
    await tester.pump();

    expect(reviewed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin borrador no se muestra la tarjeta', (tester) async {
    await tester.pumpWidget(
      subject(
        messages: const [
          ChatMessage(role: 'assistant', content: 'Que canales atendera?'),
        ],
      ),
    );

    expect(find.byKey(const ValueKey('builder-draft-card')), findsNothing);
  });
}
