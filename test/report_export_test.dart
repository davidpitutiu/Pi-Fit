import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/domain/body_measurement.dart';
import 'package:pi_fit/domain/models.dart';
import 'package:pi_fit/domain/user_profile.dart';
import 'package:pi_fit/services/report_export_service.dart';
import 'package:pi_fit/state/app_store.dart';
import 'package:pi_fit/ui/export_screen.dart';
import 'package:pi_fit/ui/theme.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const barbell = Exercise(
  id: 'bench',
  name: 'Bench press',
  muscle: 'Chest',
  equipment: 'Barbell',
  description: '',
  category: 'Strength',
);
const bodyweight = Exercise(
  id: 'push-up',
  name: 'Push-up',
  muscle: 'Chest',
  equipment: 'Bodyweight',
  description: '',
  category: 'Strength',
);

WorkoutSession logged(
  String id,
  DateTime date, {
  String exerciseId = 'bench',
  double weight = 20,
  double? rpe,
  bool finished = true,
}) => WorkoutSession(
  id: id,
  routineName: 'Training $id',
  startedAt: date,
  finishedAt: finished ? date.add(const Duration(minutes: 10)) : null,
  exercises: [
    WorkoutExercise(
      exerciseId: exerciseId,
      sets: [
        WorkoutSet(weight: weight, reps: 10, completed: true, rpe: rpe),
        const WorkoutSet(weight: 900, reps: 10, completed: false, rpe: 10),
      ],
    ),
  ],
);

class DelayedReportService extends ReportExportService {
  final result = Completer<Uint8List>();
  @override
  Future<Uint8List> buildPdf(
    PiFitReport report, {
    required bool dark,
    ByteData? fontData,
  }) => result.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore(await SharedPreferences.getInstance());
  });

  test(
    'Custom report uses inclusive local dates and canonical valid counts',
    () {
      final history = [
        logged('first', DateTime(2026, 1, 10), rpe: 8),
        logged('last', DateTime(2026, 1, 12, 23, 50), weight: 30, rpe: 6),
        logged('body', DateTime(2026, 1, 11), exerciseId: 'push-up', weight: 0),
        logged('before', DateTime(2026, 1, 9)),
        logged('after', DateTime(2026, 1, 13)),
        logged('unfinished', DateTime(2026, 1, 11), finished: false),
        logged('future', DateTime(2026, 1, 25)),
        logged('first', DateTime(2026, 1, 10), weight: 500),
      ];
      final report = ReportExportService.create(
        options: ReportOptions(
          start: DateTime(2026, 1, 10, 12),
          end: DateTime(2026, 1, 12, 8),
          sections: ReportSection.values.toSet(),
        ),
        displayName: 'David',
        history: history,
        exercises: const [barbell, bodyweight],
        profile: UserProfile(),
        now: DateTime(2026, 1, 20),
        measurements: [
          BodyMeasurement(
            id: 'manual',
            measuredAt: DateTime(2026, 1, 11),
            weightKg: 80,
            heightCm: 180,
          ),
          BodyMeasurement(
            id: 'import',
            measuredAt: DateTime(2026, 1, 12),
            heightCm: 181,
            source: 'health',
            sourceRecordId: 'selected-record',
            sourceName: 'Apple Health',
          ),
          BodyMeasurement(
            id: 'old',
            measuredAt: DateTime(2026, 1, 9),
            weightKg: 81,
          ),
        ],
      );
      expect(report.workoutCount, 3);
      expect(report.completedSets, 3);
      expect(report.activeDays, 3);
      expect(report.volume, 500);
      expect(report.durationMinutes, 30);
      expect(report.ratedSets, 2);
      expect(report.averageRpe, 7);
      expect(report.records.single.weight, 30);
      expect(report.records.single.estimatedOneRepMax, 40);
      expect(report.measurements.map((item) => item.id), ['manual', 'import']);
      expect(
        report.activity.fold<int>(0, (sum, bin) => sum + bin.workoutCount),
        3,
      );
      expect(report.filename, 'Pi-Fit-2026-01-10-2026-01-12.pdf');
      expect(report.options.calendarDays, 3);
    },
  );

  test('No-data and invalid windows never invent sessions or effort', () {
    final options = ReportOptions(
      start: DateTime(2026, 1, 1),
      end: DateTime(2026, 1, 1),
    );
    final report = ReportExportService.create(
      options: options,
      displayName: 'Athlete',
      history: [],
      exercises: const [barbell],
      profile: UserProfile(),
      now: DateTime(2026, 1, 2),
    );
    expect(report.workoutCount, 0);
    expect(report.averageRpe, isNull);
    expect(report.records, isEmpty);
    expect(report.measurements, isEmpty);
    expect(
      () => ReportOptions(start: DateTime(2026, 2), end: DateTime(2026, 1)),
      throwsArgumentError,
    );
    expect(
      () => ReportOptions(
        start: DateTime(2026),
        end: DateTime(2026),
        sections: {},
      ),
      throwsArgumentError,
    );
  });

  test(
    'Designed light and dark PDFs render a multi-page report with Inter',
    () async {
      final history = [
        for (var index = 0; index < 90; index++)
          logged(
            'row-$index',
            DateTime(2026, 1, 1, 8).add(Duration(days: index)),
            rpe: index.isEven ? 7 : null,
          ),
      ];
      final report = ReportExportService.create(
        options: ReportOptions(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 4, 1),
          title: 'My stronger year',
          sections: ReportSection.values.toSet(),
        ),
        displayName: 'David',
        history: history,
        exercises: const [barbell],
        profile: UserProfile(),
        now: DateTime(2026, 5, 1),
      );
      for (final dark in [false, true]) {
        final bytes = await ReportExportService().buildPdf(report, dark: dark);
        expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
        expect(bytes.length, greaterThan(10000));
        // Each journal row is rendered in the PDF's paginated table.
        expect(report.workoutCount, 90);
      }
    },
  );

  Future<void> show(WidgetTester tester, {ReportExportService? service}) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: piTheme(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.3)),
          child: child!,
        ),
        home: ExportScreen(store: store, service: service),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Report controls support all time, sections and themes on a phone',
    (tester) async {
      final now = DateTime.now();
      store.history.addAll([
        logged(
          'recent',
          DateTime(now.year, now.month, now.day - 1),
          exerciseId: store.exercises.first.id,
        ),
        logged(
          'old',
          DateTime(now.year, now.month, now.day - 45),
          exerciseId: store.exercises.first.id,
        ),
      ]);
      await show(tester);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('export-count'))).data,
        startsWith('1 completed workout'),
      );
      final all = find.byKey(const ValueKey('export-period-all'));
      await tester.ensureVisible(all);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('export-count'))).data,
        startsWith('2 completed workouts'),
      );
      final light = find.widgetWithText(ChoiceChip, 'Light');
      await tester.ensureVisible(light);
      await tester.tap(light);
      await tester.pumpAndSettle();
      final measurements = find.byKey(
        const ValueKey('export-section-bodyMeasurements'),
      );
      await tester.ensureVisible(measurements);
      await tester.tap(measurements);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(measurements).value, isTrue);
      await tester.ensureVisible(find.text('Create PDF preview'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Custom report opens the inclusive date-range picker', (
    tester,
  ) async {
    await show(tester);
    final dates = find.text('Custom dates');
    await tester.ensureVisible(dates);
    await tester.tap(dates);
    await tester.pumpAndSettle();
    expect(find.text('Choose report dates'), findsOneWidget);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Custom dates'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Account change discards an in-flight PDF and removes sharing', (
    tester,
  ) async {
    final service = DelayedReportService();
    await show(tester, service: service);
    final create = find.text('Create PDF preview');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pump();
    expect(find.text('Creating your PDF…'), findsOneWidget);
    await tester.runAsync(() => store.switchAccount('another-user'));
    await tester.pumpAndSettle();
    service.result.complete(Uint8List.fromList(ascii.encode('%PDF-test')));
    await tester.pumpAndSettle();
    expect(find.byType(PdfPreview), findsNothing);
    expect(find.text('Share / Download PDF'), findsNothing);
    expect(
      find.text('Your account changed. Create a new report for this account.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
