import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/models/agents/agent_models.dart';

void main() {
  group('ResourceItem.isActive', () {
    test('acepta booleanos del contrato API', () {
      expect(const AgentItem(raw: {'is_active': true}).isActive, isTrue);
      expect(const AgentItem(raw: {'is_active': false}).isActive, isFalse);
    });

    test('acepta flags enteros de persistencia', () {
      expect(const AgentItem(raw: {'is_active': 1}).isActive, isTrue);
      expect(const AgentItem(raw: {'is_active': 0}).isActive, isFalse);
    });

    test('mantiene activo por defecto para respuestas antiguas', () {
      expect(const AgentItem(raw: {}).isActive, isTrue);
    });
  });
}
