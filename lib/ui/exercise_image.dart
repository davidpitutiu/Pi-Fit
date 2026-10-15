import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'exercise_icon.dart';

export 'exercise_icon.dart' show exerciseIconCredit, exerciseIconFor;

/// A consistent offline icon tile for exercises, routines and workout headers.
/// Legacy image fields and pose indices never load photos or imply a tutorial.
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
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? const Color(0xFFC7FF3D) : const Color(0xFF557C16);
    final data = exerciseIconFor(exercise);
    return Semantics(
      image: true,
      excludeSemantics: true,
      label: exerciseIconSemanticLabel(exercise),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [Color(0xFF24382B), Color(0xFF14251D)]
                    : const [Color(0xFFEAF1E2), Color(0xFFDCE8D8)],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final edge = math.min(
                  constraints.maxWidth.isFinite ? constraints.maxWidth : 120.0,
                  constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : 120.0,
                );
                final large =
                    constraints.maxWidth >= 180 && constraints.maxHeight >= 160;
                final iconSize = (edge * (large ? .31 : .43)).clamp(22.0, 76.0);
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (large)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: dark ? .07 : .055),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: accent.withValues(alpha: .16),
                            ),
                          ),
                          child: Icon(data.icon, size: iconSize, color: accent),
                        )
                      else
                        Icon(data.icon, size: iconSize, color: accent),
                      if (large) ...[
                        const SizedBox(height: 15),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            data.label.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: accent.withValues(alpha: .85),
                              fontSize: 9,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
