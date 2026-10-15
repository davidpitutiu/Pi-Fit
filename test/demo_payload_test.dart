import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pi_fit/state/app_store.dart';
import 'package:pi_fit/domain/training_analytics.dart';
import 'package:pi_fit/domain/muscle_focus.dart';
import 'package:pi_fit/services/report_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Demo history restores through AppStore and renders progress/export',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(await SharedPreferences.getInstance());
      await store.load();
      await store.switchAccount('payload-validation-only');
      final payload = Map<String, dynamic>.from(
        jsonDecode(File('firebase/demo-workouts.v1.json').readAsStringSync())
            as Map,
      );
      await store.restoreBackup(
        payload,
        expectedAccountId: 'payload-validation-only',
      );
      final asOf = DateTime(2026, 10, 15, 23, 59);
      expect(
        completedTrainingSessions(store.history, now: asOf),
        hasLength(36),
      );
      expect(store.bodyMeasurements, isEmpty);
      expect(store.profile.weightKg, isNull);
      final counts = <int>[];
      for (final days in [7, 28, 90]) {
        final series = buildTrainingSeries(
          history: store.history,
          exercises: store.exercises,
          days: days,
          now: asOf,
        );
        final focus = buildMuscleFocus(
          history: store.history,
          exercises: store.exercises,
          days: days,
          now: asOf,
        );
        expect(focus.totalPrimarySets, greaterThan(0));
        expect(focus.unattributedSets, 0);
        expect(
          focus.groups.fold<double>(0, (s, g) => s + g.share),
          closeTo(1, 1e-10),
        );
        counts.add(series.workoutCount);
      }
      expect(counts, [3, 12, 36]);
      final report = ReportExportService.create(
        options: ReportOptions(
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 10, 15),
          title: 'TEST DATA · Progress export validation',
        ),
        displayName: store.name,
        history: store.history,
        exercises: store.exercises,
        profile: store.profile,
        now: asOf,
      );
      expect(report.workoutCount, 36);
      expect(report.completedSets, 572);
      expect(report.ratedSets, 572);
      final bytes = await ReportExportService().buildPdf(report, dark: true);
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      print(
        'Payload validated: 36 workouts, 572 sets, 7/28/90 counts=$counts; PDF bytes=${bytes.length}',
      );
    },
  );
}
