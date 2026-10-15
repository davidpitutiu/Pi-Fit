import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/domain/exercise_catalog.dart';
import 'package:pi_fit/domain/models.dart';
import 'package:pi_fit/ui/exercise_image.dart';
import 'package:pi_fit/ui/theme.dart';

void main() {
  test('all exercises have logical equipment or training icons', () {
    final icons = <IconData>{};
    for (final exercise in exerciseCatalog) {
      final data = exerciseIconFor(exercise);
      icons.add(data.icon);
      expect(data.label, isNotEmpty, reason: exercise.name);
      expect(data.icon.fontFamily, 'MaterialIcons');
    }
    expect(icons.length, greaterThanOrEqualTo(10));
    expect(
      exerciseIconFor(
        exerciseCatalog.firstWhere((e) => e.id == 'bench_press'),
      ).icon,
      Icons.fitness_center_rounded,
    );
    expect(
      exerciseIconFor(
        exerciseCatalog.firstWhere((e) => e.id == 'stationary_bike'),
      ).icon,
      Icons.directions_bike_rounded,
    );
    expect(
      exerciseIconFor(
        exerciseCatalog.firstWhere((e) => e.id == 'treadmill'),
      ).icon,
      Icons.directions_run_rounded,
    );
    expect(
      exerciseIconFor(
        exerciseCatalog.firstWhere((e) => e.id == 'cable_curl'),
      ).icon,
      Icons.linear_scale_rounded,
    );
  });

  testWidgets(
    'exercise tiles render icons and ignore old photo URLs or anatomy poses',
    (tester) async {
      final semantics = tester.ensureSemantics();
      const exercise = Exercise(
        id: 'bench',
        name: 'Bench press',
        muscle: 'Chest',
        equipment: 'Barbell',
        description: '',
        imageAsset: 'does-not-exist.jpg',
        imageUrl: 'https://example.invalid/photo.jpg',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: piTheme(Brightness.dark),
          home: const Scaffold(
            body: ExerciseImage(
              exercise: exercise,
              width: 342,
              height: 232,
              imageIndex: 999,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.byType(PageView), findsNothing);
      expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
      expect(find.text('FREE WEIGHTS'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Bench press. Free weights exercise icon.'),
        findsOneWidget,
      );
      expect(find.textContaining('Phase'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'icons have distinct light and dark styling and fit compact workout thumbnails',
    (tester) async {
      final exercise = exerciseCatalog.firstWhere((e) => e.id == 'bench_press');
      Future<List<int>> render(Brightness brightness) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: piTheme(brightness),
            home: Scaffold(
              body: RepaintBoundary(
                key: const ValueKey('icon'),
                child: ExerciseImage(
                  exercise: exercise,
                  width: 240,
                  height: 240,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final data = await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('icon')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          return bytes!.buffer.asUint8List().toList();
        });
        return data!;
      }

      final dark = await render(Brightness.dark);
      final light = await render(Brightness.light);
      expect(dark, isNot(orderedEquals(light)));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ExerciseImage(exercise: exercise, width: 80, height: 92),
                ExerciseImage(exercise: exercise, width: 52, height: 58),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.fitness_center_rounded), findsNWidgets(2));
      expect(find.text('FREE WEIGHTS'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
