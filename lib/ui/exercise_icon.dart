import 'package:flutter/material.dart';

import '../domain/models.dart';

const exerciseIconCredit = 'Material Icons · Flutter';

class ExerciseIconData {
  const ExerciseIconData(this.icon, this.label);
  final IconData icon;
  final String label;
}

String _normalized(String value) {
  var result = value.toLowerCase();
  const accents = {'ă': 'a', 'â': 'a', 'î': 'i', 'ș': 's', 'ț': 't'};
  accents.forEach(
    (source, target) => result = result.replaceAll(source, target),
  );
  return result;
}

/// Icons identify a training category or equipment, rather than demonstrating
/// technique. Several exercises deliberately share the same recognizable icon.
ExerciseIconData exerciseIconFor(Exercise exercise) {
  final name = _normalized(
    '${exercise.id} ${exercise.name} ${exercise.aliases.join(' ')}',
  );
  final equipment = _normalized(exercise.equipment);
  final category = _normalized(exercise.category);
  final muscle = _normalized(exercise.muscle);
  bool has(String term) => name.contains(term);
  if (category == 'cardio' || muscle == 'cardio') {
    if (has('cycl') || has('bike') || has('biciclet')) {
      return const ExerciseIconData(Icons.directions_bike_rounded, 'Cycling');
    }
    if (has('row') || has('ergomet')) {
      return const ExerciseIconData(Icons.rowing_rounded, 'Rowing');
    }
    if (has('swim') || has('pool')) {
      return const ExerciseIconData(Icons.pool_rounded, 'Swimming');
    }
    if (has('run') || has('treadmill') || has('walk') || has('alerg')) {
      return const ExerciseIconData(
        Icons.directions_run_rounded,
        'Running and walking',
      );
    }
    return const ExerciseIconData(Icons.monitor_heart_outlined, 'Cardio');
  }
  if (equipment.contains('foam') || equipment.contains('masaj')) {
    return const ExerciseIconData(Icons.spa_outlined, 'Recovery');
  }
  if (category.contains('mobil') || category.contains('stretch')) {
    return const ExerciseIconData(Icons.open_with_rounded, 'Mobility');
  }
  if (category.contains('plyo') || category.contains('pliom')) {
    return const ExerciseIconData(Icons.bolt_rounded, 'Power and jumps');
  }
  if (equipment.contains('cable') || equipment.contains('cablu')) {
    return const ExerciseIconData(Icons.linear_scale_rounded, 'Cable');
  }
  if (equipment.contains('band') || equipment.contains('elastica')) {
    return const ExerciseIconData(
      Icons.all_inclusive_rounded,
      'Resistance band',
    );
  }
  if (equipment.contains('ball') || equipment.contains('minge')) {
    return const ExerciseIconData(
      Icons.sports_volleyball_outlined,
      'Ball training',
    );
  }
  if (equipment.contains('machine') ||
      equipment.contains('aparat') ||
      equipment.contains('smith')) {
    return const ExerciseIconData(Icons.space_dashboard_outlined, 'Machine');
  }
  if (equipment.contains('barbell') ||
      equipment.contains('bara') ||
      equipment.contains('dumbbell') ||
      equipment.contains('ganter') ||
      equipment.contains('kettlebell') ||
      equipment.contains('ez bar')) {
    return const ExerciseIconData(Icons.fitness_center_rounded, 'Free weights');
  }
  if (muscle.contains('abs') ||
      muscle.contains('abdom') ||
      muscle.contains('core')) {
    return const ExerciseIconData(Icons.center_focus_strong_rounded, 'Core');
  }
  if (equipment.contains('bodyweight') ||
      equipment.contains('corp') ||
      equipment.contains('pull-up') ||
      equipment.contains('tractiuni') ||
      equipment.contains('paralele')) {
    return const ExerciseIconData(Icons.person_outline_rounded, 'Bodyweight');
  }
  return const ExerciseIconData(Icons.sports_gymnastics_rounded, 'Training');
}

String exerciseIconSemanticLabel(Exercise exercise) =>
    '${exercise.name}. ${exerciseIconFor(exercise).label} exercise icon.';
