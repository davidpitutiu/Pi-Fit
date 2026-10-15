import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pi_fit/main.dart';
import 'package:pi_fit/state/app_store.dart';

void main() {
  testWidgets('Pi Fit navigation works on a narrow phone in both themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(PiFitApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Mai puternic.\nÎn fiecare zi.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Exerciții').last);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Pi Coach').last);
    await tester.pumpAndSettle();
    expect(find.text('Recomandări locale · AI neconectat'), findsOneWidget);
    await store.setTheme(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
