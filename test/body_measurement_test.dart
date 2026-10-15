import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/domain/body_measurement.dart';
import 'package:pi_fit/domain/models.dart';

void main() {
  test(
    'explicit measurements retain timestamp and Health provenance through JSON',
    () {
      final date = DateTime.now().subtract(const Duration(days: 2));
      final value = BodyMeasurement(
        id: 'body-1',
        measuredAt: date,
        weightKg: 82.5,
        heightCm: 181,
        source: 'health',
        sourceRecordId: 'apple/source/uuid',
        sourceName: 'Apple Health',
      );
      final restored = BodyMeasurement.fromJson(value.toJson());
      expect(restored.toJson(), value.toJson());
      expect(restored.measuredAt, date);
      expect(restored.sourceRecordId, 'apple/source/uuid');
    },
  );

  test(
    'invalid values, future timestamps and missing Health identity are rejected',
    () {
      final valid = BodyMeasurement(
        id: 'valid',
        measuredAt: DateTime.now(),
        weightKg: 80,
      ).toJson();
      for (final invalid in [
        {...valid, 'weightKg': double.nan},
        {...valid, 'weightKg': 351},
        {...valid, 'weightKg': 24},
        {...valid, 'heightCm': 99},
        {...valid, 'weightKg': null, 'heightCm': null},
        {
          ...valid,
          'measuredAt': DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(),
        },
        {...valid, 'measuredAt': 'invalid'},
        {...valid, 'measuredAt': '1800-01-01T00:00:00.000'},
        {...valid, 'source': 'health', 'sourceRecordId': null},
        {...valid, 'weightKg': '80'},
        {...valid, 'source': 'invented'},
      ]) {
        expect(() => BodyMeasurement.fromJson(invalid), throwsFormatException);
      }
    },
  );

  test(
    'optional reported effort survives serialization, can clear, and does not affect volume',
    () {
      const set = WorkoutSet(reps: 8, weight: 60, completed: true, rpe: 8.5);
      expect(WorkoutSet.fromJson(set.toJson()).rpe, 8.5);
      expect(set.volume, 480);
      expect(set.copyWith(rpe: 7).rpe, 7);
      expect(set.copyWith(clearRpe: true).rpe, isNull);
      expect(
        WorkoutSet.fromJson({'reps': 8, 'weight': 60, 'completed': true}).rpe,
        isNull,
      );
      for (final invalid in [0, 10.1, double.nan, 'hard']) {
        expect(
          () => WorkoutSet.fromJson({...set.toJson(), 'rpe': invalid}),
          throwsFormatException,
        );
      }
    },
  );
}
