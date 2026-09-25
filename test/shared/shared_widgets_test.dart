import 'package:agrilink_mobile/core/session/role.dart';
import 'package:agrilink_mobile/l10n/labels.dart';
import 'package:agrilink_mobile/shared/data/districts.dart';
import 'package:agrilink_mobile/shared/widgets/crop_icon.dart';
import 'package:agrilink_mobile/shared/widgets/dialogs.dart';
import 'package:agrilink_mobile/shared/widgets/district_picker.dart';
import 'package:agrilink_mobile/shared/widgets/form_fields.dart';
import 'package:agrilink_mobile/shared/widgets/status_badge.dart';
import 'package:agrilink_mobile/shared/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/import_web_icons.dart';
import '../helpers/pump_app.dart';

void main() {
  group('crop catalogue', () {
    test('matches the website order and names', () {
      expect(cropCatalog.first.value, 'Tea');
      expect(cropCatalog.last.value, 'Other');
      expect(cropCatalogEntry('green gram').iconName, 'green_gram');
      expect(cropCatalogEntry('Paddy').iconName, 'rice_grain');
      expect(cropCatalogEntry('Paddy').group, CropGroup.cereals);
    });

    test('an unknown crop gets the generic icon in "other"', () {
      final entry = cropCatalogEntry('Dragon Fruit');
      expect(entry.iconName, 'crop_generic');
      expect(entry.group, CropGroup.other);
      expect(cropCatalogOrder('Dragon Fruit'), cropCatalog.length);
      expect(cropCatalogOrder('Tea'), 0);
    });
  });

  group('icon converter', () {
    test('names assets in snake case', () {
      expect(assetNameFor('TeaLeafIcon'), 'tea_leaf');
      expect(assetNameFor('FarmerAvatar'), 'farmer');
    });

    test('turns JSX attributes into SVG attributes', () {
      expect(
        jsxToSvg('<path strokeWidth={2} strokeLinecap="round" className={x} d="M1 1" />'),
        '<path stroke-width="2" stroke-linecap="round" d="M1 1"/>',
      );
      expect(() => jsxToSvg('<path d={points.join()} />'), throwsFormatException);
    });
  });

  test('safePhotoUrl only allows https, or http to a local backend', () {
    expect(safePhotoUrl('https://res.cloudinary.com/a.jpg'), isNotNull);
    expect(safePhotoUrl('http://10.0.2.2:5266/photos/a.jpg'), isNotNull);
    expect(safePhotoUrl('http://example.com/a.jpg'), isNull);
    expect(safePhotoUrl('javascript:alert(1)'), isNull);
    expect(safePhotoUrl('/relative.jpg'), isNull);
    expect(safePhotoUrl(null), isNull);
  });

  testWidgets('the password checklist ticks rules as they are met', (tester) async {
    await tester.pumpApp(const PasswordChecklist(password: 'abcdefghijkl'));
    final semantics = tester.getSemantics(find.text('At least 12 characters'));
    expect(semantics.label, contains('met'));
    expect(tester.getSemantics(find.text('Contains a number')).label, contains('not met'));
  });

  testWidgets('status badges translate API values', (tester) async {
    await tester.pumpApp(
      Column(
        children: [
          StatusBadge.status(StatusKind.issue, 'AwaitingReview'),
          StatusBadge.status(StatusKind.request, 'Cancelled'),
        ],
      ),
    );
    expect(find.text('Awaiting review'), findsOneWidget);
    expect(find.text('Closed – listing unavailable'), findsOneWidget);
    expect(toneForStatus('Rejected'), BadgeTone.danger);
  });

  testWidgets('avatars and crop icons render from the bundled assets', (tester) async {
    await tester.pumpApp(
      const Row(
        children: [
          UserAvatar(role: Role.buyer, name: 'Nimali'),
          CropIcon('Tomato'),
          CropIcon('Unknown crop'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Nimali'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the district picker lists and picks a district', (tester) async {
    String? picked;
    await tester.pumpApp(
      StatefulBuilder(
        builder: (context, setState) =>
            DistrictPicker(value: picked, onChanged: (value) => setState(() => picked = value)),
      ),
      overrides: [
        districtsProvider.overrideWith((ref) async => ['Ampara', 'Colombo', 'Kandy']),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('District'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'kan');
    await tester.pumpAndSettle();
    expect(find.text('Colombo'), findsNothing);
    await tester.tap(find.text('Kandy'));
    await tester.pumpAndSettle();

    expect(picked, 'Kandy');
    expect(find.text('Kandy'), findsOneWidget);
  });

  testWidgets('the confirm dialog returns the choice', (tester) async {
    bool? result;
    await tester.pumpApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result = await showConfirmDialog(context, title: 'Remove photo?', destructive: true),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
