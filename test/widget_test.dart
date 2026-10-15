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
    expect(find.text('Mișcare cu sens.'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Exerciții').last);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Progres').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Scor de consecvență'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('Conectează-te'), findsOneWidget);
    expect(find.text('Creează un cont'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Acasă').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pi Coach').first);
    await tester.pumpAndSettle();
    expect(find.text('Coach local · adaptat profilului'), findsOneWidget);
    await store.setTheme(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
