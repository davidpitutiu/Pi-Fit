import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pi_fit/state/app_store.dart';
import 'package:pi_fit/ui/body_measurements_screen.dart';
import 'package:pi_fit/ui/theme.dart';

Future<AppStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance());
}

Future<void> _pump(WidgetTester tester, AppStore store) async {
  tester.view.physicalSize = const Size(320, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: piTheme(Brightness.dark),
      home: BodyMeasurementsScreen(store: store),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'manual body measurements save optional fields and survive reloading',
    (tester) async {
      final store = await _store();
      await _pump(tester, store);
      await tester.tap(find.byKey(const Key('add-measurement')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('measurement-weight')),
        '82,5',
      );
      await tester.enterText(
        find.byKey(const Key('measurement-height')),
        '181',
      );
      await tester.ensureVisible(find.byKey(const Key('save-measurement')));
      await tester.tap(find.byKey(const Key('save-measurement')));
      await tester.pumpAndSettle();
      expect(store.bodyMeasurements, hasLength(1));
      expect(store.bodyMeasurements.single.weightKg, 82.5);
      expect(store.bodyMeasurements.single.heightCm, 181);
      expect(store.profile.weightKg, 82.5);
      expect(store.profile.heightCm, 181);
      final restored = AppStore(store.preferences);
      await restored.load();
      expect(restored.bodyMeasurements.single.weightKg, 82.5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'measurement form rejects empty and out-of-range values without records',
    (tester) async {
      final store = await _store();
      await _pump(tester, store);
      await tester.tap(find.byKey(const Key('add-measurement')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('save-measurement')));
      await tester.tap(find.byKey(const Key('save-measurement')));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter at least your weight or height.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('measurement-weight')),
        '999',
      );
      await tester.ensureVisible(find.byKey(const Key('save-measurement')));
      await tester.tap(find.byKey(const Key('save-measurement')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a value between 25 and 350.'), findsOneWidget);
      expect(store.bodyMeasurements, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'period selector charts only recorded values and restores older history',
    (tester) async {
      final store = await _store();
      await store.recordBodyMeasurement(
        weightKg: 80,
        measuredAt: DateTime.now().subtract(const Duration(days: 60)),
      );
      final oldId = store.bodyMeasurements.single.id;
      await store.recordBodyMeasurement(
        weightKg: 82,
        measuredAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await _pump(tester, store);
      expect(find.byKey(ValueKey('body-record-$oldId')), findsNothing);
      expect(find.text('First measurement in this period'), findsOneWidget);
      await tester.ensureVisible(find.text('90 days'));
      await tester.tap(find.text('90 days'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('body-record-$oldId')), findsOneWidget);
      expect(find.text('2 measurements · change +2 kg'), findsOneWidget);
      expect(find.byKey(const Key('weight-chart')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an open measurement editor cannot save into a changed account', (
    tester,
  ) async {
    final store = await _store();
    await store.switchAccount('account-a');
    await _pump(tester, store);
    await tester.tap(find.byKey(const Key('add-measurement')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('measurement-weight')), '80');
    await store.switchAccount('account-b');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-measurement')));
    await tester.tap(find.byKey(const Key('save-measurement')));
    await tester.pumpAndSettle();
    expect(store.accountId, 'account-b');
    expect(store.bodyMeasurements, isEmpty);
    expect(find.text('Measurement saved.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
