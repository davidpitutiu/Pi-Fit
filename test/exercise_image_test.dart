import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/domain/exercise_catalog.dart';
import 'package:pi_fit/domain/models.dart';
import 'package:pi_fit/ui/exercise_image.dart';
import 'package:pi_fit/ui/exercise_illustration.dart';
import 'package:pi_fit/ui/theme.dart';

void main() {
  test(
    'all exercises map to an original movement family with supported poses',
    () {
      final families = <ExerciseMovementFamily>{};
      for (final exercise in exerciseCatalog) {
        families.add(exerciseMovementFamily(exercise));
        expect(exerciseIllustrationPoseCount(exercise), inInclusiveRange(1, 2));
      }
      expect(families.length, greaterThanOrEqualTo(20));
      expect(
        exerciseMovementFamily(
          const Exercise(
            id: 'throw',
            name: 'Overhead Medicine Ball Throw',
            muscle: 'Shoulders',
            equipment: 'Medicine ball',
            description: '',
          ),
        ),
        ExerciseMovementFamily.overheadPress,
      );
      expect(
        exerciseMovementFamily(
          exerciseCatalog.firstWhere((e) => e.id == 'leg_curl'),
        ),
        ExerciseMovementFamily.kneeFlexion,
      );
      expect(
        exerciseMovementFamily(
          exerciseCatalog.firstWhere((e) => e.id == 'bench_press'),
        ),
        ExerciseMovementFamily.benchPress,
      );
      expect(
        exerciseMovementFamily(
          exerciseCatalog.firstWhere((e) => e.id == 'stationary_bike'),
        ),
        ExerciseMovementFamily.cycle,
      );
      expect(
        exerciseIllustrationPoseCount(
          exerciseCatalog.firstWhere((e) => e.id == 'plank'),
        ),
        1,
      );
    },
  );

  testWidgets(
    'vector artwork replaces photo URLs and assets without network image providers',
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
            body: ExerciseImage(exercise: exercise, width: 342, height: 232),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.byType(ExerciseIllustration), findsOneWidget);
      expect(find.text('Horizontal press'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(
            r'Bench press\. Horizontal press movement-family illustration\. Phase 1 of 2',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'start and finish vectors render different poses and support both themes at thumbnail size',
    (tester) async {
      final exercise = exerciseCatalog.firstWhere((e) => e.id == 'bench_press');
      Future<List<int>> render(int pose, Brightness brightness) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: piTheme(brightness),
            home: Scaffold(
              body: RepaintBoundary(
                key: const ValueKey('art'),
                child: ExerciseImage(
                  exercise: exercise,
                  width: 240,
                  height: 240,
                  imageIndex: pose,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final data = await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('art')),
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

      final start = await render(0, Brightness.dark);
      final finish = await render(1, Brightness.dark);
      expect(start, isNot(orderedEquals(finish)));
      final light = await render(1, Brightness.light);
      expect(finish, isNot(orderedEquals(light)));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ExerciseImage(exercise: exercise, width: 80, height: 92),
                ExerciseImage(
                  exercise: exercise,
                  width: 52,
                  height: 58,
                  imageIndex: 1,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
