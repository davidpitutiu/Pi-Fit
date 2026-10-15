import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pi_fit/services/health_service.dart';
import 'package:pi_fit/state/app_store.dart';
import 'package:pi_fit/ui/health_screen.dart';
import 'package:pi_fit/ui/theme.dart';

final healthNow = DateTime(2026, 10, 15, 12);

class FakeHealthSource implements HealthDataSource {
  int configureCalls = 0;
  int authorizationCalls = 0;
  int motionRequests = 0;
  int readCalls = 0;
  int stepCalls = 0;
  bool motionGranted = true;
  bool authorizationResult = true;
  bool unknownReadAccess = false;
  HealthConnectSdkStatus status = HealthConnectSdkStatus.sdkAvailable;
  final granted = HealthService.readTypes.toSet();
  final records = <HealthDataType, List<HealthDataPoint>>{};
  final stepIntervals = <(DateTime, DateTime)>[];
  Completer<int?>? pendingSteps;

  @override
  Future<void> configure() async {
    configureCalls++;
  }

  @override
  Future<HealthConnectSdkStatus?> androidAvailability() async => status;
  @override
  Future<bool?> hasReadAccess(List<HealthDataType> types) async =>
      unknownReadAccess ? null : types.every(granted.contains);
  @override
  Future<bool> requestReadAccess(List<HealthDataType> types) async {
    authorizationCalls++;
    return authorizationResult;
  }

  @override
  Future<bool> activityRecognition({required bool request}) async {
    if (request) motionRequests++;
    return motionGranted;
  }

  @override
  Future<int?> steps(DateTime start, DateTime end) async {
    stepCalls++;
    stepIntervals.add((start, end));
    if (pendingSteps != null) {
      final pending = pendingSteps!;
      pendingSteps = null;
      return pending.future;
    }
    return 1000;
  }

  @override
  Future<List<HealthDataPoint>> read(
    HealthDataType type,
    DateTime start,
    DateTime end,
  ) async {
    readCalls++;
    return records[type] ?? [];
  }

  @override
  Future<void> installProvider() async {}
}

HealthDataPoint energy(
  String id,
  double value, {
  String source = 'Ceas',
  DateTime? start,
  DateTime? end,
}) => HealthDataPoint(
  uuid: id,
  value: NumericHealthValue(numericValue: value),
  type: HealthDataType.ACTIVE_ENERGY_BURNED,
  unit: HealthDataUnit.KILOCALORIE,
  dateFrom: start ?? DateTime(2026, 10, 15, 10),
  dateTo: end ?? DateTime(2026, 10, 15, 11),
  sourcePlatform: HealthPlatformType.googleHealthConnect,
  sourceDeviceId: source,
  sourceId: source,
  sourceName: source,
);
HealthDataPoint workout(String id, {DateTime? end}) => HealthDataPoint(
  uuid: id,
  value: WorkoutHealthValue(
    workoutActivityType: HealthWorkoutActivityType.STRENGTH_TRAINING,
  ),
  type: HealthDataType.WORKOUT,
  unit: HealthDataUnit.MINUTE,
  dateFrom: DateTime(2026, 10, 15, 10),
  dateTo: end ?? DateTime(2026, 10, 15, 11),
  sourcePlatform: HealthPlatformType.googleHealthConnect,
  sourceDeviceId: 'watch',
  sourceId: 'watch',
  sourceName: 'Ceas',
);
HealthService service(
  FakeHealthSource source, {
  HealthProvider provider = HealthProvider.healthConnect,
}) => HealthService(source: source, provider: provider, now: () => healthNow);

Future<AppStore> healthStore() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance());
}

Future<void> pumpHealth(
  WidgetTester tester,
  AppStore store,
  HealthService health,
) async {
  tester.view.physicalSize = const Size(320, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: piTheme(Brightness.dark),
      home: HealthScreen(store: store, service: health),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'availability inspection never requests permissions or reads records',
    () async {
      final source = FakeHealthSource();
      final health = service(source);
      expect(await health.inspect(), HealthAvailability.available);
      expect(source.authorizationCalls, 0);
      expect(source.motionRequests, 0);
      expect(source.readCalls, 0);
      expect(source.stepCalls, 0);
      await expectLater(health.refresh(), throwsA(isA<HealthReadException>()));
    },
  );

  test(
    'unsupported platforms and missing Health Connect stay explicit',
    () async {
      final source = FakeHealthSource();
      expect(
        await service(source, provider: HealthProvider.unsupported).inspect(),
        HealthAvailability.unsupported,
      );
      expect(source.configureCalls, 0);
      source.status =
          HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired;
      expect(
        await service(source).inspect(),
        HealthAvailability.installRequired,
      );
      expect(source.authorizationCalls, 0);
    },
  );

  test(
    'reads seven calendar days, bounds today at now and separates energy sources',
    () async {
      final source = FakeHealthSource();
      source.records[HealthDataType.ACTIVE_ENERGY_BURNED] = [
        energy('a', 100),
        energy('a', 100),
        energy('b', 80),
        energy('c', 300, source: 'Altă aplicație'),
        energy('bad', -20),
        energy('nan', double.nan),
        energy('future', 900, end: DateTime(2026, 10, 16)),
      ];
      source.records[HealthDataType.WORKOUT] = [
        workout('w'),
        workout('w'),
        workout('future', end: DateTime(2026, 10, 16)),
      ];
      final result = await service(source).connect();
      expect(result.days.length, 7);
      expect(result.days.first.date, DateTime(2026, 10, 9));
      expect(source.stepIntervals.last.$2, healthNow);
      expect(result.totalSteps, 7000);
      expect(result.totalEnergy('Ceas'), 180);
      expect(result.totalEnergy('Altă aplicație'), 300);
      expect(result.energySamples.length, 3);
      expect(result.workouts.length, 1);
      expect(result.workouts.single.name, 'Antrenament de forță');
      expect(result.updatedAt, healthNow);
    },
  );

  test('denied access does not read health data or fabricate zeros', () async {
    final source = FakeHealthSource()..granted.clear();
    await expectLater(
      service(source).connect(),
      throwsA(isA<HealthReadException>()),
    );
    expect(source.authorizationCalls, 1);
    expect(source.readCalls, 0);
    expect(source.stepCalls, 0);
  });

  test(
    'partial permissions skip inaccessible categories and preserve unknown values',
    () async {
      final source = FakeHealthSource()..motionGranted = false;
      source.granted.remove(HealthDataType.ACTIVE_ENERGY_BURNED);
      final result = await service(source).connect();
      expect(result.totalSteps, isNull);
      expect(result.totalEnergy('Ceas'), isNull);
      expect(result.warnings, isNotEmpty);
      expect(source.stepCalls, 0);
      expect(source.readCalls, 1);
    },
  );

  test(
    'HealthKit authorization completion never claims verified read access',
    () async {
      final source = FakeHealthSource()..unknownReadAccess = true;
      final result = await service(
        source,
        provider: HealthProvider.appleHealth,
      ).connect();
      expect(source.authorizationCalls, 1);
      expect(source.motionRequests, 0);
      expect(result.iosReadAccessUndisclosed, isTrue);
    },
  );

  testWidgets(
    'unsupported screen gives mobile guidance without a Connect button',
    (tester) async {
      final source = FakeHealthSource();
      await pumpHealth(
        tester,
        await healthStore(),
        service(source, provider: HealthProvider.unsupported),
      );
      expect(find.byKey(const ValueKey('health-unsupported')), findsOneWidget);
      expect(find.byKey(const ValueKey('health-connect')), findsNothing);
      expect(source.authorizationCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opening health screen is read-free and explicit Connect loads local values',
    (tester) async {
      final source = FakeHealthSource();
      final store = await healthStore();
      await pumpHealth(tester, store, service(source));
      expect(source.stepCalls, 0);
      await tester.ensureVisible(find.byKey(const ValueKey('health-connect')));
      await tester.tap(find.byKey(const ValueKey('health-connect')));
      await tester.pumpAndSettle();
      expect(find.text('7000'), findsOneWidget);
      expect(store.history, isEmpty);
      expect(tester.takeException(), isNull);
      await store.switchAccount('other-user');
      await tester.pumpAndSettle();
      expect(find.text('7000'), findsNothing);
      expect(find.text('Conectează și alege accesul'), findsOneWidget);
    },
  );

  testWidgets(
    'a health read finishing after an account change cannot reveal the old result',
    (tester) async {
      final source = FakeHealthSource()..pendingSteps = Completer<int?>();
      final pending = source.pendingSteps!;
      final store = await healthStore();
      await pumpHealth(tester, store, service(source));
      await tester.ensureVisible(find.byKey(const ValueKey('health-connect')));
      await tester.tap(find.byKey(const ValueKey('health-connect')));
      await tester.pump();
      await store.switchAccount('new-user');
      pending.complete(1000);
      await tester.pumpAndSettle();
      expect(find.text('7000'), findsNothing);
      expect(find.text('Conectează și alege accesul'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
