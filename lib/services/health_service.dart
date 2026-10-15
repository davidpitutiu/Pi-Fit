import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';

/// Health data stays in this screen's memory. It is never written to AppStore,
/// Firebase, the AI payload, or the training score.
enum HealthProvider { appleHealth, healthConnect, unsupported }

enum HealthAvailability { available, installRequired, unavailable, unsupported }

abstract interface class HealthDataSource {
  Future<void> configure();
  Future<HealthConnectSdkStatus?> androidAvailability();
  Future<bool?> hasReadAccess(List<HealthDataType> types);
  Future<bool> requestReadAccess(List<HealthDataType> types);
  Future<bool> activityRecognition({required bool request});
  Future<int?> steps(DateTime start, DateTime end);
  Future<List<HealthDataPoint>> read(
    HealthDataType type,
    DateTime start,
    DateTime end,
  );
  Future<void> installProvider();
}

class PluginHealthDataSource implements HealthDataSource {
  PluginHealthDataSource({Health? plugin}) : _health = plugin ?? Health();
  final Health _health;
  static const _native = MethodChannel('com.pifit.app/health');

  @override
  Future<void> configure() => _health.configure();
  @override
  Future<HealthConnectSdkStatus?> androidAvailability() =>
      _health.getHealthConnectSdkStatus();
  @override
  Future<bool?> hasReadAccess(List<HealthDataType> types) =>
      _health.hasPermissions(
        types,
        permissions: List.filled(types.length, HealthDataAccess.READ),
      );
  @override
  Future<bool> requestReadAccess(List<HealthDataType> types) =>
      _health.requestAuthorization(
        types,
        permissions: List.filled(types.length, HealthDataAccess.READ),
      );
  @override
  Future<bool> activityRecognition({required bool request}) async =>
      await _native.invokeMethod<bool>(
        request ? 'requestActivityRecognition' : 'hasActivityRecognition',
      ) ??
      false;
  @override
  Future<int?> steps(DateTime start, DateTime end) =>
      _health.getTotalStepsInInterval(start, end);
  @override
  Future<List<HealthDataPoint>> read(
    HealthDataType type,
    DateTime start,
    DateTime end,
  ) => _health.getHealthDataFromTypes(
    types: [type],
    startTime: start,
    endTime: end,
  );
  @override
  Future<void> installProvider() => _health.installHealthConnect();
}

class HealthDaySummary {
  const HealthDaySummary({required this.date, this.steps});
  final DateTime date;

  /// Null means unreadable or unavailable, rather than an invented zero.
  final int? steps;
}

class HealthEnergySample {
  const HealthEnergySample({
    required this.start,
    required this.end,
    required this.kilocalories,
    required this.source,
  });
  final DateTime start;
  final DateTime end;
  final double kilocalories;
  final String source;
}

class HealthWorkoutRecord {
  const HealthWorkoutRecord({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.source,
  });
  final String id;
  final String name;
  final DateTime start;
  final DateTime end;
  final String source;
  Duration get duration => end.difference(start);
}

class HealthSnapshot {
  const HealthSnapshot({
    required this.days,
    required this.energySamples,
    required this.workouts,
    required this.updatedAt,
    required this.iosReadAccessUndisclosed,
    required this.warnings,
  });
  final List<HealthDaySummary> days;
  final List<HealthEnergySample> energySamples;
  final List<HealthWorkoutRecord> workouts;
  final DateTime updatedAt;
  final bool iosReadAccessUndisclosed;
  final List<String> warnings;

  List<String> get energySources {
    final counts = <String, int>{};
    for (final sample in energySamples) {
      counts.update(sample.source, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts.keys.toList()..sort((a, b) {
      final countOrder = counts[b]!.compareTo(counts[a]!);
      return countOrder == 0 ? a.compareTo(b) : countOrder;
    });
  }

  int? get totalSteps {
    final readable = days.map((day) => day.steps).whereType<int>().toList();
    return readable.isEmpty ? null : readable.reduce((a, b) => a + b);
  }

  /// A single selected source avoids silently adding overlapping app/device
  /// energy totals together. These are measured records, not calorie estimates.
  double? energyForDay(DateTime date, String? source) {
    final selected = energySamples
        .where(
          (sample) =>
              sample.source == source &&
              sample.start.year == date.year &&
              sample.start.month == date.month &&
              sample.start.day == date.day,
        )
        .toList();
    return selected.isEmpty
        ? null
        : selected.fold<double>(0, (sum, sample) => sum + sample.kilocalories);
  }

  double? totalEnergy(String? source) {
    final selected = energySamples
        .where((sample) => sample.source == source)
        .toList();
    return selected.isEmpty
        ? null
        : selected.fold<double>(0, (sum, sample) => sum + sample.kilocalories);
  }
}

class HealthReadException implements Exception {
  const HealthReadException(this.message);
  final String message;
  @override
  String toString() => message;
}

class HealthService {
  HealthService({
    HealthDataSource? source,
    HealthProvider? provider,
    DateTime Function()? now,
  }) : _source = source ?? PluginHealthDataSource(),
       provider = provider ?? currentProvider,
       _now = now ?? DateTime.now;
  final HealthDataSource _source;
  final HealthProvider provider;
  final DateTime Function() _now;
  bool _configured = false;
  bool _sessionOpened = false;
  static const readTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WORKOUT,
  ];
  static HealthProvider get currentProvider => kIsWeb
      ? HealthProvider.unsupported
      : switch (defaultTargetPlatform) {
          TargetPlatform.iOS => HealthProvider.appleHealth,
          TargetPlatform.android => HealthProvider.healthConnect,
          _ => HealthProvider.unsupported,
        };
  String get providerName => switch (provider) {
    HealthProvider.appleHealth => 'Apple Health',
    HealthProvider.healthConnect => 'Health Connect',
    HealthProvider.unsupported => 'Sănătate',
  };

  /// Availability only: opening the screen never reads records or asks consent.
  Future<HealthAvailability> inspect() async {
    if (provider == HealthProvider.unsupported) {
      return HealthAvailability.unsupported;
    }
    try {
      if (!_configured) {
        await _source.configure();
        _configured = true;
      }
      if (provider == HealthProvider.appleHealth) {
        return HealthAvailability.available;
      }
      return switch (await _source.androidAvailability()) {
        HealthConnectSdkStatus.sdkAvailable => HealthAvailability.available,
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
          HealthAvailability.installRequired,
        _ => HealthAvailability.unavailable,
      };
    } catch (_) {
      return HealthAvailability.unavailable;
    }
  }

  /// Called exclusively by the visible Connect button.
  Future<HealthSnapshot> connect() async {
    final availability = await inspect();
    if (availability != HealthAvailability.available) {
      throw const HealthReadException(
        'Serviciul de sănătate nu este disponibil pe acest dispozitiv.',
      );
    }
    if (provider == HealthProvider.healthConnect) {
      await _source.activityRecognition(request: true);
    }
    final existing = await _source.hasReadAccess(readTypes);
    // HealthKit deliberately does not reveal READ permission status. Its true
    // return value only confirms the authorization sheet completed successfully.
    final requested =
        existing == true || await _source.requestReadAccess(readTypes);
    if (provider == HealthProvider.appleHealth && !requested) {
      throw const HealthReadException(
        'Cererea Apple Health nu s-a încheiat. Poți încerca din nou.',
      );
    }
    _sessionOpened = true;
    return refresh();
  }

  Future<void> installProvider() async {
    if (provider == HealthProvider.healthConnect) {
      await _source.installProvider();
    }
  }

  Future<HealthSnapshot> refresh() async {
    if (!_sessionOpened) {
      throw const HealthReadException(
        'Conectează serviciul înainte de citirea datelor.',
      );
    }
    final end = _now();
    final today = DateTime(end.year, end.month, end.day);
    final start = DateTime(today.year, today.month, today.day - 6);
    final warnings = <String>[];
    final allowed = <HealthDataType>{};
    for (final type in readTypes) {
      if (provider == HealthProvider.appleHealth ||
          await _source.hasReadAccess([type]) == true) {
        allowed.add(type);
      }
    }
    if (allowed.isEmpty) {
      throw const HealthReadException(
        'Nu ai acordat permisiuni de citire. Activează categoriile dorite în Health Connect și reconectează.',
      );
    }
    if (provider == HealthProvider.healthConnect &&
        !await _source.activityRecognition(request: false)) {
      allowed.remove(HealthDataType.STEPS);
      warnings.add(
        'Accesul la activitate fizică nu este acordat; pașii nu au fost citiți.',
      );
    }
    if (allowed.length < readTypes.length &&
        provider == HealthProvider.healthConnect) {
      warnings.add(
        'Unele categorii nu au permisiune. Nu sunt afișate valori inventate pentru datele inaccesibile.',
      );
    }
    final days = <HealthDaySummary>[];
    for (var i = 0; i < 7; i++) {
      final date = DateTime(start.year, start.month, start.day + i);
      final next = DateTime(date.year, date.month, date.day + 1);
      int? steps;
      if (allowed.contains(HealthDataType.STEPS)) {
        try {
          steps = await _source.steps(date, next.isAfter(end) ? end : next);
        } catch (_) {
          if (!warnings.contains('Pașii nu au putut fi citiți complet.')) {
            warnings.add('Pașii nu au putut fi citiți complet.');
          }
        }
      }
      days.add(
        HealthDaySummary(
          date: date,
          steps: steps != null && steps >= 0 ? steps : null,
        ),
      );
    }
    Future<List<HealthDataPoint>> read(
      HealthDataType type,
      String label,
    ) async {
      if (!allowed.contains(type)) return [];
      try {
        return await _source.read(type, start, end);
      } catch (_) {
        warnings.add(
          '$label nu au putut fi citite. Verifică permisiunile și încearcă din nou.',
        );
        return [];
      }
    }

    final energyPoints = await read(
      HealthDataType.ACTIVE_ENERGY_BURNED,
      'Înregistrările de energie',
    );
    final workoutPoints = await read(HealthDataType.WORKOUT, 'Antrenamentele');
    final seenEnergy = <String>{};
    final energy = <HealthEnergySample>[];
    for (final point in energyPoints) {
      final value = point.value;
      if (point.type != HealthDataType.ACTIVE_ENERGY_BURNED ||
          value is! NumericHealthValue ||
          !value.numericValue.isFinite ||
          value.numericValue < 0 ||
          point.unit != HealthDataUnit.KILOCALORIE) {
        continue;
      }
      final key = '${point.sourceId}:${point.uuid}';
      if (!seenEnergy.add(key)) continue;
      if (point.dateFrom.isBefore(start) ||
          point.dateFrom.isAfter(end) ||
          !point.dateTo.isAfter(point.dateFrom) ||
          point.dateTo.isAfter(end)) {
        continue;
      }
      energy.add(
        HealthEnergySample(
          start: point.dateFrom.toLocal(),
          end: point.dateTo.toLocal(),
          kilocalories: value.numericValue.toDouble(),
          source: point.sourceName.isEmpty ? point.sourceId : point.sourceName,
        ),
      );
    }
    final seenWorkouts = <String>{};
    final workouts = <HealthWorkoutRecord>[];
    for (final point in workoutPoints) {
      if (point.dateFrom.isBefore(start) ||
          point.dateFrom.isAfter(end) ||
          !point.dateTo.isAfter(point.dateFrom) ||
          point.dateTo.isAfter(end) ||
          point.type != HealthDataType.WORKOUT ||
          point.value is! WorkoutHealthValue) {
        continue;
      }
      final key = '${point.sourceId}:${point.uuid}';
      if (!seenWorkouts.add(key)) continue;
      final value = point.value;
      final name = value is WorkoutHealthValue
          ? healthWorkoutName(value.workoutActivityType)
          : 'Antrenament';
      workouts.add(
        HealthWorkoutRecord(
          id: key,
          name: name,
          start: point.dateFrom.toLocal(),
          end: point.dateTo.toLocal(),
          source: point.sourceName.isEmpty ? point.sourceId : point.sourceName,
        ),
      );
    }
    workouts.sort((a, b) => b.start.compareTo(a.start));
    return HealthSnapshot(
      days: List.unmodifiable(days),
      energySamples: List.unmodifiable(energy),
      workouts: List.unmodifiable(workouts),
      updatedAt: end,
      iosReadAccessUndisclosed: provider == HealthProvider.appleHealth,
      warnings: List.unmodifiable(warnings),
    );
  }
}

String healthWorkoutName(HealthWorkoutActivityType type) => switch (type) {
  HealthWorkoutActivityType.WALKING ||
  HealthWorkoutActivityType.WALKING_TREADMILL => 'Mers',
  HealthWorkoutActivityType.RUNNING ||
  HealthWorkoutActivityType.RUNNING_TREADMILL => 'Alergare',
  HealthWorkoutActivityType.BIKING ||
  HealthWorkoutActivityType.BIKING_STATIONARY => 'Ciclism',
  HealthWorkoutActivityType.STRENGTH_TRAINING ||
  HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING ||
  HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING ||
  HealthWorkoutActivityType.WEIGHTLIFTING => 'Antrenament de forță',
  HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING =>
    'Intervale de intensitate mare',
  HealthWorkoutActivityType.ROWING ||
  HealthWorkoutActivityType.ROWING_MACHINE => 'Vâslit',
  HealthWorkoutActivityType.SWIMMING ||
  HealthWorkoutActivityType.SWIMMING_POOL ||
  HealthWorkoutActivityType.SWIMMING_OPEN_WATER => 'Înot',
  HealthWorkoutActivityType.YOGA => 'Yoga',
  HealthWorkoutActivityType.PILATES => 'Pilates',
  HealthWorkoutActivityType.HIKING => 'Drumeție',
  HealthWorkoutActivityType.ELLIPTICAL => 'Eliptică',
  HealthWorkoutActivityType.STAIR_CLIMBING ||
  HealthWorkoutActivityType.STAIR_CLIMBING_MACHINE ||
  HealthWorkoutActivityType.STAIRS => 'Urcări de trepte',
  HealthWorkoutActivityType.CALISTHENICS => 'Calistenie',
  HealthWorkoutActivityType.OTHER => 'Alt antrenament',
  _ =>
    type.name
        .split('_')
        .map((word) => '${word[0]}${word.substring(1).toLowerCase()}')
        .join(' '),
};
