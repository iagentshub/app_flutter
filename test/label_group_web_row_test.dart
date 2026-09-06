import 'package:app_flutter/features/labels/cards/label_catalog_card.dart';
import 'package:app_flutter/shared/labels/label_catalog.dart';
import 'package:app_flutter/shared/widgets/resource_collection_view.dart';
import 'package:app_flutter/utils/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'el cat?logo permite expandir y cerrar grupos sin limitar su altura',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResourceCollectionView(
              alignRows: false,
              itemCount: 2,
              itemBuilder: (context, index) => LabelGroupCard(
                group: index == 0 ? kOwnershipGroup : kOriginGroup,
                text: tr,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(const ValueKey('label-group-toggle-labels.group_ownership')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Eres el propietario directo de este recurso.'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('label-group-toggle-labels.group_ownership')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Eres el propietario directo de este recurso.'),
        findsNothing,
      );
    },
  );
}
