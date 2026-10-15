import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/models.dart';

const exerciseIllustrationCredit = 'Original vector artwork · Pi Fit';

enum ExerciseMovementFamily {
  squat('Squat'),
  lunge('Lunge'),
  hinge('Hip hinge'),
  kneeFlexion('Knee flexion'),
  kneeExtension('Knee extension'),
  calfRaise('Calf raise'),
  benchPress('Horizontal press'),
  overheadPress('Overhead press'),
  pushUp('Push-up'),
  row('Row'),
  pullDown('Pulldown'),
  pullUp('Pull-up'),
  curl('Arm curl'),
  triceps('Triceps extension'),
  lateralRaise('Shoulder raise'),
  fly('Chest fly'),
  crunch('Core flexion'),
  plank('Core stability'),
  run('Locomotion'),
  cycle('Cycling'),
  mobility('Mobility'),
  carry('Loaded carry'),
  rotation('Rotation');

  const ExerciseMovementFamily(this.label);
  final String label;
}

String _normalized(String value) {
  var result = value.toLowerCase();
  const replacements = {'ă': 'a', 'â': 'a', 'î': 'i', 'ș': 's', 'ț': 't'};
  replacements.forEach((from, to) => result = result.replaceAll(from, to));
  return result;
}

/// Original illustrations describe movement families, not 878 individually
/// verified biomechanical tutorials. Exercise-specific steps remain authoritative.
ExerciseMovementFamily exerciseMovementFamily(Exercise exercise) {
  final text = _normalized(
    '${exercise.id} ${exercise.name} ${exercise.aliases.join(' ')}',
  );
  final movement = _normalized(exercise.movement);
  final muscle = _normalized(exercise.muscle);
  bool has(List<String> words) => words.any(text.contains);
  if (has(['bicycle', 'cycling', 'biciclet', 'stationary bike'])) {
    return ExerciseMovementFamily.cycle;
  }
  if (has([
    'plank',
    'bird dog',
    'bird_dog',
    'dead bug',
    'dead_bug',
    'pallof',
    'planșa',
    'plansa',
  ])) {
    return ExerciseMovementFamily.plank;
  }
  if (has([
    'wood chop',
    'woodchop',
    'russian twist',
    'rotation',
    'rotatie',
    'twist',
  ])) {
    return ExerciseMovementFamily.rotation;
  }
  if (has([
    'lunge',
    'fandari',
    'split squat',
    'split_squat',
    'step up',
    'step_up',
  ])) {
    return ExerciseMovementFamily.lunge;
  }
  if (has([
    'pull-up',
    'pull up',
    'pull_up',
    'chin-up',
    'chin up',
    'chin_up',
    'tractiuni',
  ])) {
    return ExerciseMovementFamily.pullUp;
  }
  if (has(['pulldown', 'pull down', 'lat_pull', 'helcometru'])) {
    return ExerciseMovementFamily.pullDown;
  }
  if (has(['push up', 'push-up', 'push_up', 'flotari'])) {
    return ExerciseMovementFamily.pushUp;
  }
  if (has(['farmer', 'carry', 'walk with', 'yoke'])) {
    return ExerciseMovementFamily.carry;
  }
  if (has([
    'crunch',
    'sit-up',
    'sit up',
    'sit_up',
    'leg raise',
    'leg_raise',
    'ab wheel',
    'ab_wheel',
  ])) {
    return ExerciseMovementFamily.crunch;
  }
  if (has([
    'deadlift',
    'good morning',
    'good_morning',
    'hip thrust',
    'hip_thrust',
    'swing',
    'indrep',
    'glute bridge',
    'glute_bridge',
    'back extension',
    'back_extension',
  ])) {
    return ExerciseMovementFamily.hinge;
  }
  if (has(['squat', 'genuflex', 'leg press', 'leg_press', 'hack press'])) {
    return ExerciseMovementFamily.squat;
  }
  if (has([
    'lateral raise',
    'lateral_raise',
    'front raise',
    'front_raise',
    'ridicari laterale',
    'shrug',
    'upright row',
    'upright_row',
  ])) {
    return ExerciseMovementFamily.lateralRaise;
  }
  if (has([
    'fly',
    'flye',
    'fluturari',
    'crossover',
    'cross over',
    'pec deck',
  ])) {
    return ExerciseMovementFamily.fly;
  }
  if (has([
    'tricep',
    'skullcrusher',
    'skull_crusher',
    'pushdown',
    'push_down',
    'kickback',
    'kick_back',
  ])) {
    return ExerciseMovementFamily.triceps;
  }
  if (has([
    'leg curl',
    'leg_curl',
    'hamstring curl',
    'hamstring_curl',
    'nordic',
  ])) {
    return ExerciseMovementFamily.kneeFlexion;
  }
  if (has([
    'leg extension',
    'leg_extension',
    'extensii la aparat',
    'knee extension',
  ])) {
    return ExerciseMovementFamily.kneeExtension;
  }
  if (has([
    'calf raise',
    'calf_raise',
    'calf press',
    'calf_press',
    'ridicari pe varfuri',
  ])) {
    return ExerciseMovementFamily.calfRaise;
  }
  if (has(['curl', 'flexii', 'flexie antebrat'])) {
    return ExerciseMovementFamily.curl;
  }
  if (RegExp(r'(^|[^a-z])(row|rowing|ramat)([^a-z]|$)').hasMatch(text)) {
    return ExerciseMovementFamily.row;
  }
  if (has([
    'overhead',
    'shoulder press',
    'shoulder_press',
    'military press',
    'military_press',
    'arnold',
    'jerk',
    'snatch',
    'impins deasupra',
  ])) {
    return ExerciseMovementFamily.overheadPress;
  }
  if (has([
    'bench press',
    'bench_press',
    'chest press',
    'chest_press',
    'incline press',
    'impins la banca',
    'impins inclinat',
    'dumbbell_press',
  ])) {
    return ExerciseMovementFamily.benchPress;
  }
  if (RegExp(
        r'(^|[^a-z])(run|running|jog|jogging|treadmill|sprint|elliptical)([^a-z]|$)',
      ).hasMatch(text) ||
      has(['alerg', 'jump rope', 'jump_rope'])) {
    return ExerciseMovementFamily.run;
  }
  if (movement.contains('mobil') ||
      has(['stretch', 'foam roll', 'foam_roll', 'masaj', 'intindere'])) {
    return ExerciseMovementFamily.mobility;
  }
  if (movement.contains('genuflex') || movement.contains('squat')) {
    return ExerciseMovementFamily.squat;
  }
  if (movement.contains('sold') || movement.contains('hinge')) {
    return ExerciseMovementFamily.hinge;
  }
  if (movement.contains('locom')) return ExerciseMovementFamily.run;
  if (movement.contains('stabili')) return ExerciseMovementFamily.plank;
  if (movement.contains('rot')) return ExerciseMovementFamily.rotation;
  if (muscle.contains('piept') || muscle.contains('chest')) {
    return ExerciseMovementFamily.benchPress;
  }
  if (muscle.contains('bicep') ||
      muscle.contains('antebr') ||
      muscle.contains('forearm')) {
    return ExerciseMovementFamily.curl;
  }
  if (muscle.contains('tricep')) return ExerciseMovementFamily.triceps;
  if (muscle.contains('spate') ||
      muscle.contains('back') ||
      muscle.contains('lat')) {
    return ExerciseMovementFamily.row;
  }
  if (muscle.contains('umer') || muscle.contains('shoulder')) {
    return ExerciseMovementFamily.overheadPress;
  }
  if (muscle.contains('abdom') || muscle.contains('core')) {
    return ExerciseMovementFamily.crunch;
  }
  if (muscle.contains('cvad') || muscle.contains('quad')) {
    return ExerciseMovementFamily.squat;
  }
  if (muscle.contains('ischio') ||
      muscle.contains('hamstring') ||
      muscle.contains('fesier') ||
      muscle.contains('glute')) {
    return ExerciseMovementFamily.hinge;
  }
  if (muscle.contains('gamb') ||
      muscle.contains('calf') ||
      muscle.contains('calves')) {
    return ExerciseMovementFamily.calfRaise;
  }
  if (muscle.contains('cardio')) return ExerciseMovementFamily.run;
  if (movement.contains('exploz') || movement.contains('explos')) {
    return ExerciseMovementFamily.hinge;
  }
  return ExerciseMovementFamily.mobility;
}

int exerciseIllustrationPoseCount(Exercise exercise) =>
    exerciseMovementFamily(exercise) == ExerciseMovementFamily.plank ? 1 : 2;

String exerciseIllustrationSemanticLabel(Exercise exercise, int pose) {
  final count = exerciseIllustrationPoseCount(exercise);
  final phase = pose.clamp(0, count - 1) + 1;
  return '${exercise.name}. ${exerciseMovementFamily(exercise).label} movement-family illustration. Phase $phase of $count. Follow the exercise instructions for this variation.';
}

class ExerciseIllustration extends StatelessWidget {
  const ExerciseIllustration({
    super.key,
    required this.exercise,
    this.pose = 0,
  });
  final Exercise exercise;
  final int pose;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final family = exerciseMovementFamily(exercise);
    final phase = pose.clamp(0, exerciseIllustrationPoseCount(exercise) - 1);
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _MovementPainter(
                family: family,
                phase: phase,
                dark: dark,
                muscle: exercise.muscle,
                equipment: exercise.equipment,
              ),
            ),
          ),
          if (constraints.maxWidth > 170 && constraints.maxHeight > 170)
            Positioned(
              left: 16,
              bottom: 13,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MOVEMENT STUDY',
                    style: TextStyle(
                      fontSize: 7,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: dark
                          ? const Color(0xFF80988C)
                          : const Color(0xFF647A6E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    family.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: dark
                          ? const Color(0xFFE1F0E7)
                          : const Color(0xFF2A4535),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Pose {
  const _Pose({
    required this.head,
    required this.shoulder,
    required this.hip,
    required this.elbow,
    required this.hand,
    required this.knee,
    required this.foot,
    required this.farElbow,
    required this.farHand,
    required this.farKnee,
    required this.farFoot,
  });
  final Offset head, shoulder, hip, elbow, hand, knee, foot;
  final Offset farElbow, farHand, farKnee, farFoot;
}

class _MovementPainter extends CustomPainter {
  const _MovementPainter({
    required this.family,
    required this.phase,
    required this.dark,
    required this.muscle,
    required this.equipment,
  });
  final ExerciseMovementFamily family;
  final int phase;
  final bool dark;
  final String muscle, equipment;

  Color get accent => dark ? const Color(0xFFC7FF3D) : const Color(0xFF78A923);
  Color get body => dark ? const Color(0xFFABC0B4) : const Color(0xFF6D8678);
  Color get bodyLight =>
      dark ? const Color(0xFFD6E5DB) : const Color(0xFF92A99B);
  Color get ink => dark ? const Color(0xFF3E5A4B) : const Color(0xFFA7BCAE);
  Color get line => dark ? const Color(0xFF688575) : const Color(0xFF7D9987);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF1A3329), Color(0xFF0E2119)]
              : const [Color(0xFFEAF3E6), Color(0xFFDCEADC)],
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(size.width * .58, size.height * .40),
      size.longestSide * .45,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: dark ? .10 : .09),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    final grid = Paint()
      ..color = line.withValues(alpha: .10)
      ..strokeWidth = .6;
    for (var index = 1; index < 5; index++) {
      canvas.drawLine(
        Offset(size.width * index / 5, 0),
        Offset(size.width * index / 5, size.height),
        grid,
      );
      canvas.drawLine(
        Offset(0, size.height * index / 5),
        Offset(size.width, size.height * index / 5),
        grid,
      );
    }
    final scale = math.min(size.width / 240, size.height / 240);
    canvas.save();
    canvas.translate(
      (size.width - 240 * scale) / 2,
      (size.height - 240 * scale) / 2 - 3 * scale,
    );
    canvas.scale(scale);
    canvas.drawOval(
      const Rect.fromLTWH(48, 204, 145, 11),
      Paint()..color = Colors.black.withValues(alpha: dark ? .20 : .05),
    );
    canvas.drawLine(
      const Offset(29, 208),
      const Offset(214, 208),
      Paint()
        ..color = line.withValues(alpha: .25)
        ..strokeWidth = 1,
    );
    final pose = _pose();
    _equipmentBehind(canvas, pose);
    _limb(
      canvas,
      pose.hip,
      pose.farKnee,
      pose.farFoot,
      upper: 17,
      lower: 12,
      color: body.withValues(alpha: .45),
      highlight: false,
      leg: true,
    );
    _limb(
      canvas,
      pose.shoulder,
      pose.farElbow,
      pose.farHand,
      upper: 11,
      lower: 8,
      color: body.withValues(alpha: .50),
      highlight: false,
    );
    _torso(canvas, pose);
    _limb(
      canvas,
      pose.hip,
      pose.knee,
      pose.foot,
      upper: 19,
      lower: 13,
      color: body,
      highlight: true,
      leg: true,
    );
    _limb(
      canvas,
      pose.shoulder,
      pose.elbow,
      pose.hand,
      upper: 12,
      lower: 9,
      color: bodyLight,
      highlight: true,
    );
    final neck = Offset.lerp(pose.head, pose.shoulder, .70)!;
    _stroke(
      canvas,
      neck,
      pose.shoulder,
      8,
      _normalized(muscle).contains('neck') ||
              _normalized(muscle).contains('gat')
          ? accent
          : body,
    );
    canvas.drawCircle(pose.head, 12, Paint()..color = bodyLight);
    canvas.drawArc(
      Rect.fromCircle(center: pose.head, radius: 12),
      math.pi * 1.0,
      math.pi * 1.03,
      false,
      Paint()
        ..color = ink
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      pose.head + const Offset(4, 1),
      1.5,
      Paint()..color = ink,
    );
    _equipmentFront(canvas, pose);
    _motionCue(canvas, pose);
    canvas.restore();
  }

  void _stroke(Canvas canvas, Offset a, Offset b, double width, Color color) =>
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );

  void _limb(
    Canvas canvas,
    Offset a,
    Offset b,
    Offset c, {
    required double upper,
    required double lower,
    required Color color,
    required bool highlight,
    bool leg = false,
  }) {
    _stroke(
      canvas,
      a,
      b,
      upper + 2,
      dark ? const Color(0xFF163124) : const Color(0xFFD7E7D9),
    );
    _stroke(
      canvas,
      b,
      c,
      lower + 2,
      dark ? const Color(0xFF163124) : const Color(0xFFD7E7D9),
    );
    _stroke(canvas, a, b, upper, color);
    _stroke(canvas, b, c, lower, color);
    final target = _normalized(muscle);
    final upperTarget = leg
        ? [
            'cvad',
            'quad',
            'ischio',
            'hamstring',
            'fesier',
            'glute',
            'adduct',
          ].any(target.contains)
        : ['bicep', 'tricep'].any(target.contains);
    final lowerTarget = leg
        ? target.contains('gamb') ||
              target.contains('calf') ||
              target.contains('calves')
        : target.contains('antebr') || target.contains('forearm');
    if (highlight && upperTarget) {
      _stroke(
        canvas,
        Offset.lerp(a, b, .28)!,
        Offset.lerp(a, b, .70)!,
        upper * .66,
        accent,
      );
    }
    if (highlight && lowerTarget) {
      _stroke(
        canvas,
        Offset.lerp(b, c, .22)!,
        Offset.lerp(b, c, .60)!,
        lower * .70,
        accent,
      );
    }
    canvas.drawCircle(
      b,
      lower * .28,
      Paint()..color = dark ? const Color(0xFF7F9A8B) : const Color(0xFFB5C8BA),
    );
    if (leg) {
      if (family == ExerciseMovementFamily.calfRaise && phase == 1) {
        _stroke(canvas, c, c + const Offset(11, 10), 6, ink);
      } else {
        _stroke(
          canvas,
          c - const Offset(3, 0),
          c + const Offset(10, 0),
          6,
          ink,
        );
      }
    } else {
      canvas.drawCircle(c, 4, Paint()..color = bodyLight);
    }
  }

  void _torso(Canvas canvas, _Pose pose) {
    final vector = pose.hip - pose.shoulder;
    final length = math.max(vector.distance, 1.0);
    final normal = Offset(-vector.dy / length, vector.dx / length);
    final s = pose.shoulder;
    final h = pose.hip;
    final path = Path()
      ..moveTo((s + normal * 13).dx, (s + normal * 13).dy)
      ..quadraticBezierTo(
        (Offset.lerp(s, h, .6)! + normal * 12).dx,
        (Offset.lerp(s, h, .6)! + normal * 12).dy,
        (h + normal * 10).dx,
        (h + normal * 10).dy,
      )
      ..lineTo((h - normal * 10).dx, (h - normal * 10).dy)
      ..quadraticBezierTo(
        (Offset.lerp(s, h, .6)! - normal * 10).dx,
        (Offset.lerp(s, h, .6)! - normal * 10).dy,
        (s - normal * 13).dx,
        (s - normal * 13).dy,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [bodyLight, body],
        ).createShader(path.getBounds()),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = bodyLight.withValues(alpha: .28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final target = _normalized(muscle);
    final torsoTarget = [
      'piept',
      'chest',
      'spate',
      'back',
      'lat',
      'abdomen',
      'abdom',
      'core',
    ].any(target.contains);
    if (torsoTarget) {
      final from = target.contains('abdom') || target.contains('core')
          ? .45
          : .12;
      final to = target.contains('abdom') || target.contains('core')
          ? .79
          : .42;
      _stroke(
        canvas,
        Offset.lerp(s, h, from)!,
        Offset.lerp(s, h, to)!,
        15,
        accent,
      );
      _stroke(
        canvas,
        Offset.lerp(s, h, from)!,
        Offset.lerp(s, h, to)!,
        1.2,
        dark ? const Color(0xFF64852B) : const Color(0xFF4D711C),
      );
    }
    canvas.drawCircle(pose.hip, 10, Paint()..color = ink);
    if (target.contains('fesier') || target.contains('glute')) {
      canvas.drawCircle(pose.hip, 7, Paint()..color = accent);
    }
    canvas.drawCircle(pose.shoulder, 8, Paint()..color = bodyLight);
    if (target.contains('umer') ||
        target.contains('shoulder') ||
        target.contains('delt')) {
      canvas.drawCircle(pose.shoulder, 6, Paint()..color = accent);
    }
  }

  void _equipmentBehind(Canvas canvas, _Pose pose) {
    final equipmentText = _normalized(equipment);
    final bench =
        family == ExerciseMovementFamily.benchPress ||
        family == ExerciseMovementFamily.fly;
    if (bench) {
      _stroke(canvas, const Offset(69, 169), const Offset(69, 204), 5, ink);
      _stroke(canvas, const Offset(152, 169), const Offset(152, 204), 5, ink);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(43, 155, 125, 10),
          const Radius.circular(4),
        ),
        Paint()..color = line,
      );
      _stroke(
        canvas,
        const Offset(48, 157),
        const Offset(162, 157),
        2,
        line.withValues(alpha: .5),
      );
    }
    if (family == ExerciseMovementFamily.pullUp ||
        family == ExerciseMovementFamily.pullDown) {
      _stroke(canvas, const Offset(46, 36), const Offset(46, 207), 4, ink);
      _stroke(canvas, const Offset(194, 36), const Offset(194, 207), 4, ink);
      _stroke(canvas, const Offset(47, 37), const Offset(193, 37), 6, line);
      if (family == ExerciseMovementFamily.pullDown) {
        _stroke(canvas, const Offset(98, 167), const Offset(143, 167), 9, line);
        _stroke(canvas, const Offset(122, 172), const Offset(122, 206), 4, ink);
        _stroke(
          canvas,
          const Offset(122, 37),
          pose.hand,
          1.7,
          accent.withValues(alpha: .65),
        );
      }
    }
    if (equipmentText.contains('cablu') ||
        equipmentText.contains('cable') ||
        equipmentText.contains('banda elastica') ||
        equipmentText == 'band' ||
        equipmentText.contains('resistance band')) {
      _stroke(canvas, const Offset(38, 44), const Offset(38, 208), 4, ink);
      canvas.drawCircle(const Offset(38, 80), 6, Paint()..color = line);
      _stroke(
        canvas,
        const Offset(38, 80),
        pose.hand,
        1.6,
        accent.withValues(alpha: .6),
      );
      for (var index = 0; index < 5; index++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(27, 145 + index * 8, 23, 5),
            const Radius.circular(2),
          ),
          Paint()..color = line.withValues(alpha: .55),
        );
      }
    }
    if (family == ExerciseMovementFamily.kneeExtension) {
      _stroke(canvas, const Offset(80, 145), const Offset(132, 145), 8, line);
      _stroke(canvas, const Offset(98, 150), const Offset(98, 206), 5, ink);
      _stroke(canvas, const Offset(81, 98), const Offset(81, 143), 8, line);
    }
    if (family == ExerciseMovementFamily.cycle) {
      final frame = Paint()
        ..color = line
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      canvas.drawCircle(const Offset(77, 181), 24, frame);
      canvas.drawCircle(const Offset(171, 181), 24, frame);
      canvas.drawPath(
        Path()
          ..moveTo(77, 181)
          ..lineTo(109, 142)
          ..lineTo(125, 181)
          ..lineTo(77, 181)
          ..moveTo(109, 142)
          ..lineTo(156, 139)
          ..lineTo(171, 181)
          ..lineTo(125, 181)
          ..lineTo(156, 139),
        frame,
      );
      _stroke(canvas, const Offset(151, 140), const Offset(157, 119), 3, line);
      _stroke(canvas, const Offset(153, 119), const Offset(169, 119), 4, line);
      _stroke(canvas, const Offset(96, 141), const Offset(118, 141), 5, ink);
    }
    if (family == ExerciseMovementFamily.plank ||
        family == ExerciseMovementFamily.crunch ||
        family == ExerciseMovementFamily.mobility) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(32, 203, 179, 5),
          const Radius.circular(3),
        ),
        Paint()..color = accent.withValues(alpha: .25),
      );
    }
  }

  void _equipmentFront(Canvas canvas, _Pose pose) {
    final text = _normalized(equipment);
    if (text.contains('ganter') || text.contains('dumbbell')) {
      _dumbbell(canvas, pose.farHand, .65);
      _dumbbell(canvas, pose.hand, 1);
    } else if (text.contains('kettlebell')) {
      final center = pose.hand + const Offset(0, 11);
      canvas.drawCircle(
        center - const Offset(0, 6),
        6,
        Paint()
          ..color = line
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(center + const Offset(0, 3), 10, Paint()..color = ink);
      canvas.drawArc(
        Rect.fromCircle(center: center + const Offset(0, 3), radius: 7),
        .2,
        1.4,
        false,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else if ((text.contains('bara') ||
            text.contains('barbell') ||
            text == 'smith') &&
        !text.contains('tract') &&
        !text.contains('pull-up')) {
      final position = family == ExerciseMovementFamily.squat
          ? pose.shoulder - const Offset(0, 5)
          : pose.hand;
      _barbell(canvas, position);
    } else if (text.contains('minge') || text.contains('ball')) {
      final at = pose.hand + const Offset(5, 11);
      canvas.drawCircle(at, 15, Paint()..color = ink);
      canvas.drawCircle(
        at,
        14,
        Paint()
          ..color = accent.withValues(alpha: .35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawArc(
        Rect.fromCircle(center: at, radius: 10),
        -1.2,
        2.5,
        false,
        Paint()
          ..color = accent.withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _dumbbell(Canvas canvas, Offset at, double alpha) {
    _stroke(
      canvas,
      at - const Offset(10, 0),
      at + const Offset(10, 0),
      3,
      line.withValues(alpha: alpha),
    );
    for (final dx in [-11.0, 8.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(at.dx + dx, at.dy - 8, 6, 16),
          const Radius.circular(2),
        ),
        Paint()..color = ink.withValues(alpha: alpha),
      );
      _stroke(
        canvas,
        Offset(at.dx + dx + 2, at.dy - 5),
        Offset(at.dx + dx + 2, at.dy + 5),
        1,
        accent.withValues(alpha: alpha * .6),
      );
    }
  }

  void _barbell(Canvas canvas, Offset at) {
    _stroke(
      canvas,
      at - const Offset(39, 0),
      at + const Offset(39, 0),
      4,
      line,
    );
    for (final dx in [-29.0, 23.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(at.dx + dx, at.dy - 15, 7, 30),
          const Radius.circular(2),
        ),
        Paint()..color = ink,
      );
      _stroke(
        canvas,
        Offset(at.dx + dx + 3, at.dy - 11),
        Offset(at.dx + dx + 3, at.dy + 11),
        1.5,
        accent.withValues(alpha: .75),
      );
    }
  }

  void _motionCue(Canvas canvas, _Pose pose) {
    if (family == ExerciseMovementFamily.plank) return;
    final at = family == ExerciseMovementFamily.benchPress
        ? const Offset(176, 93)
        : family == ExerciseMovementFamily.cycle
        ? const Offset(206, 147)
        : const Offset(188, 105);
    final arrow = Paint()
      ..color = accent.withValues(alpha: .55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: at, width: 28, height: 45),
      -.8,
      1.6,
      false,
      arrow,
    );
    final end = at + const Offset(10, 16);
    canvas.drawPath(
      Path()
        ..moveTo(end.dx - 5, end.dy - 2)
        ..lineTo(end.dx, end.dy + 2)
        ..lineTo(end.dx + 1, end.dy - 4),
      arrow,
    );
    canvas.drawCircle(
      const Offset(34, 30),
      3,
      Paint()..color = accent.withValues(alpha: .75),
    );
    _stroke(
      canvas,
      const Offset(43, 30),
      const Offset(62, 30),
      1,
      line.withValues(alpha: .45),
    );
  }

  _Pose _pose() {
    final end = phase == 1;
    const s = Offset(120, 78), h = Offset(120, 137);
    const head = Offset(120, 52),
        knee = Offset(112, 168),
        foot = Offset(107, 203);
    _Pose standing({
      Offset shoulder = s,
      Offset hip = h,
      Offset top = head,
      Offset elbow = const Offset(130, 109),
      Offset hand = const Offset(134, 139),
      Offset farElbow = const Offset(108, 109),
      Offset farHand = const Offset(104, 139),
      Offset nearKnee = knee,
      Offset nearFoot = foot,
      Offset farKnee = const Offset(133, 168),
      Offset farFoot = const Offset(143, 203),
    }) => _Pose(
      head: top,
      shoulder: shoulder,
      hip: hip,
      elbow: elbow,
      hand: hand,
      knee: nearKnee,
      foot: nearFoot,
      farElbow: farElbow,
      farHand: farHand,
      farKnee: farKnee,
      farFoot: farFoot,
    );
    switch (family) {
      case ExerciseMovementFamily.squat:
        return end
            ? standing(
                top: const Offset(126, 78),
                shoulder: const Offset(125, 102),
                hip: const Offset(95, 146),
                elbow: const Offset(148, 113),
                hand: const Offset(129, 98),
                farElbow: const Offset(111, 112),
                farHand: const Offset(117, 98),
                nearKnee: const Offset(146, 171),
                nearFoot: const Offset(146, 203),
                farKnee: const Offset(125, 167),
                farFoot: const Offset(127, 203),
              )
            : standing(
                elbow: const Offset(143, 98),
                hand: const Offset(127, 74),
                farElbow: const Offset(108, 98),
                farHand: const Offset(113, 74),
              );
      case ExerciseMovementFamily.lunge:
        return standing(
          top: end ? const Offset(117, 81) : head,
          shoulder: end ? const Offset(117, 106) : s,
          hip: end ? const Offset(117, 157) : h,
          nearKnee: end ? const Offset(155, 157) : const Offset(143, 168),
          nearFoot: const Offset(168, 203),
          farKnee: end ? const Offset(87, 187) : const Offset(97, 167),
          farFoot: const Offset(69, 203),
          elbow: end ? const Offset(127, 129) : const Offset(130, 109),
          hand: end ? const Offset(133, 159) : const Offset(134, 139),
        );
      case ExerciseMovementFamily.hinge:
        return end
            ? standing()
            : standing(
                top: const Offset(157, 94),
                shoulder: const Offset(141, 113),
                hip: const Offset(91, 141),
                elbow: const Offset(140, 144),
                hand: const Offset(140, 176),
                farElbow: const Offset(129, 142),
                farHand: const Offset(129, 174),
                nearKnee: const Offset(112, 171),
                nearFoot: const Offset(113, 203),
                farKnee: const Offset(97, 168),
                farFoot: const Offset(97, 203),
              );
      case ExerciseMovementFamily.kneeFlexion:
        return standing(
          nearKnee: const Offset(126, 171),
          nearFoot: Offset(end ? 157 : 126, end ? 151 : 203),
          elbow: const Offset(139, 107),
          hand: const Offset(156, 99),
        );
      case ExerciseMovementFamily.kneeExtension:
        return standing(
          top: const Offset(101, 66),
          shoulder: const Offset(102, 91),
          hip: const Offset(106, 137),
          nearKnee: const Offset(149, 141),
          nearFoot: Offset(end ? 190 : 158, end ? 149 : 183),
          farKnee: const Offset(140, 145),
          farFoot: Offset(end ? 180 : 149, end ? 151 : 185),
          elbow: const Offset(113, 119),
          hand: const Offset(122, 141),
        );
      case ExerciseMovementFamily.calfRaise:
        return standing(
          top: Offset(120, end ? 42 : 52),
          shoulder: Offset(120, end ? 68 : 78),
          hip: Offset(120, end ? 127 : 137),
          nearKnee: Offset(112, end ? 158 : 168),
          nearFoot: Offset(107, end ? 193 : 203),
          farKnee: Offset(133, end ? 158 : 168),
          farFoot: Offset(143, end ? 193 : 203),
        );
      case ExerciseMovementFamily.benchPress:
      case ExerciseMovementFamily.fly:
        return _Pose(
          head: const Offset(56, 139),
          shoulder: const Offset(80, 144),
          hip: const Offset(131, 149),
          elbow: family == ExerciseMovementFamily.fly
              ? Offset(end ? 104 : 123, end ? 108 : 150)
              : Offset(end ? 89 : 111, end ? 106 : 132),
          hand: family == ExerciseMovementFamily.fly
              ? Offset(end ? 108 : 154, end ? 80 : 146)
              : Offset(end ? 93 : 112, end ? 76 : 111),
          knee: const Offset(166, 175),
          foot: const Offset(172, 203),
          farElbow: Offset(end ? 84 : 98, end ? 112 : 136),
          farHand: Offset(end ? 87 : 102, end ? 83 : 119),
          farKnee: const Offset(151, 175),
          farFoot: const Offset(157, 203),
        );
      case ExerciseMovementFamily.overheadPress:
        return standing(
          elbow: Offset(end ? 110 : 91, end ? 50 : 94),
          hand: Offset(end ? 121 : 98, end ? 24 : 69),
          farElbow: Offset(end ? 136 : 143, end ? 50 : 94),
          farHand: Offset(end ? 132 : 136, end ? 25 : 69),
        );
      case ExerciseMovementFamily.pushUp:
      case ExerciseMovementFamily.plank:
        final low = family == ExerciseMovementFamily.pushUp && !end;
        return _Pose(
          head: Offset(69, low ? 156 : 124),
          shoulder: Offset(85, low ? 171 : 144),
          hip: Offset(139, low ? 177 : 157),
          elbow: Offset(low ? 106 : 85, low ? 188 : 173),
          hand: const Offset(85, 202),
          knee: const Offset(177, 182),
          foot: const Offset(202, 202),
          farElbow: Offset(low ? 111 : 94, 186),
          farHand: const Offset(101, 202),
          farKnee: const Offset(172, 177),
          farFoot: const Offset(196, 201),
        );
      case ExerciseMovementFamily.row:
        return standing(
          top: const Offset(150, 91),
          shoulder: const Offset(137, 111),
          hip: const Offset(95, 140),
          elbow: Offset(end ? 123 : 141, end ? 139 : 144),
          hand: Offset(end ? 101 : 143, end ? 134 : 176),
          farElbow: Offset(end ? 117 : 130, end ? 136 : 145),
          farHand: Offset(end ? 100 : 130, end ? 128 : 174),
          nearKnee: const Offset(120, 170),
          nearFoot: const Offset(121, 203),
          farKnee: const Offset(99, 166),
          farFoot: const Offset(96, 203),
        );
      case ExerciseMovementFamily.pullDown:
        return standing(
          top: const Offset(122, 71),
          shoulder: const Offset(122, 94),
          hip: const Offset(121, 158),
          elbow: Offset(end ? 92 : 98, end ? 116 : 61),
          hand: Offset(end ? 106 : 110, end ? 91 : 42),
          farElbow: Offset(end ? 149 : 143, end ? 116 : 61),
          farHand: Offset(end ? 137 : 132, end ? 91 : 42),
          nearKnee: const Offset(155, 160),
          nearFoot: const Offset(162, 202),
          farKnee: const Offset(143, 161),
          farFoot: const Offset(147, 202),
        );
      case ExerciseMovementFamily.pullUp:
        return standing(
          top: Offset(122, end ? 47 : 77),
          shoulder: Offset(121, end ? 71 : 101),
          hip: Offset(122, end ? 127 : 156),
          elbow: Offset(92, end ? 82 : 64),
          hand: const Offset(99, 38),
          farElbow: Offset(149, end ? 82 : 64),
          farHand: const Offset(144, 38),
          nearKnee: Offset(116, end ? 157 : 181),
          nearFoot: Offset(140, end ? 178 : 201),
          farKnee: Offset(105, end ? 151 : 177),
          farFoot: Offset(129, end ? 175 : 197),
        );
      case ExerciseMovementFamily.curl:
        return standing(
          elbow: const Offset(130, 111),
          hand: Offset(end ? 146 : 135, end ? 88 : 145),
          farElbow: const Offset(109, 111),
          farHand: Offset(end ? 92 : 103, end ? 91 : 143),
        );
      case ExerciseMovementFamily.triceps:
        return standing(
          elbow: const Offset(136, 54),
          hand: Offset(end ? 145 : 123, end ? 25 : 79),
          farElbow: const Offset(126, 54),
          farHand: Offset(end ? 134 : 116, end ? 25 : 77),
        );
      case ExerciseMovementFamily.lateralRaise:
        return standing(
          elbow: Offset(end ? 154 : 135, end ? 79 : 111),
          hand: Offset(end ? 185 : 141, end ? 82 : 145),
          farElbow: Offset(end ? 85 : 108, end ? 82 : 111),
          farHand: Offset(end ? 55 : 100, end ? 86 : 145),
        );
      case ExerciseMovementFamily.crunch:
        return _Pose(
          head: Offset(end ? 103 : 59, end ? 140 : 181),
          shoulder: Offset(end ? 113 : 82, end ? 157 : 183),
          hip: const Offset(139, 192),
          elbow: Offset(end ? 95 : 78, end ? 168 : 164),
          hand: Offset(end ? 104 : 63, end ? 141 : 171),
          knee: const Offset(163, 159),
          foot: const Offset(192, 201),
          farElbow: const Offset(106, 171),
          farHand: const Offset(99, 151),
          farKnee: const Offset(150, 163),
          farFoot: const Offset(179, 201),
        );
      case ExerciseMovementFamily.run:
        return standing(
          top: const Offset(126, 50),
          shoulder: const Offset(122, 75),
          hip: const Offset(111, 132),
          elbow: Offset(end ? 141 : 101, end ? 105 : 102),
          hand: Offset(end ? 158 : 108, end ? 91 : 74),
          farElbow: Offset(end ? 98 : 139, 106),
          farHand: Offset(end ? 106 : 154, end ? 80 : 92),
          nearKnee: Offset(end ? 87 : 142, end ? 163 : 145),
          nearFoot: Offset(end ? 60 : 150, end ? 188 : 183),
          farKnee: Offset(end ? 142 : 90, end ? 145 : 166),
          farFoot: Offset(end ? 156 : 65, end ? 182 : 194),
        );
      case ExerciseMovementFamily.cycle:
        return standing(
          top: const Offset(141, 69),
          shoulder: const Offset(129, 91),
          hip: const Offset(104, 135),
          elbow: const Offset(145, 116),
          hand: const Offset(164, 117),
          farElbow: const Offset(137, 113),
          farHand: const Offset(159, 118),
          nearKnee: Offset(end ? 116 : 143, end ? 164 : 140),
          nearFoot: Offset(end ? 141 : 131, end ? 182 : 173),
          farKnee: Offset(end ? 142 : 116, end ? 141 : 165),
          farFoot: Offset(end ? 131 : 141, end ? 172 : 181),
        );
      case ExerciseMovementFamily.mobility:
        return standing(
          top: Offset(end ? 132 : 120, end ? 65 : 52),
          shoulder: Offset(end ? 124 : 120, end ? 91 : 78),
          hip: const Offset(116, 137),
          elbow: Offset(end ? 161 : 133, end ? 71 : 48),
          hand: Offset(end ? 182 : 134, end ? 51 : 21),
          farElbow: Offset(end ? 102 : 106, end ? 114 : 104),
          farHand: Offset(end ? 96 : 101, end ? 142 : 135),
        );
      case ExerciseMovementFamily.carry:
        return standing(
          nearKnee: Offset(end ? 99 : 133, 169),
          nearFoot: Offset(end ? 85 : 151, 203),
          farKnee: Offset(end ? 133 : 99, 169),
          farFoot: Offset(end ? 152 : 85, 203),
        );
      case ExerciseMovementFamily.rotation:
        return standing(
          elbow: Offset(end ? 153 : 108, 104),
          hand: Offset(end ? 177 : 83, 109),
          farElbow: Offset(end ? 143 : 98, 107),
          farHand: Offset(end ? 169 : 80, 113),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _MovementPainter oldDelegate) =>
      family != oldDelegate.family ||
      phase != oldDelegate.phase ||
      dark != oldDelegate.dark ||
      muscle != oldDelegate.muscle ||
      equipment != oldDelegate.equipment;
}
