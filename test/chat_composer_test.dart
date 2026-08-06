import 'package:app_flutter/features/agents/widgets/chat_composer.dart';
import 'package:app_flutter/models/chat/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('ChatComposer reply preview', () {
    testWidgets('se oculta cuando no hay respuesta activa', (tester) async {
      await tester.pumpWidget(
        _host(
          ChatComposer(
            textController: TextEditingController(),
            mentionLink: LayerLink(),
            attachedKnowledge: const [],
            onRemoveKnowledge: (_) {},
            streaming: false,
            onSend: () {},
            onStop: () {},
            sendTooltip: 'Enviar mensaje',
            stopTooltip: 'Detener respuesta',
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets(
      'muestra la cita truncada y cancela la respuesta al pulsar la X',
      (tester) async {
        var cancelled = false;
        final replyTo = ChatMessage(
          role: 'assistant',
          content: 'Respuesta original del agente',
          createdAt: DateTime(2026, 1, 1),
        );

        await tester.pumpWidget(
          _host(
            ChatComposer(
              textController: TextEditingController(),
              mentionLink: LayerLink(),
              attachedKnowledge: const [],
              onRemoveKnowledge: (_) {},
              streaming: false,
              onSend: () {},
              onStop: () {},
              sendTooltip: 'Enviar mensaje',
              stopTooltip: 'Detener respuesta',
              replyTo: replyTo,
              replyToLabel: 'Asistente',
              onCancelReply: () => cancelled = true,
              cancelReplyTooltip: 'Cancelar respuesta',
            ),
          ),
        );

        expect(find.text('Asistente'), findsOneWidget);
        expect(find.text('Respuesta original del agente'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();

        expect(cancelled, isTrue);
      },
    );
  });
}
