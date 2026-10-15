import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'exercise_illustration.dart';

export 'exercise_illustration.dart'
    show exerciseIllustrationCredit, exerciseIllustrationPoseCount;

/// Original scalable movement-family artwork. No photo downloads or connection
/// are required; exact technique remains in the exercise-specific instructions.
class ExerciseImage extends StatelessWidget {
  const ExerciseImage({
    super.key,
    required this.exercise,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.imageIndex = 0,
  });

  final Exercise exercise;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final int imageIndex;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    excludeSemantics: true,
    label: exerciseIllustrationSemanticLabel(exercise, imageIndex),
    child: ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      child: SizedBox(
        width: width,
        height: height,
        child: ExerciseIllustration(exercise: exercise, pose: imageIndex),
      ),
    ),
  );
}
