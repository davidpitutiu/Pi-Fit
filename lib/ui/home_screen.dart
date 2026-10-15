import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../domain/models.dart';
import '../state/app_store.dart';
import '../services/firebase_gateway.dart';
import 'account_coach.dart';
import 'exercise_image.dart';
import 'theme.dart';
import 'training_screens.dart';

class HomeScreen extends StatelessWidget {
  final AppStore store;
  final ValueChanged<int> onNavigate;
  const HomeScreen({super.key, required this.store, required this.onNavigate});

  Future<void> _start(BuildContext context, [Routine? routine]) async {
    try {
      if (routine == null) {
        await store.startEmptyWorkout();
      } else {
        await store.startWorkout(routine);
      }
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/workout'),
            builder: (_) => ActiveWorkoutScreen(store: store),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        toast(context, error.toString().replaceFirst('Bad state: ', ''));
      }
    }
  }

  void _coach(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => CoachScreen(store: store)));
  void _routines(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => RoutinesScreen(store: store)));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: StreamBuilder<User?>(
      stream: FirebaseGateway.instance.authStateChanges,
      builder: (context, auth) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final upcoming =
              store.schedule
                  .where((event) => event.date.isAfter(DateTime.now()))
                  .toList()
                ..sort((a, b) => a.date.compareTo(b.date));
          final next = upcoming.isEmpty ? null : upcoming.first;
          final nextRoutine = next == null
              ? null
              : store.routineById(next.routineId);
          final score = store.analytics;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final greeting = now.hour < 12
              ? 'Good morning'
              : now.hour < 18
              ? 'Good afternoon'
              : 'Good evening';
          final user = auth.data ?? FirebaseGateway.instance.currentUser;
          final heroExercise = store.exerciseById(
            nextRoutine?.exercises.firstOrNull?.exerciseId ?? 'deadlift',
          );
          final narrow = MediaQuery.sizeOf(context).width < 360;
          return PageBody(
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: PiColors.lime,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Center(
                      child: Text(
                        'π',
                        style: TextStyle(
                          color: Color(0xFF18270A),
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 60,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'pi fit',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 100,
                    child: TextButton.icon(
                      onPressed: () => _coach(context),
                      icon: const Icon(Icons.auto_awesome_outlined, size: 15),
                      label: const Text(
                        'Pi Coach',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: PiColors.lime.withValues(alpha: 0.09),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Semantics(
                    button: true,
                    label: 'Open profile',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onNavigate(4),
                      child: CircleAvatar(
                        radius: 19,
                        backgroundColor: PiColors.surface(
                          context,
                        ).withValues(alpha: 0.65),
                        child: Text(
                          store.name.characters.first.toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 27),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting, ${store.name.split(' ').first}',
                          style: TextStyle(
                            fontSize: 12,
                            color: PiColors.muted(context),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Move with purpose.',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(fontSize: narrow ? 28 : 32),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PiCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 10,
                    ),
                    radius: 16,
                    onTap: () => onNavigate(2),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 15,
                            ),
                            Text(
                              '${score.streak.activeDaysThisWeek}/${score.streak.targetDaysPerWeek}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'days this week',
                          style: TextStyle(
                            fontSize: 8,
                            color: PiColors.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 21),
              _WorkoutHero(
                exercise: heroExercise,
                active: store.activeSession != null,
                title: store.activeSession != null
                    ? store.activeSession!.routineName
                    : nextRoutine?.name,
                caption: next != null
                    ? '${formatDate(next.date)} · ${formatTime(next.date)}'
                    : null,
                onStart: () => _start(context, nextRoutine),
                onRoutines: () => _routines(context),
              ),
              const SizedBox(height: 14),
              if (user == null)
                PiCard(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                  radius: 20,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: PiColors.lime.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.person_add_alt_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your progress deserves a home.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Your profile and backup, together.',
                              style: TextStyle(
                                fontSize: 10,
                                color: PiColors.muted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sign in or create an account',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AuthScreen(store: store),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                      ),
                    ],
                  ),
                )
              else
                PiCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  radius: 20,
                  onTap: () => onNavigate(4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_done_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 19,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Signed in · manage profile and backups',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              SectionHeading(
                title: 'Your consistency',
                action: 'Details',
                onAction: () => onNavigate(2),
              ),
              PiCard(
                onTap: () => onNavigate(2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 84,
                            height: 84,
                            child: CircularProgressIndicator(
                              value: (score.score ?? 0) / 100,
                              strokeWidth: 6,
                              strokeCap: StrokeCap.round,
                              backgroundColor: PiColors.line(context),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                score.score?.round().toString() ?? '—',
                                style: const TextStyle(
                                  fontSize: 31,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -1,
                                ),
                              ),
                              Text(
                                score.score == null
                                    ? 'First step'
                                    : 'out of 100',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: PiColors.muted(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            score.score == null
                                ? 'Start at your own pace.'
                                : 'A habit, built by you.',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            score.score == null
                                ? 'Save your first workout to start tracking your progress.'
                                : '${score.activeDaysLast28} active days out of ${score.targetDaysLast28} planned over the last 28 days.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.55,
                              color: PiColors.muted(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'How it is calculated  ↗',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PiCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 17,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        value: score.workoutCountLast28.toString(),
                        label: 'sessions · 28 days',
                      ),
                    ),
                    Container(
                      height: 30,
                      width: 1,
                      color: PiColors.line(context),
                    ),
                    Expanded(
                      child: _Stat(
                        value: score.completedSetsLast28.toString(),
                        label: 'completed sets',
                      ),
                    ),
                    Container(
                      height: 30,
                      width: 1,
                      color: PiColors.line(context),
                    ),
                    Expanded(
                      child: _Stat(
                        value: score.volumeLast28 >= 1000
                            ? '${(score.volumeLast28 / 1000).toStringAsFixed(1)} t'
                            : '${score.volumeLast28.toStringAsFixed(0)} kg',
                        label: 'external volume',
                      ),
                    ),
                  ],
                ),
              ),
              SectionHeading(
                title: 'Your week',
                action: 'Calendar',
                onAction: () => onNavigate(3),
              ),
              PiCard(
                padding: const EdgeInsets.all(17),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) {
                    final day = DateTime(
                      today.year,
                      today.month,
                      today.day - today.weekday + 1 + i,
                    );
                    final done = store.history.any(
                      (s) =>
                          s.finishedAt != null &&
                          s.completedSets > 0 &&
                          s.startedAt.year == day.year &&
                          s.startedAt.month == day.month &&
                          s.startedAt.day == day.day &&
                          !s.startedAt.isAfter(now),
                    );
                    final planned = store.schedule.any(
                      (s) =>
                          s.date.year == day.year &&
                          s.date.month == day.month &&
                          s.date.day == day.day,
                    );
                    final isToday = day == today;
                    return Column(
                      children: [
                        Text(
                          const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                          style: TextStyle(
                            fontSize: 9,
                            color: PiColors.muted(context),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Container(
                          width: narrow ? 29 : 34,
                          height: 38,
                          decoration: BoxDecoration(
                            color: done
                                ? PiColors.lime
                                : (isToday
                                      ? PiColors.lime.withValues(alpha: 0.10)
                                      : Colors.transparent),
                            border: Border.all(
                              color: isToday
                                  ? Theme.of(context).colorScheme.primary
                                  : PiColors.line(context),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: done
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 17,
                                    color: Color(0xFF1B2A09),
                                  )
                                : Text(
                                    day.day.toString(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: planned
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
              PiCard(
                onTap: () => onNavigate(2),
                padding: const EdgeInsets.all(17),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: PiColors.lime.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.local_fire_department_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            score.currentStreakWeeks == 0
                                ? 'Build your first streak'
                                : '${score.currentStreakWeeks} ${score.currentStreakWeeks == 1 ? 'week' : 'weeks'} in a row',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Weekly streak · best ${score.bestStreakWeeks}. Rest days belong here too.',
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.5,
                              color: PiColors.muted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
              ),
              SectionHeading(
                title: 'Routines, your way',
                action: 'See all',
                onAction: () => _routines(context),
              ),
              SizedBox(
                height: 208,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: store.routines.take(5).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final routine = store.routines[i];
                    final photo = store.exerciseById(
                      routine.exercises.firstOrNull?.exerciseId ?? 'squat',
                    );
                    return SizedBox(
                      width: 200,
                      child: PiCard(
                        padding: EdgeInsets.zero,
                        onTap: () => _routines(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 120,
                              width: 200,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ExerciseImage(
                                    exercise: photo,
                                    borderRadius: BorderRadius.zero,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    left: 10,
                                    top: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF13251B,
                                        ).withValues(alpha: 0.78),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        routine.category,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    routine.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${routine.exercises.length} exercises · ${routine.estimatedMinutes} min',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: PiColors.muted(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
              PiCard(
                onTap: () => _coach(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                PiColors.lime.withValues(alpha: 0.22),
                                PiColors.mint.withValues(alpha: 0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Pi Coach',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const Icon(Icons.north_east_rounded, size: 20),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'A plan that fits your life.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${store.profile.experience} · ${store.profile.sessionsPerWeek} days per week · ${store.profile.sessionMinutes} min per session',
                      style: TextStyle(
                        fontSize: 11,
                        color: PiColors.muted(context),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Profile, history and personal guidance',
                            style: TextStyle(
                              fontSize: 10,
                              color: PiColors.muted(context),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (store.profile.age == null && store.profile.equipment.isEmpty)
                PiCard(
                  onTap: () => onNavigate(4),
                  padding: const EdgeInsets.all(17),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, size: 21),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Make it yours.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Complete your profile and set your own pace.',
                              style: TextStyle(
                                fontSize: 10,
                                color: PiColors.muted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _WorkoutHero extends StatelessWidget {
  final Exercise exercise;
  final bool active;
  final String? title, caption;
  final VoidCallback onStart, onRoutines;
  const _WorkoutHero({
    required this.exercise,
    required this.active,
    this.title,
    this.caption,
    required this.onStart,
    required this.onRoutines,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFF183227),
      borderRadius: BorderRadius.circular(27),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.63,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0xFF5D7B64),
                BlendMode.multiply,
              ),
              child: ExerciseImage(
                exercise: exercise,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF0E2118).withValues(alpha: 0.96),
                  const Color(0xFF0C2417).withValues(alpha: 0.70),
                  const Color(0xFF0E2118).withValues(alpha: 0.13),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  const Color(0xFF0C2017).withValues(alpha: 0.82),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(23, 25, 23, 21),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: PiColors.lime,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    active
                        ? 'WORKOUT IN PROGRESS'
                        : caption != null
                        ? 'PLANNED FOR YOU'
                        : 'YOUR NEXT SESSION',
                    style: const TextStyle(
                      color: Color(0xFFCFDBC8),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 19),
              Text(
                active
                    ? 'Pick up where\nyou left off.'
                    : title ?? 'Show up.\nFeel the progress.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                caption ?? 'Every set counts. We keep track.',
                style: const TextStyle(
                  color: Color(0xFFC0D0C4),
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 23),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(
                        active ? 'Resume workout' : 'Start workout',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: onRoutines,
                    tooltip: 'Choose a routine',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(15),
                    ),
                    icon: const Icon(Icons.grid_view_outlined, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.8,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(fontSize: 8, color: PiColors.muted(context)),
      ),
    ],
  );
}
