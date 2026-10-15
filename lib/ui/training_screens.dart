import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';
import '../domain/training_analytics.dart';
import '../state/app_store.dart';
import '../services/workout_clock.dart';
import 'theme.dart';
import 'exercise_image.dart';
import 'live_workout_advice_card.dart';
import 'live_heart_rate_card.dart';
import 'workout_shortcuts_card.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final _search = TextEditingController();
  String _query = '';
  final _filters = _ExerciseFilters();
  bool _alphabetical = false;
  int get _filterCount => _filters.count;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetFilters() => setState(_filters.clear);

  Future<void> _favorite(Exercise exercise) async {
    try {
      await widget.store.setExerciseFavorite(
        exercise.id,
        !widget.store.favoriteExerciseIds.contains(exercise.id),
      );
    } catch (_) {
      if (mounted) _message(context, 'Your preference could not be saved.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final exercises = widget.store.exercises;
          List<String> options(String Function(Exercise) value) =>
              exercises
                  .map(value)
                  .where((value) => value.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          final muscles = options((exercise) => exercise.muscle);
          final equipment = options((exercise) => exercise.equipment);
          final difficulties = options((exercise) => exercise.difficulty);
          final categories = options((exercise) => exercise.category);
          final query = _searchText(_query.trim());
          final filtered = _filters.apply(
            exercises,
            favorites: widget.store.favoriteExerciseIds,
            query: query,
          );
          if (_alphabetical) {
            filtered.sort(
              (a, b) => _searchText(a.name).compareTo(_searchText(b.name)),
            );
          }
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: _Eyebrow('EXERCISES')),
                          Icon(
                            Icons.auto_awesome_outlined,
                            size: 20,
                            color: _accent(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Find your next move.',
                        style: TextStyle(
                          fontSize: 31,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${exercises.length} exercises. Find the right move for you.',
                        style: TextStyle(
                          color: PiColors.muted(context),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _search,
                        onChanged: (value) => setState(() => _query = value),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 22,
                          ),
                          hintText: 'Exercise, muscle or equipment',
                          hintStyle: const TextStyle(fontSize: 13),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _search.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 42,
                  child: ListView.separated(
                    key: const ValueKey('exercise-muscles'),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    scrollDirection: Axis.horizontal,
                    itemCount: muscles.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final label = index == 0 ? 'All' : muscles[index - 1];
                      return _FilterPill(
                        label: label,
                        selected: label == _filters.muscle,
                        onTap: () => setState(() => _filters.muscle = label),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    height: 40,
                    child: ListView(
                      key: const ValueKey('exercise-filters'),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterMenu(
                          label: 'Equipment',
                          value: _filters.equipment,
                          options: equipment,
                          onSelected: (value) =>
                              setState(() => _filters.equipment = value),
                        ),
                        const SizedBox(width: 8),
                        _FilterMenu(
                          label: 'Level',
                          value: _filters.difficulty,
                          options: difficulties,
                          onSelected: (value) =>
                              setState(() => _filters.difficulty = value),
                        ),
                        const SizedBox(width: 8),
                        _FilterMenu(
                          label: 'Category',
                          value: _filters.category,
                          options: categories,
                          onSelected: (value) =>
                              setState(() => _filters.category = value),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          key: const ValueKey('favorites-filter'),
                          label: 'Favorites',
                          selected: _filters.favoritesOnly,
                          onTap: () => setState(
                            () => _filters.favoritesOnly =
                                !_filters.favoritesOnly,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _exerciseCount(filtered.length),
                          style: TextStyle(
                            color: PiColors.muted(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_filterCount > 0)
                        TextButton(
                          onPressed: _resetFilters,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(
                            'Clear filters · $_filterCount',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      PopupMenuButton<bool>(
                        tooltip: 'Sort exercises',
                        initialValue: _alphabetical,
                        onSelected: (value) =>
                            setState(() => _alphabetical = value),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: false,
                            child: Text('Library order'),
                          ),
                          PopupMenuItem(value: true, child: Text('Name · A–Z')),
                        ],
                        icon: const Icon(Icons.sort_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyState(
                    icon: _filters.favoritesOnly
                        ? Icons.favorite_border_rounded
                        : Icons.search_off_rounded,
                    title: _filters.favoritesOnly
                        ? 'Keep your favorite moves'
                        : 'No exercises found',
                    description: _filters.favoritesOnly
                        ? 'Tap the heart on an exercise to find it here.'
                        : 'Try another name or clear the filters.',
                    action: _filterCount == 0
                        ? null
                        : TextButton(
                            onPressed: _resetFilters,
                            child: const Text('Reset filters'),
                          ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final exercise = filtered[index];
                    final favorite = widget.store.favoriteExerciseIds.contains(
                      exercise.id,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ExerciseTile(
                        exercise: exercise,
                        onTap: () => _showExercise(
                          context,
                          exercise,
                          store: widget.store,
                        ),
                        trailing: IconButton(
                          tooltip: favorite
                              ? 'Remove from favorites: ${exercise.name}'
                              : 'Add to favorites: ${exercise.name}',
                          onPressed: () => _favorite(exercise),
                          icon: Icon(
                            favorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 20,
                            color: favorite
                                ? _accent(context)
                                : PiColors.muted(context),
                          ),
                        ),
                      ),
                    );
                  }, childCount: filtered.length),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
    this.onOpened,
  });
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Filter by ${label.toLowerCase()}',
    initialValue: value,
    onOpened: onOpened,
    onSelected: onSelected,
    constraints: const BoxConstraints(maxHeight: 480, minWidth: 190),
    itemBuilder: (_) => ['All', ...options]
        .map(
          (option) => PopupMenuItem(
            value: option,
            child: Text(option == 'All' ? 'All · $label' : option),
          ),
        )
        .toList(),
    child: Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: value == 'All'
            ? PiColors.surface(context).withValues(alpha: .55)
            : _accent(context).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value == 'All' ? label : value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: value == 'All'
                  ? PiColors.muted(context)
                  : _accent(context),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: PiColors.muted(context),
          ),
        ],
      ),
    ),
  );
}

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  String _category = 'All';

  Future<void> _createRoutine() async {
    final routine = await Navigator.of(context).push<Routine>(
      MaterialPageRoute(builder: (_) => _RoutineBuilder(store: widget.store)),
    );
    if (routine == null || !mounted) return;
    try {
      await widget.store.saveRoutine(routine);
      if (mounted) {
        _message(context, 'Routine “${routine.name}” saved.');
      }
    } catch (error) {
      if (mounted) {
        _message(context, 'The routine could not be saved. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final categories = widget.store.routines
              .map((routine) => routine.category)
              .toSet()
              .toList();
          final routines = widget.store.routines
              .where(
                (routine) =>
                    _category == 'All' || routine.category == _category,
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              const _Eyebrow('YOUR PLAN. YOUR PACE.'),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Workouts.',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.4,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Create routine',
                    onPressed: _createRoutine,
                    style: IconButton.styleFrom(
                      backgroundColor: PiColors.lime,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'A good plan makes room for progress.',
                style: TextStyle(color: PiColors.muted(context), height: 1.5),
              ),
              const SizedBox(height: 24),
              if (widget.store.activeSession != null) ...[
                PiCard(
                  onTap: () => _openActive(context, widget.store),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: PiColors.lime,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Workout in progress',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.store.activeSession!.routineName,
                              style: TextStyle(
                                color: PiColors.muted(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              PiCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: PiColors.lime,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Make today your own.',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Start an empty workout and add exercises as you go.',
                      style: TextStyle(
                        color: PiColors.muted(context),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _startTraining(context, widget.store),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start empty workout'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              SectionHeading(
                title: 'Routines',
                action: 'Create',
                onAction: _createRoutine,
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length + 1,
                  separatorBuilder: (_, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final label = index == 0 ? 'All' : categories[index - 1];
                    return _FilterPill(
                      label: label,
                      selected: label == _category,
                      onTap: () => setState(() => _category = label),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              if (routines.isEmpty)
                const _EmptyState(
                  icon: Icons.fitness_center_rounded,
                  title: 'Your next plan starts here',
                  description: 'Build a routine with your favorite exercises.',
                ),
              for (var index = 0; index < routines.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _RoutineCard(
                    routine: routines[index],
                    number: index + 1,
                    store: widget.store,
                    onDetail: () =>
                        _showRoutine(context, widget.store, routines[index]),
                    onStart: () => _startTraining(
                      context,
                      widget.store,
                      routine: routines[index],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final _clock = WorkoutClock.instance;
  DateTime? _alertedRestDeadline;
  bool _saving = false;
  final _notes = TextEditingController();

  int get _restRemaining => _clock.remaining;
  int get _restDuration => _clock.restSeconds;

  @override
  void initState() {
    super.initState();
    final session = widget.store.activeSession;
    if (session != null) {
      _clock.bind(
        sessionId: session.id,
        startedAt: session.startedAt,
        accountId: widget.store.accountId,
        preferences: widget.store.preferences,
      );
    }
    if (_clock.remaining == 0) _alertedRestDeadline = _clock.restEndsAt;
    _clock.addListener(_clockChanged);
  }

  void _clockChanged() {
    if (!mounted) return;
    final deadline = _clock.restEndsAt;
    if (deadline != null &&
        _clock.remaining == 0 &&
        deadline != _alertedRestDeadline) {
      _alertedRestDeadline = deadline;
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.alert);
      _message(context, 'Rest complete. Ready for your next set?');
    }
    setState(() {});
  }

  @override
  void dispose() {
    _clock.removeListener(_clockChanged);
    _notes.dispose();
    super.dispose();
  }

  void _startRest() => _clock.startRest();

  Future<void> _addExercise() async {
    final exercise = await _pickExercise(context, widget.store);
    if (exercise == null || !mounted) return;
    await _perform(() => widget.store.addExercise(exercise.id));
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _message(context, 'The change could not be saved. Please try again.');
      }
    }
  }

  Future<void> _rateEffort(int exerciseIndex, int setIndex) async {
    FocusScope.of(context).unfocus();
    final current =
        widget.store.activeSession?.exercises[exerciseIndex].sets[setIndex];
    if (current == null || !isValidCompletedSet(current)) return;
    final rating = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How hard was your last set?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Rate the effort you felt in set ${setIndex + 1}. Optional; this is separate from exercise difficulty.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: PiColors.muted(context),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var value = 1; value <= 10; value++)
                    ChoiceChip(
                      label: Text('$value'),
                      selected: current.rpe == value,
                      onSelected: (_) =>
                          Navigator.pop(context, value.toDouble()),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '1 = very easy · 10 = maximum effort',
                style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
              ),
              if (current.rpe != null)
                TextButton(
                  onPressed: () => Navigator.pop(context, 0.0),
                  child: const Text('Clear effort rating'),
                ),
            ],
          ),
        ),
      ),
    );
    if (rating == null || !mounted) return;
    await _perform(
      () => widget.store.updateSet(
        exerciseIndex,
        setIndex,
        rpe: rating == 0 ? null : rating,
        clearRpe: rating == 0,
      ),
    );
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this workout?'),
        content: const Text(
          'This workout’s sets will be deleted. Previously saved workouts remain in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Discard',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.store.discardWorkout();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _message(context, 'The workout could not be deleted.');
    }
  }

  Future<void> _finish() async {
    FocusScope.of(context).unfocus();
    final session = widget.store.activeSession;
    if (session == null || _saving) return;
    final live = _LiveWorkoutTotals.fromSession(session, widget.store);
    if (live.completedSets == 0) {
      _message(context, 'Complete at least one set before saving.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish this workout?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_setCount(live.completedSets)} completed · ${live.reps} reps · ${_volume(live.volume)} kg external volume\nOnly valid completed sets count toward your progress.',
                style: TextStyle(color: PiColors.muted(context), height: 1.6),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _notes,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'How did it feel? Add optional notes.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep training'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.store.finishWorkout(notes: _notes.text.trim());
      if (!mounted) return;
      _message(context, 'Workout saved. Another step forward!');
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _message(
          context,
          'The workout could not be saved. Your data is still available.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final session = widget.store.activeSession;
      final live = session == null
          ? null
          : _LiveWorkoutTotals.fromSession(session, widget.store);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Active workout'),
          actions: [
            TextButton(
              onPressed: _saving ? null : _finish,
              child: Text(
                _saving ? 'Saving…' : 'Finish',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: session == null
            ? const _EmptyState(
                icon: Icons.fitness_center_rounded,
                title: 'No active workout',
                description: 'Choose a routine or start an empty workout.',
              )
            : SafeArea(
                top: false,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    const _Eyebrow('STAY PRESENT. GET STRONGER.'),
                    const SizedBox(height: 10),
                    Text(
                      session.routineName,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _LiveWorkoutSummary(
                      session: session,
                      totals: live!,
                      elapsed: _clock.elapsed,
                    ),
                    const LiveHeartRateReadout(),
                    const SizedBox(height: 18),
                    _restCard(context),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: const Text(
                        'Watch & workout shortcuts',
                        style: TextStyle(fontSize: 13),
                      ),
                      leading: const Icon(Icons.watch_outlined, size: 20),
                      children: [
                        LiveHeartRateCard(store: widget.store),
                        const SizedBox(height: 12),
                        WorkoutShortcutsCard(store: widget.store),
                        const SizedBox(height: 12),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (session.exercises.isEmpty)
                      const _EmptyState(
                        icon: Icons.add_circle_outline_rounded,
                        title: 'Your first exercise is waiting',
                        description: 'Add an exercise and log every set.',
                      ),
                    for (
                      var exerciseIndex = 0;
                      exerciseIndex < session.exercises.length;
                      exerciseIndex++
                    )
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          children: [
                            _workoutExercise(context, session, exerciseIndex),
                            if (session.exercises[exerciseIndex].sets.any(
                              isValidCompletedSet,
                            )) ...[
                              const SizedBox(height: 10),
                              LiveWorkoutAdviceCard(
                                key: ValueKey('advice-$exerciseIndex'),
                                store: widget.store,
                                exerciseIndex: exerciseIndex,
                              ),
                            ],
                          ],
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _addExercise,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add exercise'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _finish,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Finish and save'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _saving ? null : _discard,
                      child: const Text(
                        'Discard workout',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    Text(
                      'Your active workout is saved as you train. Rest time stays synchronized with your workout notification.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: PiColors.muted(context),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
      );
    },
  );

  Widget _restCard(BuildContext context) {
    final remaining = _restRemaining;
    return PiCard(
      padding: const EdgeInsets.fromLTRB(15, 10, 8, 10),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.hourglass_bottom_rounded,
                color: _accent(context),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      remaining > 0
                          ? 'Breathe. Come back stronger.'
                          : 'Rest between sets',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      remaining > 0
                          ? _seconds(remaining)
                          : '${_restDuration}s · after each completed set',
                      style: TextStyle(
                        color: PiColors.muted(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<int>(
                tooltip: 'Rest duration',
                initialValue: _restDuration,
                icon: Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: PiColors.muted(context),
                ),
                itemBuilder: (_) => [30, 60, 90, 120]
                    .map(
                      (seconds) => PopupMenuItem(
                        value: seconds,
                        child: Text('${seconds}s'),
                      ),
                    )
                    .toList(),
                onSelected: (seconds) {
                  final running = _clock.remaining > 0;
                  _clock.selectRestSeconds(seconds);
                  if (running) _clock.startRest();
                },
              ),
              IconButton(
                tooltip: remaining > 0 ? 'Skip rest' : 'Start rest',
                onPressed: remaining > 0 ? _clock.skipRest : _startRest,
                icon: Icon(
                  remaining > 0
                      ? Icons.close_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
            ],
          ),
          if (remaining > 0)
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (remaining / _restDuration).clamp(0.0, 1.0),
                      minHeight: 3,
                      color: _accent(context),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _clock.extendRest(30),
                  child: const Text('+30s', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _workoutExercise(
    BuildContext context,
    WorkoutSession session,
    int exerciseIndex,
  ) {
    final workoutExercise = session.exercises[exerciseIndex];
    final exercise = widget.store.exerciseById(workoutExercise.exerciseId);
    final progress = _LiveExerciseProgress.fromSession(
      session,
      exercise,
      widget.store.history,
    );
    final ratedIndex = workoutExercise.sets.lastIndexWhere(isValidCompletedSet);
    final lastSet = ratedIndex >= 0 ? workoutExercise.sets[ratedIndex] : null;
    return PiCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showExercise(context, exercise, store: widget.store),
            child: Row(
              children: [
                ExerciseImage(
                  exercise: exercise,
                  width: 52,
                  height: 58,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${exercise.muscle} · ${exercise.equipment}',
                        style: TextStyle(
                          color: PiColors.muted(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: PiColors.muted(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _LiveExercisePanel(exercise: exercise, progress: progress),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(width: 32, child: _columnLabel(context, 'SET')),
              const SizedBox(width: 8),
              Expanded(child: _columnLabel(context, 'KG')),
              const SizedBox(width: 10),
              Expanded(child: _columnLabel(context, 'REPS')),
              const SizedBox(width: 8),
              SizedBox(width: 42, child: _columnLabel(context, 'DONE')),
              const SizedBox(width: 30),
            ],
          ),
          const SizedBox(height: 8),
          for (
            var setIndex = 0;
            setIndex < workoutExercise.sets.length;
            setIndex++
          )
            _WorkoutSetRow(
              key: ValueKey('${session.id}:$exerciseIndex:$setIndex'),
              number: setIndex + 1,
              set: workoutExercise.sets[setIndex],
              onChanged: (reps, weight, completed) async {
                await _perform(
                  () => widget.store.updateSet(
                    exerciseIndex,
                    setIndex,
                    reps: reps,
                    weight: weight,
                    completed: completed,
                  ),
                );
                if (completed == true && mounted) {
                  HapticFeedback.lightImpact();
                  _startRest();
                }
              },
              onRemove: () {
                FocusScope.of(context).unfocus();
                _perform(() => widget.store.removeSet(exerciseIndex, setIndex));
              },
            ),
          if (lastSet != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Last set effort · set ${ratedIndex + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        color: PiColors.muted(context),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: ValueKey('rate-effort-$exerciseIndex'),
                    onPressed: _saving
                        ? null
                        : () => _rateEffort(exerciseIndex, ratedIndex),
                    icon: const Icon(Icons.speed_rounded, size: 16),
                    label: Text(
                      lastSet.rpe == null
                          ? 'Rate effort'
                          : 'RPE ${_volume(lastSet.rpe!)}/10',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _saving
                  ? null
                  : () => _perform(() => widget.store.addSet(exerciseIndex)),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Add set', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _columnLabel(BuildContext context, String label) => Text(
    label,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 9,
      letterSpacing: 1,
      fontWeight: FontWeight.w700,
      color: PiColors.muted(context),
    ),
  );
}

class _WorkoutSetRow extends StatefulWidget {
  const _WorkoutSetRow({
    super.key,
    required this.number,
    required this.set,
    required this.onChanged,
    required this.onRemove,
  });

  final int number;
  final WorkoutSet set;
  final void Function(int? reps, double? weight, bool? completed) onChanged;
  final VoidCallback onRemove;

  @override
  State<_WorkoutSetRow> createState() => _WorkoutSetRowState();
}

class _WorkoutSetRowState extends State<_WorkoutSetRow> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;
  final _weightFocus = FocusNode();
  final _repsFocus = FocusNode();

  double? get _parsedWeight =>
      double.tryParse(_weight.text.replaceAll(',', '.'));
  int? get _parsedReps => int.tryParse(_reps.text);
  bool get _validWeight =>
      _parsedWeight != null &&
      _parsedWeight!.isFinite &&
      _parsedWeight! >= 0 &&
      _parsedWeight! <= 2000;
  bool get _validReps =>
      _parsedReps != null && _parsedReps! > 0 && _parsedReps! <= 999;

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(text: _weightValue(widget.set.weight));
    _reps = TextEditingController(text: '${widget.set.reps}');
  }

  @override
  void didUpdateWidget(covariant _WorkoutSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_weightFocus.hasFocus && oldWidget.set.weight != widget.set.weight) {
      _weight.text = _weightValue(widget.set.weight);
    }
    if (!_repsFocus.hasFocus && oldWidget.set.reps != widget.set.reps) {
      _reps.text = '${widget.set.reps}';
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    if (_validWeight && _validReps) {
      widget.onChanged(_parsedReps, _parsedWeight, null);
    } else if (widget.set.completed) {
      // An invalid edit must not retain the previously completed prescription.
      widget.onChanged(null, null, false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            '${widget.number}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: widget.set.completed ? _accent(context) : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _numberField(
            context,
            controller: _weight,
            focusNode: _weightFocus,
            valid: _validWeight,
            label: 'Set ${widget.number} weight, kg',
            decimal: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _numberField(
            context,
            controller: _reps,
            focusNode: _repsFocus,
            valid: _validReps,
            label: 'Set ${widget.number} reps',
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          height: 46,
          child: IconButton(
            tooltip: widget.set.completed
                ? 'Mark set incomplete'
                : 'Mark set complete',
            onPressed: _validWeight && _validReps
                ? () {
                    FocusScope.of(context).unfocus();
                    widget.onChanged(
                      _parsedReps,
                      _parsedWeight,
                      !widget.set.completed,
                    );
                  }
                : null,
            style: IconButton.styleFrom(
              backgroundColor: widget.set.completed
                  ? PiColors.lime
                  : PiColors.surface(context),
              foregroundColor: widget.set.completed
                  ? Colors.black
                  : PiColors.muted(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.check_rounded, size: 21),
          ),
        ),
        SizedBox(
          width: 30,
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: 'Delete set ${widget.number}',
            onPressed: widget.onRemove,
            icon: Icon(
              Icons.remove_circle_outline_rounded,
              size: 17,
              color: PiColors.muted(context),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _numberField(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool valid,
    required String label,
    bool decimal = false,
  }) => Semantics(
    label: label,
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: (_) => _changed(),
      onTap: () => controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      ),
      textAlign: TextAlign.center,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp('[0-9.,]') : RegExp('[0-9]'),
        ),
        LengthLimitingTextInputFormatter(decimal ? 7 : 3),
      ],
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: valid ? Colors.transparent : Colors.redAccent,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: valid ? PiColors.lime : Colors.redAccent,
          ),
        ),
      ),
    ),
  );
}

class _RoutineBuilder extends StatefulWidget {
  const _RoutineBuilder({required this.store});
  final AppStore store;

  @override
  State<_RoutineBuilder> createState() => _RoutineBuilderState();
}

class _RoutineBuilderState extends State<_RoutineBuilder> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  final List<RoutineExercise> _exercises = [];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final selected = await _pickExercises(
      context,
      widget.store,
      multiple: true,
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    setState(
      () => _exercises.addAll(
        selected.map((exercise) => RoutineExercise(exerciseId: exercise.id)),
      ),
    );
  }

  Future<void> _edit(int index) async {
    final exercise = _exercises[index];
    final sets = TextEditingController(text: '${exercise.sets}');
    final reps = TextEditingController(text: '${exercise.reps}');
    final weight = TextEditingController(text: _weightValue(exercise.weight));
    final form = GlobalKey<FormState>();
    final updated = await showDialog<RoutineExercise>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.store.exerciseById(exercise.exerciseId).name),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: sets,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sets'),
                  validator: (value) => _integerError(value, 1, 20),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reps,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps / set'),
                  validator: (value) => _integerError(value, 1, 999),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    helperText: '0 for bodyweight',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(
                      (value ?? '').replaceAll(',', '.'),
                    );
                    return parsed == null ||
                            !parsed.isFinite ||
                            parsed < 0 ||
                            parsed > 2000
                        ? 'Enter a weight between 0 and 2000 kg.'
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  context,
                  exercise.copyWith(
                    sets: int.parse(sets.text),
                    reps: int.parse(reps.text),
                    weight: double.parse(weight.text.replaceAll(',', '.')),
                  ),
                );
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    // Controllers belong to the dialog; dispose after its route transition.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    sets.dispose();
    reps.dispose();
    weight.dispose();
    if (updated != null && mounted) setState(() => _exercises[index] = updated);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (_exercises.isEmpty) {
      _message(context, 'Add at least one exercise.');
      return;
    }
    Navigator.pop(
      context,
      Routine(
        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        subtitle: 'Made by you, at your own pace.',
        exercises: List.of(_exercises),
        estimatedMinutes:
            (_exercises.fold<int>(
                      0,
                      (total, exercise) => total + exercise.sets,
                    ) *
                    2.5)
                .ceil(),
        category: 'Custom',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your routine'),
      actions: [TextButton(onPressed: _save, child: const Text('Save'))],
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _Eyebrow('BUILD WHAT WORKS FOR YOU'),
          const SizedBox(height: 14),
          const Text(
            'A plan that fits you.',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 22),
          TextFormField(
            controller: _name,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Routine name',
              hintText: 'e.g. Upper body · Monday',
            ),
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Give your routine a name.'
                : null,
          ),
          const SizedBox(height: 20),
          SectionHeading(title: 'Exercises', action: 'Add', onAction: _add),
          const SizedBox(height: 14),
          if (_exercises.isEmpty)
            const _EmptyState(
              icon: Icons.playlist_add_rounded,
              title: 'Choose your first exercise',
              description:
                  'Tap an added exercise to edit its sets, reps and weight.',
            ),
          for (var index = 0; index < _exercises.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PiCard(
                onTap: () => _edit(index),
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                child: Row(
                  children: [
                    Text(
                      '${index + 1}'.padLeft(2, '0'),
                      style: TextStyle(
                        color: PiColors.muted(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.store
                                .exerciseById(_exercises[index].exerciseId)
                                .name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${_exercises[index].sets} sets × ${_exercises[index].reps} reps · ${_weightValue(_exercises[index].weight)} kg',
                            style: TextStyle(
                              color: PiColors.muted(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove exercise',
                      onPressed: () =>
                          setState(() => _exercises.removeAt(index)),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add exercise'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save routine')),
        ],
      ),
    ),
  );
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.number,
    required this.store,
    required this.onDetail,
    required this.onStart,
  });
  final Routine routine;
  final int number;
  final AppStore store;
  final VoidCallback onDetail;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => PiCard(
    padding: const EdgeInsets.all(18),
    onTap: onDetail,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (routine.exercises.isNotEmpty) ...[
              ExerciseImage(
                exercise: store.exerciseById(
                  routine.exercises.first.exerciseId,
                ),
                width: 76,
                height: 88,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(17),
              ),
              const SizedBox(width: 15),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${routine.category.toUpperCase()} · ${number.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: _accent(context),
                      fontSize: 8,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    routine.name,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    routine.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: PiColors.muted(context),
                      height: 1.5,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _RoutineMeta(
              icon: Icons.schedule_rounded,
              label: '~${routine.estimatedMinutes} min',
            ),
            _RoutineMeta(
              icon: Icons.fitness_center_rounded,
              label:
                  '${routine.exercises.length} exercises · ${routine.totalSets} sets',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          routine.exercises
              .take(3)
              .map((item) => store.exerciseById(item.exerciseId).name)
              .join('  /  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: PiColors.muted(context),
            fontSize: 10,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: onDetail,
                child: const Text(
                  'View routine',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded, size: 17),
                label: const Text('Start'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _RoutineMeta extends StatelessWidget {
  const _RoutineMeta({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: PiColors.muted(context)),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(color: PiColors.muted(context), fontSize: 10),
      ),
    ],
  );
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    super.key,
    required this.exercise,
    required this.onTap,
    this.trailing,
  });
  final Exercise exercise;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => PiCard(
    onTap: onTap,
    padding: const EdgeInsets.all(10),
    child: Row(
      children: [
        ExerciseImage(
          exercise: exercise,
          width: 80,
          height: 92,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(17),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.muscle.toUpperCase(),
                style: TextStyle(
                  fontSize: 8,
                  color: _accent(context),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                exercise.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.3,
                  letterSpacing: -.2,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                [
                  exercise.equipment,
                  exercise.difficulty,
                ].where((value) => value.isNotEmpty).join(' · '),
                style: TextStyle(
                  fontSize: 10,
                  height: 1.4,
                  color: PiColors.muted(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 2),
        trailing ??
            Icon(
              Icons.chevron_right_rounded,
              color: PiColors.muted(context),
              size: 20,
            ),
      ],
    ),
  );
}

class _LiveWorkoutTotals {
  const _LiveWorkoutTotals({
    required this.completedSets,
    required this.reps,
    required this.volume,
  });
  final int completedSets;
  final int reps;
  final double volume;

  factory _LiveWorkoutTotals.fromSession(
    WorkoutSession session,
    AppStore store,
  ) {
    var completedSets = 0;
    var reps = 0;
    var volume = 0.0;
    for (final item in session.exercises) {
      final weighted = isWeightedStrengthExercise(
        store.exerciseById(item.exerciseId),
      );
      for (final set in item.sets.where(isValidCompletedSet)) {
        completedSets++;
        reps += set.reps;
        if (weighted) volume += set.weight * set.reps;
      }
    }
    return _LiveWorkoutTotals(
      completedSets: completedSets,
      reps: reps,
      volume: volume,
    );
  }
}

class _LiveWorkoutSummary extends StatelessWidget {
  const _LiveWorkoutSummary({
    required this.session,
    required this.totals,
    required this.elapsed,
  });
  final WorkoutSession session;
  final _LiveWorkoutTotals totals;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) => PiCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _LiveStat(
                valueKey: 'live-duration',
                value: _duration(elapsed),
                label: 'DURATION',
              ),
            ),
            Expanded(
              child: _LiveStat(
                valueKey: 'live-completed-sets',
                value: '${totals.completedSets}/${session.totalSets}',
                label: 'SETS',
              ),
            ),
            Expanded(
              child: _LiveStat(
                valueKey: 'live-reps',
                value: '${totals.reps}',
                label: 'REPS',
              ),
            ),
            Expanded(
              child: Tooltip(
                message:
                    'External volume = kg × reps from completed strength sets. Bodyweight, cardio and mobility are excluded.',
                child: _LiveStat(
                  valueKey: 'live-volume',
                  value: _volume(totals.volume),
                  label: 'VOLUME · KG',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Semantics(
          label:
              '${totals.completedSets} of ${session.totalSets} sets completed',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: session.totalSets == 0
                  ? 0
                  : totals.completedSets / session.totalSets,
              minHeight: 4,
              color: _accent(context),
              backgroundColor: _accent(context).withValues(alpha: .09),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${totals.completedSets} of ${session.totalSets} sets completed · ${session.totalSets - totals.completedSets} remaining',
            key: const ValueKey('live-planned-completed'),
            style: TextStyle(fontSize: 10, color: PiColors.muted(context)),
          ),
        ),
      ],
    ),
  );
}

class _LiveStat extends StatelessWidget {
  const _LiveStat({
    required this.valueKey,
    required this.value,
    required this.label,
  });
  final String valueKey;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.w600,
          color: PiColors.muted(context),
          letterSpacing: .6,
        ),
      ),
      const SizedBox(height: 7),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          key: ValueKey(valueKey),
          style: const TextStyle(
            fontSize: 21,
            letterSpacing: -.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

/// Totals and comparisons are scoped to the exact exercise ID. Duplicate blocks
/// in a session are aggregated, and unfinished/future history cannot set a PR.
class _LiveExerciseProgress {
  const _LiveExerciseProgress({
    required this.completedSets,
    required this.plannedSets,
    required this.reps,
    required this.volume,
    required this.previous,
    required this.previousSetCount,
    required this.previousReps,
    required this.previousVolume,
    required this.estimatedOneRepMax,
    required this.previousEstimatedOneRepMax,
    required this.maxWeight,
    required this.previousMaxWeight,
  });
  final int completedSets;
  final int plannedSets;
  final int reps;
  final double volume;
  final WorkoutSession? previous;
  final int previousSetCount;
  final int previousReps;
  final double previousVolume;
  final double? estimatedOneRepMax;
  final double? previousEstimatedOneRepMax;
  final double maxWeight;
  final double previousMaxWeight;

  bool get estimatedRecord =>
      estimatedOneRepMax != null &&
      previousEstimatedOneRepMax != null &&
      estimatedOneRepMax! > previousEstimatedOneRepMax! + .000001;
  bool get weightRecord =>
      previousMaxWeight > 0 && maxWeight > previousMaxWeight + .000001;

  factory _LiveExerciseProgress.fromSession(
    WorkoutSession session,
    Exercise exercise,
    List<WorkoutSession> history,
  ) {
    List<WorkoutSet> setsIn(WorkoutSession item) => item.exercises
        .where((item) => item.exerciseId == exercise.id)
        .expand((item) => item.sets)
        .toList();
    final current = setsIn(session);
    final done = current.where(isValidCompletedSet).toList();
    final weighted = isWeightedStrengthExercise(exercise);
    final past =
        history
            .where(
              (item) =>
                  item.id != session.id &&
                  item.finishedAt != null &&
                  !item.finishedAt!.isAfter(session.startedAt) &&
                  !item.finishedAt!.isBefore(item.startedAt) &&
                  setsIn(item).any(isValidCompletedSet),
            )
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final previous = past.isEmpty ? null : past.first;
    final previousSets = previous == null
        ? <WorkoutSet>[]
        : setsIn(previous).where(isValidCompletedSet).toList();
    final historicalSets = past
        .expand(setsIn)
        .where(isValidCompletedSet)
        .toList();
    double volume(List<WorkoutSet> sets) =>
        weighted ? sets.fold(0, (sum, set) => sum + set.weight * set.reps) : 0;
    double? estimate(List<WorkoutSet> sets) {
      double? best;
      for (final set in sets) {
        final value = estimateOneRepMax(exercise, set);
        if (value != null && (best == null || value > best)) best = value;
      }
      return best;
    }

    double weight(List<WorkoutSet> sets) => weighted
        ? sets.fold(0, (best, set) => set.weight > best ? set.weight : best)
        : 0;
    return _LiveExerciseProgress(
      completedSets: done.length,
      plannedSets: current.length,
      reps: done.fold(0, (sum, set) => sum + set.reps),
      volume: volume(done),
      previous: previous,
      previousSetCount: previousSets.length,
      previousReps: previousSets.fold(0, (sum, set) => sum + set.reps),
      previousVolume: volume(previousSets),
      estimatedOneRepMax: estimate(done),
      previousEstimatedOneRepMax: estimate(historicalSets),
      maxWeight: weight(done),
      previousMaxWeight: weight(historicalSets),
    );
  }
}

class _LiveExercisePanel extends StatelessWidget {
  const _LiveExercisePanel({required this.exercise, required this.progress});
  final Exercise exercise;
  final _LiveExerciseProgress progress;

  @override
  Widget build(BuildContext context) {
    final weighted = isWeightedStrengthExercise(exercise);
    final previous = progress.previous;
    final record = progress.estimatedRecord || progress.weightRecord;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: record
            ? _accent(context).withValues(alpha: .08)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: record
              ? _accent(context).withValues(alpha: .20)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Now · ${progress.completedSets}/${_setCount(progress.plannedSets)} · ${progress.reps} reps${weighted ? ' · ${_volume(progress.volume)} kg volume' : ''}',
            key: ValueKey('live-exercise-${exercise.id}'),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            previous == null
                ? 'Your first baseline for this exercise.'
                : 'Previous (${formatDate(previous.startedAt.toLocal())}) · ${_setCount(progress.previousSetCount)} · ${progress.previousReps} reps${weighted ? ' · ${_volume(progress.previousVolume)} kg' : ''}',
            key: ValueKey('live-previous-${exercise.id}'),
            style: TextStyle(
              fontSize: 9,
              color: PiColors.muted(context),
              height: 1.5,
            ),
          ),
          if (progress.estimatedOneRepMax != null) ...[
            const SizedBox(height: 5),
            Tooltip(
              message:
                  'Epley estimate: kg × (1 + reps / 30), only completed strength sets with 1–12 reps. This is not a weight recommendation.',
              child: Text(
                'Estimated 1RM · ${_volume(progress.estimatedOneRepMax!)} kg',
                key: ValueKey('live-1rm-${exercise.id}'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: record ? _accent(context) : PiColors.muted(context),
                ),
              ),
            ),
          ] else if (progress.previousEstimatedOneRepMax != null) ...[
            const SizedBox(height: 5),
            Text(
              'Previous record · ${_volume(progress.previousEstimatedOneRepMax!)} kg Estimated 1RM',
              style: TextStyle(fontSize: 9, color: PiColors.muted(context)),
            ),
          ],
          if (record) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 14,
                  color: _accent(context),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    progress.estimatedRecord
                        ? 'Estimated 1RM record · +${_volume(progress.estimatedOneRepMax! - progress.previousEstimatedOneRepMax!)} kg versus ${_volume(progress.previousEstimatedOneRepMax!)} kg'
                        : 'Weight record · ${_volume(progress.maxWeight)} kg (previous ${_volume(progress.previousMaxWeight)} kg)',
                    key: ValueKey('live-pr-${exercise.id}'),
                    style: TextStyle(
                      fontSize: 9,
                      color: _accent(context),
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: Theme.of(context).brightness == Brightness.dark
          ? PiColors.lime
          : const Color(0xFF527500),
      fontSize: 9,
      fontWeight: FontWeight.w800,
      letterSpacing: 2.1,
    ),
  );
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? _accent(context).withValues(alpha: .15)
        : PiColors.surface(context).withValues(alpha: .55),
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: selected ? _accent(context) : PiColors.muted(context),
          ),
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
    child: Column(
      children: [
        Icon(icon, size: 38, color: PiColors.muted(context)),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            color: PiColors.muted(context),
            height: 1.6,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    ),
  );
}

Future<void> _showExercise(
  BuildContext context,
  Exercise exercise, {
  AppStore? store,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ExerciseDetail(exercise: exercise, store: store),
);

class _ExerciseDetail extends StatefulWidget {
  const _ExerciseDetail({required this.exercise, this.store});
  final Exercise exercise;
  final AppStore? store;

  @override
  State<_ExerciseDetail> createState() => _ExerciseDetailState();
}

class _ExerciseDetailState extends State<_ExerciseDetail> {
  bool _tips = false;
  bool _adding = false;

  Future<void> _favorite() async {
    final store = widget.store;
    if (store == null) return;
    try {
      await store.setExerciseFavorite(
        widget.exercise.id,
        !store.favoriteExerciseIds.contains(widget.exercise.id),
      );
    } catch (_) {
      if (mounted) _message(context, 'Your preference could not be saved.');
    }
  }

  Future<void> _addToWorkout() async {
    final store = widget.store;
    if (store == null || store.activeSession == null || _adding) return;
    setState(() => _adding = true);
    try {
      await store.addExercise(widget.exercise.id);
      if (mounted) {
        _message(context, 'Exercise added to your active workout.');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) _message(context, 'The exercise could not be added.');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    if (store != null) {
      return AnimatedBuilder(
        animation: store,
        builder: (_, _) => _body(context),
      );
    }
    return _body(context);
  }

  Widget _body(BuildContext context) {
    final exercise = widget.exercise;
    final store = widget.store;
    final favorite = store?.favoriteExerciseIds.contains(exercise.id) ?? false;
    final related =
        store?.exercises
            .where(
              (item) =>
                  item.id != exercise.id &&
                  item.muscle == exercise.muscle &&
                  item.movement.isNotEmpty &&
                  item.movement == exercise.movement,
            )
            .take(3)
            .toList() ??
        <Exercise>[];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .88,
      minChildSize: .45,
      maxChildSize: .95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
        children: [
          Stack(
            children: [
              _ExerciseGallery(exercise: exercise),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (store != null)
                      _ImageAction(
                        tooltip: favorite
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                        onPressed: _favorite,
                        icon: favorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        selected: favorite,
                      ),
                    const SizedBox(width: 6),
                    _ImageAction(
                      tooltip: 'Close exercise details',
                      icon: Icons.close_rounded,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              exerciseIllustrationCredit,
              style: TextStyle(fontSize: 9, color: PiColors.muted(context)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              'Movement-family illustration. Follow the exercise instructions for this variation.',
              style: TextStyle(
                fontSize: 9,
                height: 1.5,
                color: PiColors.muted(context),
              ),
            ),
          ),
          if (exercise.sourceName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'Exercise source: ${exercise.sourceName}',
                maxLines: 2,
                style: TextStyle(
                  fontSize: 9,
                  height: 1.4,
                  color: PiColors.muted(context),
                ),
              ),
            ),
          const SizedBox(height: 20),
          _Eyebrow(exercise.muscle.toUpperCase()),
          const SizedBox(height: 8),
          Text(
            exercise.name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (exercise.instructionLanguage == 'en')
                const _DetailTag(label: 'English instructions'),
              for (final label in [
                exercise.equipment,
                exercise.difficulty,
                exercise.category,
              ])
                if (label.isNotEmpty) _DetailTag(label: label),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            exercise.description,
            style: TextStyle(
              color: PiColors.muted(context),
              height: 1.65,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),
          PiCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.accessibility_new_rounded,
                      size: 19,
                      color: _accent(context),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Target muscles',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  exercise.muscle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (exercise.secondaryMuscles.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Secondary muscles',
                    style: TextStyle(
                      color: PiColors.muted(context),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    exercise.secondaryMuscles,
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Technique'),
                  icon: Icon(Icons.format_list_numbered_rounded, size: 17),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Tips'),
                  icon: Icon(Icons.lightbulb_outline_rounded, size: 17),
                ),
              ],
              selected: {_tips},
              onSelectionChanged: (values) =>
                  setState(() => _tips = values.first),
              showSelectedIcon: false,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            _tips ? 'Details make the difference' : 'How to perform',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -.3,
            ),
          ),
          const SizedBox(height: 16),
          if ((_tips ? exercise.tips : exercise.steps).isEmpty)
            Text(
              'Instructions for this movement are not available yet.',
              style: TextStyle(color: PiColors.muted(context), fontSize: 12),
            ),
          for (
            var index = 0;
            index < (_tips ? exercise.tips : exercise.steps).length;
            index++
          )
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _accent(context).withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _tips
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: _accent(context),
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: _accent(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      (_tips ? exercise.tips : exercise.steps)[index],
                      style: const TextStyle(height: 1.65, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (related.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Same movement, different variations',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -.3,
              ),
            ),
            const SizedBox(height: 14),
            for (final variation in related)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ExerciseTile(
                  exercise: variation,
                  onTap: () => _showExercise(context, variation, store: store),
                ),
              ),
          ],
          if (store?.activeSession != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _adding ? null : _addToWorkout,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add to active workout'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseGallery extends StatefulWidget {
  const _ExerciseGallery({required this.exercise});
  final Exercise exercise;

  @override
  State<_ExerciseGallery> createState() => _ExerciseGalleryState();
}

class _ExerciseGalleryState extends State<_ExerciseGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final count = exerciseIllustrationPoseCount(widget.exercise);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 232,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: count,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (_, index) => ExerciseImage(
                exercise: widget.exercise,
                imageIndex: index,
                fit: BoxFit.contain,
                borderRadius: BorderRadius.zero,
              ),
            ),
            if (count > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .64),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var index = 0; index < count; index++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _page == index ? 15 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _page == index
                                  ? PiColors.lime
                                  : Colors.white54,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        const SizedBox(width: 7),
                        Text(
                          '${_page + 1}/$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailTag extends StatelessWidget {
  const _DetailTag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: PiColors.surface(context).withValues(alpha: .65),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: PiColors.muted(context),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _ImageAction extends StatelessWidget {
  const _ImageAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: .60),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 19,
        color: selected ? PiColors.lime : Colors.white,
      ),
    ),
  );
}

Future<void> _showRoutine(
  BuildContext context,
  AppStore store,
  Routine routine,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheetContext) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .75,
    maxChildSize: .94,
    minChildSize: .35,
    builder: (sheetBodyContext, controller) => ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 36),
      children: [
        _Eyebrow(routine.category.toUpperCase()),
        const SizedBox(height: 10),
        Text(
          routine.name,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          routine.subtitle,
          style: TextStyle(color: PiColors.muted(context), height: 1.6),
        ),
        const SizedBox(height: 18),
        Text(
          '~${routine.estimatedMinutes} min · ${routine.totalSets} sets',
          style: TextStyle(color: PiColors.muted(context), fontSize: 12),
        ),
        const SizedBox(height: 24),
        for (final exercise in routine.exercises)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ExerciseTile(
              exercise: store.exerciseById(exercise.exerciseId),
              onTap: () => _showExercise(
                context,
                store.exerciseById(exercise.exerciseId),
                store: store,
              ),
              trailing: Text(
                '${exercise.sets} × ${exercise.reps}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(sheetContext);
            _startTraining(context, store, routine: routine);
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start workout'),
        ),
      ],
    ),
  ),
);

/// The workout and routine builder use the same chooser and predicate as the
/// library. Filtering never changes which exercise a row adds.
Future<Exercise?> _pickExercise(BuildContext context, AppStore store) async {
  final selected = await _pickExercises(context, store);
  return selected != null && selected.length == 1 ? selected.single : null;
}

Future<List<Exercise>?> _pickExercises(
  BuildContext context,
  AppStore store, {
  bool multiple = false,
}) => Navigator.of(context).push<List<Exercise>>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _ExercisePicker(store: store, multiple: multiple),
  ),
);

class _ExerciseFilters {
  String muscle = 'All';
  String equipment = 'All';
  String difficulty = 'All';
  String category = 'All';
  bool favoritesOnly = false;

  int get count => [
    muscle != 'All',
    equipment != 'All',
    difficulty != 'All',
    category != 'All',
    favoritesOnly,
  ].where((value) => value).length;

  void clear() {
    muscle = 'All';
    equipment = 'All';
    difficulty = 'All';
    category = 'All';
    favoritesOnly = false;
  }

  List<Exercise> apply(
    List<Exercise> exercises, {
    required Set<String> favorites,
    required String query,
  }) => exercises
      .where(
        (exercise) =>
            (muscle == 'All' || exercise.muscle == muscle) &&
            (equipment == 'All' || exercise.equipment == equipment) &&
            (difficulty == 'All' || exercise.difficulty == difficulty) &&
            (category == 'All' || exercise.category == category) &&
            (!favoritesOnly || favorites.contains(exercise.id)) &&
            _matchesExercise(exercise, query),
      )
      .toList();
}

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker({required this.store, required this.multiple});
  final AppStore store;
  final bool multiple;

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  final _search = TextEditingController();
  final _filters = _ExerciseFilters();
  final _selectedIds = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _choose(Exercise exercise) {
    if (!widget.multiple) {
      Navigator.pop(context, [exercise]);
      return;
    }
    setState(() {
      if (!_selectedIds.add(exercise.id)) _selectedIds.remove(exercise.id);
    });
  }

  void _confirm() {
    if (_selectedIds.isEmpty) return;
    Navigator.pop(
      context,
      _selectedIds.map(widget.store.exerciseById).toList(),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final exercises = widget.store.exercises;
      List<String> options(String Function(Exercise) value) =>
          exercises
              .map(value)
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      final filtered = _filters.apply(
        exercises,
        favorites: widget.store.favoriteExerciseIds,
        query: _search.text,
      );
      final outsideFilters =
          filtered.isEmpty &&
              _filters.count > 0 &&
              _search.text.trim().isNotEmpty
          ? exercises
                .where((exercise) => _matchesExercise(exercise, _search.text))
                .length
          : 0;
      final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
      Widget menu(
        String label,
        String value,
        String Function(Exercise) property,
        ValueChanged<String> onSelected,
      ) => _FilterMenu(
        label: label,
        value: value,
        options: options(property),
        onOpened: () => FocusScope.of(context).unfocus(),
        onSelected: (value) => setState(() => onSelected(value)),
      );
      return Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close exercise selector',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
          title: Text(
            widget.multiple ? 'Choose exercises' : 'Add exercise',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          actions: [
            if (widget.multiple)
              TextButton(
                onPressed: _selectedIds.isEmpty ? null : _confirm,
                child: Text('Done (${_selectedIds.length})'),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: TextField(
                  key: const ValueKey('picker-search'),
                  controller: _search,
                  autofocus: false,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Name, muscle, equipment · EN / RO',
                    hintStyle: const TextStyle(fontSize: 12),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear exercise search',
                            onPressed: () => setState(_search.clear),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  key: const ValueKey('picker-filters'),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  children: [
                    menu(
                      'Muscle',
                      _filters.muscle,
                      (exercise) => exercise.muscle,
                      (value) => _filters.muscle = value,
                    ),
                    const SizedBox(width: 8),
                    menu(
                      'Equipment',
                      _filters.equipment,
                      (exercise) => exercise.equipment,
                      (value) => _filters.equipment = value,
                    ),
                    const SizedBox(width: 8),
                    menu(
                      'Level',
                      _filters.difficulty,
                      (exercise) => exercise.difficulty,
                      (value) => _filters.difficulty = value,
                    ),
                    const SizedBox(width: 8),
                    menu(
                      'Category',
                      _filters.category,
                      (exercise) => exercise.category,
                      (value) => _filters.category = value,
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      key: const ValueKey('picker-favorites'),
                      label: 'Favorites',
                      selected: _filters.favoritesOnly,
                      onTap: () => setState(
                        () => _filters.favoritesOnly = !_filters.favoritesOnly,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 14, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          '${_exerciseCount(filtered.length)}${widget.multiple && _selectedIds.isNotEmpty ? ' · ${_selectedIds.length} selected' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: PiColors.muted(context),
                          ),
                        ),
                      ),
                    ),
                    if (_filters.count > 0)
                      TextButton(
                        key: const ValueKey('picker-reset-filters'),
                        onPressed: () => setState(_filters.clear),
                        child: Text(
                          'Clear filters · ${_filters.count}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      )
                    else
                      const SizedBox(height: 38),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          _EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No exercises found',
                            description: outsideFilters > 0
                                ? '$outsideFilters matching exercises are outside your selected filters.'
                                : 'Try an English or Romanian name, or clear the filters.',
                            action: _filters.count > 0
                                ? TextButton(
                                    key: const ValueKey(
                                      'picker-search-without-filters',
                                    ),
                                    onPressed: () => setState(_filters.clear),
                                    child: Text(
                                      outsideFilters > 0
                                          ? 'Search without filters'
                                          : 'Reset filters',
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      )
                    : ListView.separated(
                        key: const ValueKey('picker-results'),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final exercise = filtered[index];
                          final selected = _selectedIds.contains(exercise.id);
                          return Semantics(
                            selected: widget.multiple ? selected : null,
                            child: _ExerciseTile(
                              key: ValueKey('picker-exercise-${exercise.id}'),
                              exercise: exercise,
                              onTap: () => _choose(exercise),
                              trailing: Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                                color: selected
                                    ? _accent(context)
                                    : PiColors.muted(context),
                                size: 24,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (widget.multiple && !keyboardOpen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _selectedIds.isEmpty ? null : _confirm,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(
                        _selectedIds.isEmpty
                            ? 'Select exercises'
                            : 'Add ${_exerciseCount(_selectedIds.length)}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _startTraining(
  BuildContext context,
  AppStore store, {
  Routine? routine,
}) async {
  if (store.activeSession != null) {
    final resume = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('You have an active workout'),
        content: const Text(
          'Resume your current workout. Finish or discard it before starting another.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resume workout'),
          ),
        ],
      ),
    );
    if (resume == true && context.mounted) _openActive(context, store);
    return;
  }
  try {
    if (routine != null) {
      await store.startWorkout(routine);
    } else {
      await store.startEmptyWorkout();
    }
    if (context.mounted) _openActive(context, store);
  } catch (error) {
    if (context.mounted) {
      _message(context, 'The workout could not be started. Please try again.');
    }
  }
}

void _openActive(BuildContext context, AppStore store) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/workout'),
        builder: (_) => ActiveWorkoutScreen(store: store),
      ),
    );

void _message(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

String _duration(Duration duration) =>
    '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
String _seconds(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
String _volume(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
String _weightValue(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
Color _accent(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? PiColors.lime
    : const Color(0xFF527500);
String? _integerError(String? value, int minimum, int maximum) {
  final parsed = int.tryParse(value ?? '');
  return parsed == null || parsed < minimum || parsed > maximum
      ? 'Enter a number between $minimum and $maximum.'
      : null;
}

String _setCount(int count) => '$count ${count == 1 ? 'set' : 'sets'}';

String _exerciseCount(int count) =>
    '$count ${count == 1 ? 'exercise' : 'exercises'}';

bool _matchesExercise(Exercise exercise, String query) {
  final haystack = _exerciseSearch(exercise);
  return _searchText(
    query,
  ).trim().split(RegExp(r'\s+')).every(haystack.contains);
}

String _exerciseSearch(Exercise exercise) => _searchText(
  '${exercise.name} ${exercise.muscle} ${exercise.equipment} ${exercise.secondaryMuscles} ${exercise.difficulty} ${exercise.category} ${exercise.movement} ${exercise.aliases.join(' ')}',
);

String _searchText(String value) {
  var normalized = value.toLowerCase();
  const replacements = {
    'ă': 'a',
    'â': 'a',
    'î': 'i',
    'ș': 's',
    'ş': 's',
    'ț': 't',
    'ţ': 't',
  };
  replacements.forEach(
    (source, target) => normalized = normalized.replaceAll(source, target),
  );
  return normalized;
}
