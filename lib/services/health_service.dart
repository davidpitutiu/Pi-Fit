import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';

/// Raw health data stays in screen memory. Body measurements can be imported
/// separately by explicit user action; pulse/energy/workouts never enter AppStore.
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

enum HealthBodyKind { weight, height }

class HealthBodyRecord {
  const HealthBodyRecord({
    required this.id,
    required this.kind,
    required this.value,
    required this.measuredAt,
    required this.sourceName,
    required this.sourceId,
  });
  final String id;
  final HealthBodyKind kind;

  /// Kilograms for weight, centimetres for height.
  final double value;
  final DateTime measuredAt;
  final String sourceName;
  final String sourceId;
}

class HealthHeartRateSample {
  const HealthHeartRateSample({
    required this.id,
    required this.beatsPerMinute,
    required this.measuredAt,
    required this.sourceName,
    required this.sourceId,
    this.deviceModel,
  });
  final String id;
  final double beatsPerMinute;
  final DateTime measuredAt;
  final String sourceName;
  final String sourceId;
  final String? deviceModel;
}

class HealthPulseRead {
  const HealthPulseRead({required this.sample, required this.readAt});
  final HealthHeartRateSample? sample;
  final DateTime readAt;
}

class HealthSnapshot {
  const HealthSnapshot({
    required this.days,
    required this.energySamples,
    required this.workouts,
    required this.updatedAt,
    required this.iosReadAccessUndisclosed,
    required this.warnings,
    this.bodyRecords = const [],
    this.latestHeartRate,
    this.bodyLookbackDays = 30,
  });
  final List<HealthDaySummary> days;
  final List<HealthEnergySample> energySamples;
  final List<HealthWorkoutRecord> workouts;
  final DateTime updatedAt;
  final bool iosReadAccessUndisclosed;
  final List<String> warnings;
  final List<HealthBodyRecord> bodyRecords;
  final HealthHeartRateSample? latestHeartRate;
  final int bodyLookbackDays;

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
    HealthDataType.HEART_RATE,
    HealthDataType.HEIGHT,
    HealthDataType.WEIGHT,
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
    HealthProvider.unsupported => 'Health',
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
        'The health service is unavailable on this device.',
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
        'The Apple Health request did not complete. Please try again.',
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
        'Connect the health service before reading data.',
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
        'No read permissions were granted. Enable the categories you want in Health Connect and reconnect.',
      );
    }
    if (provider == HealthProvider.healthConnect &&
        !await _source.activityRecognition(request: false)) {
      allowed.remove(HealthDataType.STEPS);
      warnings.add(
        'Physical activity access was not granted, so steps were not read.',
      );
    }
    if (allowed.length < readTypes.length &&
        provider == HealthProvider.healthConnect) {
      warnings.add(
        'Some categories are not permitted. Unavailable values are left unknown.',
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
          if (!warnings.contains('Steps could not be read completely.')) {
            warnings.add('Steps could not be read completely.');
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
      String label, {
      DateTime? from,
    }) async {
      if (!allowed.contains(type)) return [];
      try {
        return await _source.read(type, from ?? start, end);
      } catch (_) {
        warnings.add(
          '$label could not be read. Check permissions and try again.',
        );
        return [];
      }
    }

    final energyPoints = await read(
      HealthDataType.ACTIVE_ENERGY_BURNED,
      'Active-energy records',
    );
    final workoutPoints = await read(HealthDataType.WORKOUT, 'Workouts');
    final pulsePoints = await read(
      HealthDataType.HEART_RATE,
      'Heart-rate measurements',
    );
    final bodyLookbackDays = provider == HealthProvider.appleHealth ? 365 : 30;
    final bodyStart = end.subtract(Duration(days: bodyLookbackDays));
    final weightPoints = await read(
      HealthDataType.WEIGHT,
      'Weight measurements',
      from: bodyStart,
    );
    final heightPoints = await read(
      HealthDataType.HEIGHT,
      'Height measurements',
      from: bodyStart,
    );
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
          : 'Workout';
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
      bodyRecords: List.unmodifiable(
        _bodyRecords([...weightPoints, ...heightPoints], bodyStart, end),
      ),
      latestHeartRate: _latestHeartRate(pulsePoints, start, end),
      bodyLookbackDays: bodyLookbackDays,
    );
  }

  /// Foreground polling only reads pulse incrementally; it does not refetch
  /// seven days of activity or import any data into the user's profile.
  Future<HealthPulseRead> refreshHeartRate({
    HealthHeartRateSample? previous,
  }) async {
    if (!_sessionOpened) {
      throw const HealthReadException(
        'Connect the health service before reading heart rate.',
      );
    }
    if (provider == HealthProvider.healthConnect &&
        await _source.hasReadAccess([HealthDataType.HEART_RATE]) != true) {
      throw const HealthReadException(
        'Heart-rate access is not granted in Health Connect.',
      );
    }
    final end = _now();
    final weekStart = end.subtract(const Duration(days: 7));
    final incremental = previous?.measuredAt.subtract(
      const Duration(minutes: 2),
    );
    final start = incremental != null && incremental.isAfter(weekStart)
        ? incremental
        : end.subtract(const Duration(days: 1));
    try {
      final points = await _source.read(HealthDataType.HEART_RATE, start, end);
      return HealthPulseRead(
        sample: _latestHeartRate(points, start, end),
        readAt: end,
      );
    } catch (_) {
      throw const HealthReadException(
        'Heart rate could not be checked. Review access and source synchronization.',
      );
    }
  }

  String _recordId(HealthDataPoint point) =>
      'health:${provider.name}:${point.sourceId}:${point.uuid}';
  String _sourceName(HealthDataPoint point) => point.sourceName.isNotEmpty
      ? point.sourceName
      : point.sourceId.isNotEmpty
      ? point.sourceId
      : providerName;
  bool _validInstant(HealthDataPoint point, DateTime start, DateTime end) =>
      !point.dateFrom.isBefore(start) &&
      !point.dateFrom.isAfter(end) &&
      !point.dateTo.isBefore(point.dateFrom) &&
      !point.dateTo.isAfter(end);

  List<HealthBodyRecord> _bodyRecords(
    List<HealthDataPoint> points,
    DateTime start,
    DateTime end,
  ) {
    final result = <HealthBodyRecord>[];
    final seen = <String>{};
    for (final point in points) {
      final raw = point.value;
      if (raw is! NumericHealthValue ||
          !raw.numericValue.isFinite ||
          !_validInstant(point, start, end)) {
        continue;
      }
      final number = raw.numericValue.toDouble();
      final HealthBodyKind kind;
      final double value;
      if (point.type == HealthDataType.WEIGHT) {
        kind = HealthBodyKind.weight;
        value = switch (point.unit) {
          HealthDataUnit.KILOGRAM => number,
          HealthDataUnit.GRAM => number / 1000,
          HealthDataUnit.POUND => number * 0.45359237,
          _ => double.nan,
        };
        if (!value.isFinite || value < 25 || value > 350) continue;
      } else if (point.type == HealthDataType.HEIGHT) {
        kind = HealthBodyKind.height;
        value = switch (point.unit) {
          HealthDataUnit.METER => number * 100,
          HealthDataUnit.CENTIMETER => number,
          HealthDataUnit.INCH => number * 2.54,
          HealthDataUnit.FOOT => number * 30.48,
          _ => double.nan,
        };
        if (!value.isFinite || value < 100 || value > 250) continue;
      } else {
        continue;
      }
      final id = '${_recordId(point)}:${kind.name}';
      if (!seen.add(id)) continue;
      result.add(
        HealthBodyRecord(
          id: id,
          kind: kind,
          value: value,
          measuredAt: point.dateFrom.toLocal(),
          sourceName: _sourceName(point),
          sourceId: point.sourceId,
        ),
      );
    }
    result.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return result;
  }

  HealthHeartRateSample? _latestHeartRate(
    List<HealthDataPoint> points,
    DateTime start,
    DateTime end,
  ) {
    HealthHeartRateSample? latest;
    for (final point in points) {
      final raw = point.value;
      if (point.type != HealthDataType.HEART_RATE ||
          point.unit != HealthDataUnit.BEATS_PER_MINUTE ||
          raw is! NumericHealthValue ||
          !raw.numericValue.isFinite ||
          raw.numericValue <= 0 ||
          raw.numericValue > 350 ||
          !_validInstant(point, start, end)) {
        continue;
      }
      final measuredAt = point.dateTo.toLocal();
      if (latest == null || measuredAt.isAfter(latest.measuredAt)) {
        latest = HealthHeartRateSample(
          id: _recordId(point),
          beatsPerMinute: raw.numericValue.toDouble(),
          measuredAt: measuredAt,
          sourceName: _sourceName(point),
          sourceId: point.sourceId,
          deviceModel: point.deviceModel,
        );
      }
    }
    return latest;
  }
}

String healthWorkoutName(HealthWorkoutActivityType type) => switch (type) {
  HealthWorkoutActivityType.WALKING ||
  HealthWorkoutActivityType.WALKING_TREADMILL => 'Walking',
  HealthWorkoutActivityType.RUNNING ||
  HealthWorkoutActivityType.RUNNING_TREADMILL => 'Running',
  HealthWorkoutActivityType.BIKING ||
  HealthWorkoutActivityType.BIKING_STATIONARY => 'Cycling',
  HealthWorkoutActivityType.STRENGTH_TRAINING ||
  HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING ||
  HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING ||
  HealthWorkoutActivityType.WEIGHTLIFTING => 'Strength training',
  HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING =>
    'High-intensity intervals',
  HealthWorkoutActivityType.ROWING ||
  HealthWorkoutActivityType.ROWING_MACHINE => 'Rowing',
  HealthWorkoutActivityType.SWIMMING ||
  HealthWorkoutActivityType.SWIMMING_POOL ||
  HealthWorkoutActivityType.SWIMMING_OPEN_WATER => 'Swimming',
  HealthWorkoutActivityType.YOGA => 'Yoga',
  HealthWorkoutActivityType.PILATES => 'Pilates',
  HealthWorkoutActivityType.HIKING => 'Hiking',
  HealthWorkoutActivityType.ELLIPTICAL => 'Elliptical',
  HealthWorkoutActivityType.STAIR_CLIMBING ||
  HealthWorkoutActivityType.STAIR_CLIMBING_MACHINE ||
  HealthWorkoutActivityType.STAIRS => 'Stair climbing',
  HealthWorkoutActivityType.CALISTHENICS => 'Calisthenics',
  HealthWorkoutActivityType.OTHER => 'Other workout',
  _ =>
    type.name
        .split('_')
        .map((word) => '${word[0]}${word.substring(1).toLowerCase()}')
        .join(' '),
};
