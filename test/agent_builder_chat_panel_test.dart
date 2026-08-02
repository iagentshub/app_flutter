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
              title: 'Asistente de diseno',
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
}
