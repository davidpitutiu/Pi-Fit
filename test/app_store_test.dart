import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Direct platform substitution is needed to simulate failed disk writes.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:pi_fit/state/app_store.dart';
import 'package:pi_fit/domain/models.dart';
import 'package:pi_fit/domain/user_profile.dart';
import 'package:pi_fit/services/notification_service.dart';

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

  test(
    'old v1 backups migrate without deleting history or preferences',
    () async {
      await store.startWorkout(store.routines.first);
      await store.updateSet(0, 0, reps: 10, weight: 35, completed: true);
      await store.finishWorkout(notes: 'Păstrat din backup');
      final legacy = store.exportData()
        ..remove('profile')
        ..remove('favoriteExerciseIds');
      await store.restoreBackup(legacy);
      expect(store.profile.sessionsPerWeek, 3);
      expect(store.profile.coachConsent, isFalse);
      expect(store.favoriteExerciseIds, isEmpty);
      expect(store.history.single.notes, 'Păstrat din backup');
      expect(store.history.single.volume, 350);
    },
  );

  test(
    'detailed profile and favorites persist with atomic account fields',
    () async {
      final profile = UserProfile(
        age: 32,
        heightCm: 182,
        weightKg: 85.5,
        sessionsPerWeek: 4,
        sessionMinutes: 45,
        experience: 'Intermediar',
        equipment: ['Gantere', 'Cablu'],
        preferredDays: [1, 2, 4, 6],
        limitations: 'Prefer exerciții fără sărituri',
        coachConsent: true,
      );
      await store.updateUserProfile(
        profile,
        newName: '  David  ',
        newGoal: 'Condiție fizică',
      );
      final id = store.exercises.first.id;
      await store.setExerciseFavorite(id, true);
      final reopened = AppStore(await SharedPreferences.getInstance());
      await reopened.load();
      expect(reopened.profile.toJson(), profile.toJson());
      expect(reopened.name, 'David');
      expect(reopened.goal, 'Condiție fizică');
      expect(reopened.favoriteExerciseIds, {id});
      expect(
        () => reopened.favoriteExerciseIds.add('other'),
        throwsUnsupportedError,
      );
      await reopened.setExerciseFavorite(id, false);
      expect(reopened.favoriteExerciseIds, isEmpty);
      await expectLater(
        reopened.setExerciseFavorite('not-real', true),
        throwsArgumentError,
      );
    },
  );

  test(
    'invalid detailed profile import leaves existing account unchanged',
    () async {
      await store.updateUserProfile(
        UserProfile(age: 30, sessionsPerWeek: 4),
        newName: 'David',
      );
      final before = store.exportData();
      final invalid = {
        ...before,
        'name': 'Înlocuit',
        'profile': {...store.profile.toJson(), 'sessionsPerWeek': 50},
      };
      await expectLater(store.restoreBackup(invalid), throwsFormatException);
      expect(store.exportData(), before);
      final duplicateFavorites = {
        ...before,
        'favoriteExerciseIds': [
          store.exercises.first.id,
          store.exercises.first.id,
        ],
      };
      await expectLater(
        store.restoreBackup(duplicateFavorites),
        throwsFormatException,
      );
      expect(store.exportData(), before);
    },
  );

  test(
    'coach context is personalized and omits free-text without consent',
    () async {
      await store.updateUserProfile(
        UserProfile(
          age: 29,
          sessionsPerWeek: 4,
          experience: 'Intermediar',
          limitations: 'text-personal-restrictii',
        ),
        newName: 'nume-personal-secret',
      );
      await store.startWorkout(store.routines.first);
      await store.updateSet(0, 0, reps: 8, weight: 60, completed: true);
      await store.finishWorkout(notes: 'text-personal-notite');
      final encoded = store.coachContext;
      final context = jsonDecode(encoded) as Map<String, dynamic>;
      expect((context['profile'] as Map)['sessionsPerWeek'], 4);
      expect((context['statistics'] as Map)['completedSets'], 1);
      expect(context['recentSessions'], hasLength(1));
      final session = (context['recentSessions'] as List).single as Map;
      final exercise = (session['exercises'] as List).first as Map;
      expect((exercise['sets'] as List).single, {
        'reps': 8,
        'weight': 60.0,
        'completed': true,
      });
      expect(encoded, isNot(contains('text-personal-restrictii')));
      expect(encoded, isNot(contains('text-personal-notite')));
      expect(encoded, isNot(contains('nume-personal-secret')));
      expect(store.localCoachContext, contains('text-personal-restrictii'));
      expect(store.localCoachContext, contains('text-personal-notite'));
      await store.updateUserProfile(store.profile.copyWith(coachConsent: true));
      final consented = store.coachContext;
      expect(consented, contains('text-personal-restrictii'));
      expect(consented, contains('text-personal-notite'));
      await store.updateUserProfile(
        store.profile.copyWith(coachConsent: false),
      );
      expect(store.coachContext, isNot(contains('text-personal-restrictii')));
    },
  );

  test(
    'large coach context remains valid bounded JSON with newest sessions',
    () async {
      await store.updateUserProfile(UserProfile(coachConsent: true));
      final now = DateTime.now();
      store.history = List.generate(
        20,
        (index) => WorkoutSession(
          id: 'history-$index',
          routineName: 'Rutina $index',
          startedAt: now.subtract(Duration(days: index + 1)),
          finishedAt: now
              .subtract(Duration(days: index + 1))
              .add(const Duration(hours: 1)),
          notes: List.filled(400, 'a').join(),
          exercises: List.generate(
            6,
            (exerciseIndex) => WorkoutExercise(
              exerciseId: store.exercises[exerciseIndex].id,
              sets: List.generate(
                10,
                (_) => const WorkoutSet(reps: 10, weight: 50, completed: true),
              ),
            ),
          ),
        ),
      );
      final encoded = store.coachContext;
      expect(encoded.length, lessThanOrEqualTo(10000));
      final context = jsonDecode(encoded) as Map;
      final recent = context['recentSessions'] as List;
      expect(recent, isNotEmpty);
      expect(recent.length, lessThanOrEqualTo(8));
      expect((recent.first as Map)['routineName'], 'Rutina 0');
    },
  );

  test(
    'guest and multiple accounts retain isolated profile, favorites and active workout',
    () async {
      await store.updateUserProfile(UserProfile(age: 30), newName: 'Guest');
      await store.startWorkout(store.routines.first);
      await store.updateSet(0, 0, weight: 25, completed: true);
      final guest = store.exportData();
      await store.switchAccount('account-a');
      expect(store.accountId, 'account-a');
      expect(store.name, 'Atlet');
      expect(store.activeSession, isNull);
      expect(store.profile.age, isNull);
      await store.updateUserProfile(UserProfile(age: 40), newName: 'Account A');
      await store.setExerciseFavorite(store.exercises.first.id, true);
      await store.startWorkout(store.routines.last);
      final accountA = store.exportData();
      await store.switchAccount('account-b');
      expect(store.name, 'Atlet');
      expect(store.favoriteExerciseIds, isEmpty);
      expect(store.activeSession, isNull);
      await store.updateProfile('Account B', 'Condiție fizică');
      await store.switchAccount('account-a');
      expect(store.exportData(), accountA);
      await store.switchAccount(null);
      expect(store.accountId, isNull);
      expect(store.exportData(), guest);
      await store.switchAccount('account-b');
      expect(store.name, 'Account B');
    },
  );

  test(
    'overlapping account switches are serialized and same account is a no-op',
    () async {
      final first = store.switchAccount('account-a');
      final second = store.switchAccount('account-b');
      await Future.wait([first, second]);
      expect(store.accountId, 'account-b');
      await store.updateProfile('B saved', 'Condiție fizică');
      final before = store.exportData();
      await store.switchAccount('account-b');
      expect(store.exportData(), before);
    },
  );

  test(
    'corrupt target is preserved without replacing current account or blocking later switches',
    () async {
      final preferences = await SharedPreferences.getInstance();
      await store.updateProfile('Guest preserved', 'Condiție fizică');
      final before = store.exportData();
      await preferences.setString('pifit.account.broken.v1', 'corrupt-target');
      await expectLater(store.switchAccount('broken'), throwsFormatException);
      expect(store.accountId, isNull);
      expect(store.exportData(), before);
      expect(
        preferences.getString('pifit.account.broken.v1'),
        'corrupt-target',
      );
      expect(
        preferences.getString('pifit.account.broken.recovery.v1'),
        'corrupt-target',
      );
      await store.switchAccount('working');
      expect(store.accountId, 'working');
      expect(store.name, 'Atlet');
    },
  );

  test(
    'failed target write rolls back cache and leaves current account intact',
    () async {
      final preferences = await SharedPreferences.getInstance();
      await store.updateProfile('Guest preserved', 'Condiție fizică');
      final before = store.exportData();
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _FailingPreferences(
        'pifit.account.failed.v1',
      );
      addTearDown(
        () => SharedPreferencesStorePlatform.instance = originalPlatform,
      );
      await expectLater(store.switchAccount('failed'), throwsStateError);
      expect(store.accountId, isNull);
      expect(store.exportData(), before);
      expect(preferences.getString('pifit.account.failed.v1'), isNull);
    },
  );

  test(
    'failed recovery write never overwrites corrupt source or current user',
    () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('pifit.account.broken.v1', 'keep-source');
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _FailingPreferences(
        'pifit.account.broken.recovery.v1',
      );
      addTearDown(
        () => SharedPreferencesStorePlatform.instance = originalPlatform,
      );
      await expectLater(store.switchAccount('broken'), throwsFormatException);
      expect(store.accountId, isNull);
      expect(preferences.getString('pifit.account.broken.v1'), 'keep-source');
    },
  );

  test(
    'account reminder failures preserve calendar without enabled flags',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final preferences = await SharedPreferences.getInstance();
      final backup = store.exportData();
      backup['schedule'] = [
        ScheduledWorkout(
          id: 'account-reminder',
          routineId: store.routines.first.id,
          date: DateTime.now().add(const Duration(days: 7)),
          reminder: true,
        ).toJson(),
      ];
      await preferences.setString(
        'pifit.account.reminders.v1',
        jsonEncode(backup),
      );
      await store.switchAccount('reminders');
      expect(store.accountId, 'reminders');
      expect(store.schedule.single.reminder, isFalse);
      expect(store.persistenceError, isNotNull);
      final persisted =
          jsonDecode(preferences.getString('pifit.account.reminders.v1')!)
              as Map;
      expect(
        ((persisted['schedule'] as List).single as Map)['reminder'],
        isFalse,
      );
    },
  );

  test(
    'explicit guest import preserves both profiles and is idempotent',
    () async {
      final routine = Routine(
        id: 'my-routine',
        name: 'Guest routine',
        subtitle: '',
        exercises: [RoutineExercise(exerciseId: store.exercises.first.id)],
        estimatedMinutes: 45,
        category: 'Personalizat',
      );
      await store.saveRoutine(routine);
      await store.startWorkout(routine);
      await store.updateSet(0, 0, reps: 10, weight: 20, completed: true);
      await store.finishWorkout();
      await store.setExerciseFavorite(store.exercises.first.id, true);
      await store.scheduleBulk(
        routineId: routine.id,
        start: DateTime.now().add(const Duration(days: 7)),
        weeks: 1,
        weekdays: {1},
        time: const TimeOfDay(hour: 18, minute: 0),
        reminder: false,
      );
      final preferences = await SharedPreferences.getInstance();
      final guestOriginal = preferences.getString('pifit.local.v1');
      expect(store.hasGuestJournal, isTrue);
      await store.switchAccount('import-target');
      await store.updateUserProfile(
        UserProfile(age: 42, sessionsPerWeek: 4),
        newName: 'Account name',
        newGoal: 'Condiție fizică',
      );
      await store.startEmptyWorkout();
      final activeId = store.activeSession!.id;
      await store.importGuestJournal();
      expect(store.history.length, 1);
      expect(store.customRoutines.single.name, 'Guest routine');
      expect(store.schedule.length, 1);
      expect(store.favoriteExerciseIds, {store.exercises.first.id});
      expect(store.name, 'Account name');
      expect(store.goal, 'Condiție fizică');
      expect(store.profile.age, 42);
      expect(store.profile.sessionsPerWeek, 4);
      expect(store.activeSession!.id, activeId);
      expect(preferences.getString('pifit.local.v1'), guestOriginal);
      final imported = store.exportData();
      await store.importGuestJournal();
      expect(store.exportData(), imported);
      expect(preferences.getString('pifit.local.v1'), guestOriginal);
    },
  );

  test(
    'guest routine ID collisions remap calendar references deterministically',
    () async {
      final guestRoutine = Routine(
        id: 'same-id',
        name: 'Guest program',
        subtitle: '',
        exercises: [RoutineExercise(exerciseId: store.exercises.first.id)],
        estimatedMinutes: 40,
        category: 'Personalizat',
      );
      await store.saveRoutine(guestRoutine);
      await store.scheduleBulk(
        routineId: guestRoutine.id,
        start: DateTime.now().add(const Duration(days: 7)),
        weeks: 1,
        weekdays: {2},
        time: const TimeOfDay(hour: 18, minute: 0),
        reminder: false,
      );
      await store.switchAccount('target');
      await store.saveRoutine(guestRoutine.copyWith(name: 'Account program'));
      await store.importGuestJournal();
      expect(store.customRoutines.length, 2);
      expect(store.routineById('same-id')!.name, 'Account program');
      final copied = store.customRoutines.singleWhere(
        (r) => r.name == 'Guest program',
      );
      expect(copied.id, isNot('same-id'));
      expect(store.schedule.single.routineId, copied.id);
      await store.importGuestJournal();
      expect(store.customRoutines.length, 2);
      expect(store.schedule.length, 1);
      expect(store.schedule.single.routineId, copied.id);
    },
  );

  test('guest import requires account and valid journal', () async {
    await expectLater(store.importGuestJournal(), throwsStateError);
    expect(store.hasGuestJournal, isFalse);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('pifit.local.v1', 'corrupt');
    expect(store.hasGuestJournal, isFalse);
    await store.switchAccount('target');
    final before = store.exportData();
    await expectLater(store.importGuestJournal(), throwsStateError);
    expect(store.exportData(), before);
    expect(preferences.getString('pifit.local.v1'), 'corrupt');
  });
  test('stale cloud backup cannot restore into another account', () async {
    await store.switchAccount('alice');
    await store.updateProfile('Alice', store.goal);
    final aliceBackup = {...store.exportData(), 'name': 'Alice cloud'};
    await store.switchAccount('bob');
    await store.updateProfile('Bob', store.goal);
    final bobBefore = store.exportData();
    await expectLater(
      store.restoreBackup(aliceBackup, expectedAccountId: 'alice'),
      throwsStateError,
    );
    expect(store.accountId, 'bob');
    expect(store.exportData(), bobBefore);
    expect(
      jsonDecode(
        store.preferences.getString('pifit.account.alice.v1')!,
      )['name'],
      'Alice',
    );
  });

  test('restore captures scope before a queued account change', () async {
    await store.switchAccount('alice');
    final backup = {...store.exportData(), 'name': 'Alice cloud'};
    final changing = store.switchAccount('bob');
    final rejected = expectLater(store.restoreBackup(backup), throwsStateError);
    await changing;
    await rejected;
    expect(store.accountId, 'bob');
    expect(store.name, 'Atlet');
  });

  test(
    'account switch waits for complete restore recovery and write',
    () async {
      await store.switchAccount('alice');
      final backup = {...store.exportData(), 'name': 'Alice restored'};
      final original = SharedPreferencesStorePlatform.instance;
      final delayed = _DelayedPreferences(
        'pifit.account.alice.before_restore.v1',
      );
      SharedPreferencesStorePlatform.instance = delayed;
      addTearDown(() => SharedPreferencesStorePlatform.instance = original);
      final restoring = store.restoreBackup(backup, expectedAccountId: 'alice');
      await delayed.entered.future;
      final switching = store.switchAccount('bob');
      await Future<void>.delayed(Duration.zero);
      expect(store.accountId, 'alice');
      delayed.release.complete();
      await restoring;
      await switching;
      expect(store.accountId, 'bob');
      expect(store.name, 'Atlet');
      expect(
        jsonDecode(
          store.preferences.getString('pifit.account.alice.v1')!,
        )['name'],
        'Alice restored',
      );
      expect(
        jsonDecode(
          store.preferences.getString('pifit.account.bob.v1')!,
        )['name'],
        'Atlet',
      );
    },
  );

  test(
    'late notification permission cancels old-account reminder without touching new calendar',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const notifications = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      const timezone = MethodChannel('flutter_timezone');
      final permissionEntered = Completer<void>();
      final permissionRelease = Completer<bool>();
      final scheduledIds = <int>[];
      final cancelledIds = <int>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(timezone, (_) async => 'UTC');
      messenger.setMockMethodCallHandler(notifications, (call) async {
        if (call.method == 'initialize') return true;
        if (call.method == 'requestNotificationsPermission') {
          if (permissionEntered.isCompleted) return true;
          permissionEntered.complete();
          return permissionRelease.future;
        }
        if (call.method == 'zonedSchedule') {
          scheduledIds.add((call.arguments as Map)['id'] as int);
        }
        if (call.method == 'cancel') {
          cancelledIds.add((call.arguments as Map)['id'] as int);
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(timezone, null);
        messenger.setMockMethodCallHandler(notifications, null);
      });
      await store.switchAccount('alice');
      final pending = store.scheduleBulk(
        routineId: store.routines.first.id,
        start: DateTime.now().add(const Duration(days: 7)),
        weeks: 1,
        weekdays: {1},
        time: const TimeOfDay(hour: 18, minute: 0),
        reminder: true,
      );
      await permissionEntered.future;
      final eventId = store.schedule.single.id;
      final bobData = store.exportData();
      bobData['name'] = 'Bob';
      bobData['schedule'] = [
        store.schedule.single.copyWith(reminder: true).toJson(),
      ];
      await store.preferences.setString(
        'pifit.account.bob.v1',
        jsonEncode(bobData),
      );
      await store.switchAccount('bob');
      final bobBefore = store.exportData();
      permissionRelease.complete(true);
      await pending;
      expect(store.accountId, 'bob');
      expect(store.exportData(), bobBefore);
      final aliceNotification = NotificationService.stableId(
        'account/alice/$eventId',
      );
      final bobNotification = NotificationService.stableId(
        'account/bob/$eventId',
      );
      final legacyNotification = NotificationService.stableId(eventId);
      expect(scheduledIds, containsAll([aliceNotification, bobNotification]));
      expect(aliceNotification, isNot(bobNotification));
      expect(cancelledIds, contains(aliceNotification));
      expect(cancelledIds, isNot(contains(bobNotification)));
      expect(cancelledIds, contains(legacyNotification));
      expect(store.schedule.single.id, eventId);
      expect(store.schedule.single.reminder, isTrue);
      final alice =
          jsonDecode(store.preferences.getString('pifit.account.alice.v1')!)
              as Map;
      expect(((alice['schedule'] as List).single as Map)['reminder'], isFalse);
      await store.removeScheduled(eventId);
      expect(cancelledIds, contains(bobNotification));
      expect(store.schedule, isEmpty);
    },
  );
}

class _FailingPreferences extends InMemorySharedPreferencesStore {
  _FailingPreferences(this.failedKey) : super.empty();
  final String failedKey;
  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      key == 'flutter.$failedKey'
      ? Future.value(false)
      : super.setValue(valueType, key, value);
}

class _DelayedPreferences extends InMemorySharedPreferencesStore {
  _DelayedPreferences(this.heldKey) : super.empty();
  final String heldKey;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.$heldKey' && !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return super.setValue(valueType, key, value);
  }
}
