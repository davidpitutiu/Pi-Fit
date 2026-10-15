/// A value entered by the user or explicitly selected for import from Health.
/// Raw Health records are never automatically added to this history.
class BodyMeasurement {
  BodyMeasurement({
    required this.id,
    required this.measuredAt,
    this.weightKg,
    this.heightCm,
    this.source = 'manual',
    String? sourceRecordId,
    String? sourceName,
  }) : sourceRecordId = sourceRecordId?.trim(),
       sourceName = sourceName?.trim().isEmpty == true
           ? null
           : sourceName?.trim() {
    if (id.trim().isEmpty ||
        id.length > 1200 ||
        measuredAt.year < 1900 ||
        measuredAt.isAfter(DateTime.now()) ||
        (weightKg == null && heightCm == null) ||
        !_validRange(weightKg, minWeightKg, maxWeightKg) ||
        !_validRange(heightCm, minHeightCm, maxHeightCm) ||
        !const {'manual', 'health'}.contains(source) ||
        (this.sourceRecordId != null &&
            (this.sourceRecordId!.isEmpty ||
                this.sourceRecordId!.length > 512)) ||
        (source == 'health' && this.sourceRecordId == null) ||
        (this.sourceName != null && this.sourceName!.length > 100)) {
      throw ArgumentError(
        'Invalid measurement. Use 25–350 kg, 100–250 cm and a date that is not in the future.',
      );
    }
  }

  static const double minWeightKg = 25;
  static const double maxWeightKg = 350;
  static const double minHeightCm = 100;
  static const double maxHeightCm = 250;
  final String id;
  final DateTime measuredAt;
  final double? weightKg;
  final double? heightCm;
  final String source;
  final String? sourceRecordId;
  final String? sourceName;

  static bool _validRange(double? value, double min, double max) =>
      value == null || (value.isFinite && value >= min && value <= max);

  Map<String, dynamic> toJson() => {
    'id': id,
    'measuredAt': measuredAt.toIso8601String(),
    'weightKg': weightKg,
    'heightCm': heightCm,
    'source': source,
    'sourceRecordId': sourceRecordId,
    'sourceName': sourceName,
  };

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    try {
      double? number(String key) {
        final value = json[key];
        if (value == null) return null;
        if (value is! num) {
          throw const FormatException('Invalid numeric value.');
        }
        return value.toDouble();
      }

      return BodyMeasurement(
        id: json['id'] as String,
        measuredAt: DateTime.parse(json['measuredAt'] as String),
        weightKg: number('weightKg'),
        heightCm: number('heightCm'),
        source: json['source'] as String? ?? 'manual',
        sourceRecordId: json['sourceRecordId'] as String?,
        sourceName: json['sourceName'] as String?,
      );
    } catch (_) {
      throw const FormatException(
        'The measurement history contains invalid data.',
      );
    }
  }
}
