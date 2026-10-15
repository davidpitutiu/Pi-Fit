import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pi_fit/state/app_store.dart';
import 'package:pi_fit/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore(await SharedPreferences.getInstance());
  });
  test(
    'active workout survives restart and only checked sets enter volume',
    () async {
      await store.startWorkout(store.routines.first);
      await store.updateSet(0, 0, reps: 8, weight: 40, completed: true);
      await store.updateSet(0, 1, reps: 10, weight: 100, completed: false);
      final reopened = AppStore(await SharedPreferences.getInstance());
      await reopened.load();
      expect(reopened.activeSession, isNotNull);
      expect(reopened.activeSession!.volume, 320);
      await reopened.finishWorkout(notes: 'Tehnică bună');
      expect(reopened.activeSession, isNull);
      expect(reopened.history.single.volume, 320);
      expect(reopened.history.single.notes, 'Tehnică bună');
      expect(reopened.history.single.finishedAt, isNotNull);
    },
  );
  test('empty session cannot be saved as a completed workout', () async {
    await store.startEmptyWorkout();
    await expectLater(store.finishWorkout(), throwsStateError);
    expect(store.history, isEmpty);
  });
  test('bulk scheduling creates selected weekdays and deduplicates', () async {
    final start = DateTime.now().add(const Duration(days: 7));
    final count = await store.scheduleBulk(
      routineId: store.routines.first.id,
      start: start,
      weeks: 4,
      weekdays: {1, 3, 5},
      time: const TimeOfDay(hour: 18, minute: 30),
      reminder: false,
    );
    expect(count, 12);
    expect(store.schedule.length, 12);
    expect(
      store.schedule.every((e) => {1, 3, 5}.contains(e.date.weekday)),
      true,
    );
    expect(
      store.schedule.every((e) => e.date.hour == 18 && e.date.minute == 30),
      true,
    );
    final duplicates = await store.scheduleBulk(
      routineId: store.routines.first.id,
      start: start,
      weeks: 4,
      weekdays: {1, 3, 5},
      time: const TimeOfDay(hour: 18, minute: 30),
      reminder: false,
    );
    expect(duplicates, 0);
    final reopened = AppStore(await SharedPreferences.getInstance());
    await reopened.load();
    expect(reopened.schedule.length, 12);
  });
  test('invalid bulk options do not modify the calendar', () async {
    await expectLater(
      store.scheduleBulk(
        routineId: 'missing',
        start: DateTime.now(),
        weeks: 4,
        weekdays: {1},
        time: const TimeOfDay(hour: 18, minute: 0),
        reminder: false,
      ),
      throwsArgumentError,
    );
    expect(store.schedule, isEmpty);
  });
  test('corrupt data is retained for recovery', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('pifit.local.v1', 'invalid-json');
    await store.load();
    expect(store.persistenceError, isNotNull);
    expect(preferences.getString('pifit.recovery.v1'), 'invalid-json');
  });

  test(
    'malformed backup cannot partially change the current profile or workout',
    () async {
      await store.updateProfile('Alex', 'Condiție fizică');
      await store.startWorkout(store.routines.first);
      await store.updateSet(0, 0, reps: 8, weight: 32.5, completed: true);
      final before = store.exportData();
      final preferences = await SharedPreferences.getInstance();
      final persistedBefore = preferences.getString('pifit.local.v1');
      final malformed = {...before, 'name': 'Înlocuit', 'goal': 42};
      await expectLater(store.restoreBackup(malformed), throwsFormatException);
      expect(store.exportData(), before);
      expect(preferences.getString('pifit.local.v1'), persistedBefore);
      await expectLater(store.restoreBackup({}), throwsFormatException);
      expect(store.exportData(), before);
    },
  );

  test(
    'successful restore retains a recovery copy of the previous data',
    () async {
      await store.updateProfile('Profil local', 'Controlul greutății');
      await store.startWorkout(store.routines.first);
      final original = store.exportData();
      final backup = AppStore(
        await SharedPreferences.getInstance(),
      ).exportData();
      backup['name'] = 'Profil restaurat';
      await store.restoreBackup(backup);
      expect(store.name, 'Profil restaurat');
      expect(store.activeSession, isNull);
      final preferences = await SharedPreferences.getInstance();
      expect(
        jsonDecode(preferences.getString('pifit.before_restore.v1')!),
        original,
      );
      final reopened = AppStore(preferences);
      await reopened.load();
      expect(reopened.name, 'Profil restaurat');
      expect(reopened.persistenceError, isNull);
    },
  );

  test(
    'blank names and unknown goals are normalized before opening the account',
    () async {
      final backup = store.exportData();
      backup['name'] = '   ';
      backup['goal'] = 'Un obiectiv dintr-o versiune veche';
      await store.restoreBackup(backup);
      expect(store.name, 'Atlet');
      expect(store.goal, AppStore.profileGoals.first);
      await store.updateProfile('  Radu  ', '');
      expect(store.name, 'Radu');
      expect(store.goal, AppStore.profileGoals.first);
    },
  );

  test(
    'unknown historical exercise references remain readable and recoverable',
    () async {
      final backup = store.exportData();
      final start = DateTime.now().subtract(const Duration(hours: 2));
      backup['history'] = [
        WorkoutSession(
          id: 'old-session',
          routineName: 'Rutina veche',
          startedAt: start,
          finishedAt: start.add(const Duration(minutes: 30)),
          exercises: const [
            WorkoutExercise(
              exerciseId: 'removed-exercise',
              sets: [WorkoutSet(reps: 10, weight: 20, completed: true)],
            ),
          ],
        ).toJson(),
      ];
      await store.restoreBackup(backup);
      expect(store.exerciseById('removed-exercise').name, 'Exercițiu salvat');
      expect(
        store.history.single.exercises.single.exerciseId,
        'removed-exercise',
      );
      expect(store.totalVolume, 200);
      await store.startEmptyWorkout();
      await expectLater(
        store.addExercise('removed-exercise'),
        throwsArgumentError,
      );
      expect(store.activeSession!.exercises, isEmpty);
    },
  );

  test('invalid set values cannot replace the current workout data', () async {
    await store.startWorkout(store.routines.first);
    final before = store.exportData();
    await expectLater(
      store.updateSet(0, 0, weight: double.nan),
      throwsArgumentError,
    );
    await expectLater(store.updateSet(0, 0, weight: -1), throwsArgumentError);
    await expectLater(store.updateSet(0, 0, reps: 0), throwsArgumentError);
    expect(store.exportData(), before);
    final backup = jsonDecode(jsonEncode(before)) as Map<String, dynamic>;
    (((backup['active'] as Map)['exercises'] as List).first as Map)['sets'] = [
      {'reps': -1, 'weight': 10, 'completed': true},
    ];
    await expectLater(store.restoreBackup(backup), throwsFormatException);
    expect(store.exportData(), before);
  });

  test(
    'unfinished sessions cannot enter the completed workout history',
    () async {
      await store.startWorkout(store.routines.first);
      await store.updateSet(0, 0, completed: true);
      final before = store.exportData();
      final backup = {
        ...before,
        'history': [store.activeSession!.toJson()],
        'active': null,
      };
      await expectLater(store.restoreBackup(backup), throwsFormatException);
      expect(store.exportData(), before);
      expect(store.history, isEmpty);
    },
  );

  test(
    'reminder failure keeps the calendar and disables unscheduled reminder flags',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await expectLater(
        store.scheduleBulk(
          routineId: store.routines.first.id,
          start: DateTime.now().add(const Duration(days: 7)),
          weeks: 1,
          weekdays: {1, 3, 5},
          time: const TimeOfDay(hour: 18, minute: 0),
          reminder: true,
        ),
        throwsStateError,
      );
      expect(store.schedule, hasLength(3));
      expect(store.schedule.every((event) => !event.reminder), isTrue);
      final reopened = AppStore(await SharedPreferences.getInstance());
      await reopened.load();
      expect(reopened.schedule, hasLength(3));
      expect(reopened.schedule.every((event) => !event.reminder), isTrue);
    },
  );

  test(
    'restoring reminders on an unsupported device still keeps the imported plan',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final backup = store.exportData();
      backup['schedule'] = [
        ScheduledWorkout(
          id: 'future-1',
          routineId: store.routines.first.id,
          date: DateTime.now().add(const Duration(days: 3)),
        ).toJson(),
      ];
      await expectLater(store.restoreBackup(backup), throwsStateError);
      expect(store.schedule.single.id, 'future-1');
      expect(store.schedule.single.reminder, isFalse);
      final reopened = AppStore(await SharedPreferences.getInstance());
      await reopened.load();
      expect(reopened.schedule.single.reminder, isFalse);
    },
  );

  test(
    'repeated corrupt loads do not overwrite a previous recovery copy',
    () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('pifit.recovery.v1', 'original-recovery');
      await preferences.setString('pifit.local.v1', 'new-corrupt-json');
      await store.load();
      expect(preferences.getString('pifit.recovery.v1'), 'original-recovery');
      final keys = preferences.getKeys().where(
        (key) => key.startsWith('pifit.recovery.v1.'),
      );
      expect(keys, hasLength(1));
      expect(preferences.getString(keys.single), 'new-corrupt-json');
    },
  );
}
