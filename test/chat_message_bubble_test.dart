import 'package:app_flutter/features/agents/widgets/chat_message_bubble.dart';
import 'package:app_flutter/models/chat/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('ChatMessageBubble', () {
    testWidgets('bloque de código muestra el lenguaje y copia todo el código', (
      tester,
    ) async {
      final log = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          log.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      const code = 'def saluda():\n    print("hola")';
      final message = ChatMessage(
        role: 'assistant',
        content: 'Aquí tienes:\n```python\n$code\n```',
        createdAt: DateTime(2026, 1, 1, 10, 30),
      );

      await tester.pumpWidget(
        _host(
          ChatMessageBubble(
            message: message,
            onReply: (_) {},
            copyCodeTooltip: 'Copiar código',
            replyActionLabel: 'Responder',
            copyActionLabel: 'Copiar',
            messageCopiedLabel: 'Mensaje copiado',
            interruptedLabel: 'Respuesta interrumpida',
            estimatedUsageLabel: 'Uso estimado',
          ),
        ),
      );

      expect(find.text('python'), findsOneWidget);
      expect(find.textContaining('saluda'), findsOneWidget);

      await tester.tap(find.byTooltip('Copiar código'));
      await tester.pump();

      final setDataCall = log.singleWhere(
        (call) => call.method == 'Clipboard.setData',
      );
      expect((setDataCall.arguments as Map)['text'], code);

      // El icono vuelve a "copiar" tras 2s: deja correr ese timer antes de
      // que termine el test para evitar el aviso de timer pendiente.
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets(
      'mantener presionado abre el menú y "Responder" entrega el mensaje',
      (tester) async {
        ChatMessage? replied;
        final message = ChatMessage(
          role: 'user',
          content: 'Hola, ¿cómo estás?',
          createdAt: DateTime(2026, 1, 1, 10, 30),
        );

        await tester.pumpWidget(
          _host(
            ChatMessageBubble(
              message: message,
              onReply: (m) => replied = m,
              copyCodeTooltip: 'Copiar código',
              replyActionLabel: 'Responder',
              copyActionLabel: 'Copiar',
              messageCopiedLabel: 'Mensaje copiado',
              interruptedLabel: 'Respuesta interrumpida',
              estimatedUsageLabel: 'Uso estimado',
            ),
          ),
        );

        await tester.longPress(find.text('Hola, ¿cómo estás?'));
        await tester.pumpAndSettle();

        expect(find.text('Responder'), findsOneWidget);
        expect(find.text('Copiar'), findsOneWidget);

        await tester.tap(find.text('Responder'));
        await tester.pumpAndSettle();

        expect(replied, message);
      },
    );

    testWidgets('el indicador de "pensando" no ofrece el menú contextual', (
      tester,
    ) async {
      const message = ChatMessage(role: 'assistant', content: '');

      await tester.pumpWidget(
        _host(
          ChatMessageBubble(
            message: message,
            thinking: true,
            onReply: (_) {},
            copyCodeTooltip: 'Copiar código',
            replyActionLabel: 'Responder',
            copyActionLabel: 'Copiar',
            messageCopiedLabel: 'Mensaje copiado',
            interruptedLabel: 'Respuesta interrumpida',
            estimatedUsageLabel: 'Uso estimado',
          ),
        ),
      );

      // `pumpAndSettle` no vale aquí: el spinner indeterminado nunca deja de
      // animar, así que se avanza un tiempo acotado en su lugar.
      await tester.longPress(find.byType(CircularProgressIndicator));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Responder'), findsNothing);
    });

    testWidgets(
      'una cita "> " persistida se muestra como bloque referenciado',
      (tester) async {
        final message = ChatMessage(
          role: 'user',
          content: '> Tú: mensaje original citado\n\nEsta es mi respuesta',
          createdAt: DateTime(2026, 1, 1, 10, 30),
        );

        await tester.pumpWidget(
          _host(
            ChatMessageBubble(
              message: message,
              onReply: (_) {},
              copyCodeTooltip: 'Copiar código',
              replyActionLabel: 'Responder',
              copyActionLabel: 'Copiar',
              messageCopiedLabel: 'Mensaje copiado',
              interruptedLabel: 'Respuesta interrumpida',
              estimatedUsageLabel: 'Uso estimado',
            ),
          ),
        );

        expect(find.textContaining('mensaje original citado'), findsOneWidget);
        expect(find.text('Esta es mi respuesta'), findsOneWidget);
      },
    );

    testWidgets('una respuesta detenida conserva contenido y marca el corte', (
      tester,
    ) async {
      const message = ChatMessage(
        role: 'assistant',
        content: 'Respuesta parcial',
        interrupted: true,
        tokensIn: 8,
        tokensOut: 4,
        usageEstimated: true,
      );

      await tester.pumpWidget(
        _host(
          ChatMessageBubble(
            message: message,
            onReply: (_) {},
            copyCodeTooltip: 'Copiar código',
            replyActionLabel: 'Responder',
            copyActionLabel: 'Copiar',
            messageCopiedLabel: 'Mensaje copiado',
            interruptedLabel: 'Respuesta interrumpida',
            estimatedUsageLabel: 'Uso estimado',
          ),
        ),
      );

      expect(find.text('Respuesta parcial'), findsOneWidget);
      expect(find.text('Respuesta interrumpida'), findsOneWidget);
      expect(find.text('Uso estimado'), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    });
  });
}
