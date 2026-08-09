import 'package:app_flutter/models/agents/agent_models.dart';
import 'package:app_flutter/models/skills/skill_models.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('ResourceItem.propertyType', () {
    test('propietario puede gestionar el recurso', () {
      const item = SkillItem(raw: {'scope': 'public', 'origin_type': 'owner'});
      expect(item.propertyType, 'owner');
      expect(item.readOnly, isFalse);
    });

    test('enlace es de solo lectura por etiqueta o dato calculado', () {
      const byLabel = SkillItem(
        raw: {
          'labels': ['private', 'linked'],
        },
      );
      const byOrigin = SkillItem(raw: {'origin_type': 'linked'});
      expect(byLabel.propertyType, 'linked');
      expect(byLabel.readOnly, isTrue);
      expect(byOrigin.readOnly, isTrue);
    });

    test('fork es una copia gestionable y prevalece sobre linked', () {
      const item = SkillItem(
        raw: {
          'origin_type': 'linked',
          'labels': ['private', 'fork'],
        },
      );
      expect(item.propertyType, 'fork');
      expect(item.forked, isTrue);
      expect(item.readOnly, isFalse);
      expect(item.displayLabels, ['private']);
    });
  });
}
