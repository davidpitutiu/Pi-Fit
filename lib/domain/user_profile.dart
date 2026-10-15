/// Voluntary training preferences. These are not medical measurements and are
/// never used to assign health or fitness points.
class UserProfile {
  UserProfile({
    this.age,
    this.heightCm,
    this.weightKg,
    this.experience = 'Începător',
    this.sessionsPerWeek = 3,
    this.sessionMinutes = 60,
    List<String> equipment = const [],
    this.limitations = '',
    List<int> preferredDays = const [1, 3, 5],
    this.coachConsent = false,
  }) : equipment = List.unmodifiable(equipment),
       preferredDays = List.unmodifiable(preferredDays) {
    _validate();
  }

  static const experiences = ['Începător', 'Intermediar', 'Avansat'];
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final String experience;
  final int sessionsPerWeek;
  final int sessionMinutes;
  final List<String> equipment;
  final String limitations;
  final List<int> preferredDays;

  /// Explicit permission to send profile and training history to the remote
  /// coach. Free-text notes and limitations are also excluded from local
  /// request context until this permission is enabled.
  final bool coachConsent;

  void _validate() {
    if ((age != null && (age! < 13 || age! > 100)) ||
        !_optionalRange(heightCm, 100, 250) ||
        !_optionalRange(weightKg, 25, 350) ||
        !experiences.contains(experience) ||
        sessionsPerWeek < 1 ||
        sessionsPerWeek > 7 ||
        sessionMinutes < 15 ||
        sessionMinutes > 180 ||
        equipment.length > 30 ||
        equipment.any((item) => item.trim().isEmpty || item.length > 60) ||
        equipment.toSet().length != equipment.length ||
        limitations.length > 1500 ||
        preferredDays.any((day) => day < 1 || day > 7) ||
        preferredDays.toSet().length != preferredDays.length) {
      throw ArgumentError(
        'Profilul conține valori nevalide. Verifică intervalele indicate.',
      );
    }
  }

  static bool _optionalRange(double? value, double min, double max) =>
      value == null || (value.isFinite && value >= min && value <= max);

  UserProfile copyWith({
    int? age,
    double? heightCm,
    double? weightKg,
    bool clearAge = false,
    bool clearHeightCm = false,
    bool clearWeightKg = false,
    String? experience,
    int? sessionsPerWeek,
    int? sessionMinutes,
    List<String>? equipment,
    String? limitations,
    List<int>? preferredDays,
    bool? coachConsent,
  }) => UserProfile(
    age: clearAge ? null : age ?? this.age,
    heightCm: clearHeightCm ? null : heightCm ?? this.heightCm,
    weightKg: clearWeightKg ? null : weightKg ?? this.weightKg,
    experience: experience ?? this.experience,
    sessionsPerWeek: sessionsPerWeek ?? this.sessionsPerWeek,
    sessionMinutes: sessionMinutes ?? this.sessionMinutes,
    equipment: equipment ?? this.equipment,
    limitations: limitations ?? this.limitations,
    preferredDays: preferredDays ?? this.preferredDays,
    coachConsent: coachConsent ?? this.coachConsent,
  );

  Map<String, dynamic> toJson() => {
    'age': age,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'experience': experience,
    'sessionsPerWeek': sessionsPerWeek,
    'sessionMinutes': sessionMinutes,
    'equipment': equipment,
    'limitations': limitations,
    'preferredDays': preferredDays,
    'coachConsent': coachConsent,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    try {
      int? integer(String key) {
        final value = json[key];
        if (value == null) return null;
        if (value is! num ||
            !value.isFinite ||
            value != value.roundToDouble()) {
          throw const FormatException('Număr întreg invalid.');
        }
        return value.toInt();
      }

      double? decimal(String key) {
        final value = json[key];
        if (value == null) return null;
        if (value is! num || !value.isFinite) {
          throw const FormatException('Măsurătoare invalidă.');
        }
        return value.toDouble();
      }

      final rawDays = json['preferredDays'] as List?;
      if (rawDays != null && rawDays.any((value) => value is! int)) {
        throw const FormatException('Zile preferate nevalide.');
      }
      return UserProfile(
        age: integer('age'),
        heightCm: decimal('heightCm'),
        weightKg: decimal('weightKg'),
        experience: json['experience'] as String? ?? 'Începător',
        sessionsPerWeek: integer('sessionsPerWeek') ?? 3,
        sessionMinutes: integer('sessionMinutes') ?? 60,
        equipment: List<String>.from(json['equipment'] as List? ?? const []),
        limitations: json['limitations'] as String? ?? '',
        preferredDays: rawDays == null
            ? const [1, 3, 5]
            : List<int>.from(rawDays),
        coachConsent: json['coachConsent'] as bool? ?? false,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Profil de antrenament invalid.');
    }
  }
}
