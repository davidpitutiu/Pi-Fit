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
    expect(find.text('Move with purpose.'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Exercises').last);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Consistency score'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pi Coach').first);
    await tester.pumpAndSettle();
    expect(find.text('Local coach · tailored to you'), findsOneWidget);
    expect(find.text('A plan that\nfits your life.'), findsOneWidget);
    await store.setTheme(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
