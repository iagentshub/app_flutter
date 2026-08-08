import 'package:app_flutter/shared/labels/label_catalog.dart';
import 'package:app_flutter/shared/widgets/grouped_label_picker.dart';
import 'package:app_flutter/shared/widgets/multi_select_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _tx(String path, String fallback) => switch (path) {
  'labels.group_language' => 'Idioma del contenido',
  'labels.lang_es' => 'Español',
  'labels.lang_en' => 'Inglés',
  _ => fallback,
};

void main() {
  test('el catálogo expone idiomas como labels opcionales y múltiples', () {
    expect(kContentLanguageCodes, containsAll(['es', 'en', 'fr', 'de']));
    expect(kLanguageLabelGroup.exclusive, isFalse);
    expect(kLanguageLabelGroup.required, isFalse);
    expect(kLabelKeys, containsAll(['lang_es', 'lang_en']));
    expect(languageCodeFromLabel('lang_es'), 'es');
    expect(contentLanguageLabel(_tx, 'en'), 'Inglés');
    expect(contentLabelsForScope('private', ['lang_en', 'basura', 'lang_es']), [
      'private',
      'lang_es',
      'lang_en',
    ]);
  });

  testWidgets('el selector permite marcar más de un idioma', (tester) async {
    var selected = <String>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => GroupedLabelPicker(
              selected: selected,
              onChanged: (next) => setState(() => selected = next),
              tx: _tx,
              groups: const [kLanguageLabelGroup],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(MultiSelectDropdown<String>), findsOneWidget);
    await tester.tap(find.byType(MultiSelectDropdown<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Español'));
    await tester.pump();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Inglés'));
    await tester.pump();

    expect(selected, {'lang_es', 'lang_en'});
  });

  testWidgets('el selector agrupa labels y respeta exclusividad', (
    tester,
  ) async {
    var selected = <String>{'private'};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => GroupedLabelPicker(
              selected: selected,
              onChanged: (next) => setState(() => selected = next),
              tx: _tx,
              groups: kOperationalLabelGroups,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(MultiSelectDropdown<String>), findsOneWidget);
    await tester.tap(find.byType(MultiSelectDropdown<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'public'));
    await tester.pump();

    expect(selected, contains('public'));
    expect(selected, isNot(contains('private')));
  });

  testWidgets('el indicador visual queda entre el checkbox y la etiqueta', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiSelectDropdown<String>(
            options: const [
              MultiSelectDropdownOption(
                value: 'agent',
                label: 'Agente',
                icon: Icons.smart_toy_outlined,
                color: Colors.red,
              ),
            ],
            selectedValues: const {},
            emptyLabel: 'Todos',
            tooltip: 'Tipos',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(MultiSelectDropdown<String>));
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(CheckboxListTile, 'Agente');
    final checkbox = find.descendant(of: tile, matching: find.byType(Checkbox));
    final icon = find.descendant(
      of: tile,
      matching: find.byIcon(Icons.smart_toy_outlined),
    );
    final label = find.descendant(of: tile, matching: find.text('Agente'));

    expect(tester.getCenter(checkbox).dx, lessThan(tester.getCenter(icon).dx));
    expect(tester.getCenter(icon).dx, lessThan(tester.getTopLeft(label).dx));
  });
}
