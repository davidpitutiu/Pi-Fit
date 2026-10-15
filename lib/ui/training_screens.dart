import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';
import '../state/app_store.dart';
import 'theme.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  String _query = '';
  String _muscle = 'Toate';
  String _equipment = 'Toate';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            final exercises = widget.store.exercises;
            final muscles =
                exercises.map((exercise) => exercise.muscle).toSet().toList()
                  ..sort();
            final equipment =
                exercises.map((exercise) => exercise.equipment).toSet().toList()
                  ..sort();
            final filtered = exercises.where((exercise) {
              final query = _searchText(_query.trim());
              return (_muscle == 'Toate' || exercise.muscle == _muscle) &&
                  (_equipment == 'Toate' || exercise.equipment == _equipment) &&
                  (query.isEmpty ||
                      _searchText(
                        '${exercise.name} ${exercise.muscle} ${exercise.equipment} ${exercise.secondaryMuscles}',
                      ).contains(query));
            }).toList();
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Eyebrow('MIȘCARE CU SENS'),
                        const SizedBox(height: 10),
                        const Text(
                          'Biblioteca ta.',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${exercises.length} exerciții. Fiecare repetare, explicată.',
                          style: TextStyle(
                            color: PiColors.muted(context),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          onChanged: (value) => setState(() => _query = value),
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            hintText: 'Caută exerciții, mușchi, echipament',
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 42,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      scrollDirection: Axis.horizontal,
                      itemCount: muscles.length + 1,
                      separatorBuilder: (_, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final label = index == 0 ? 'Toate' : muscles[index - 1];
                        return _FilterPill(
                          label: label,
                          selected: label == _muscle,
                          onTap: () => setState(() => _muscle = label),
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${filtered.length} exerciții',
                            style: TextStyle(
                              color: PiColors.muted(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          initialValue: _equipment,
                          onSelected: (value) =>
                              setState(() => _equipment = value),
                          itemBuilder: (context) => ['Toate', ...equipment]
                              .map(
                                (label) => PopupMenuItem(
                                  value: label,
                                  child: Text(
                                    label == 'Toate'
                                        ? 'Tot echipamentul'
                                        : label,
                                  ),
                                ),
                              )
                              .toList(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.tune_rounded, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  _equipment == 'Toate'
                                      ? 'Echipament'
                                      : _equipment,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: _EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Niciun exercițiu găsit',
                      description: 'Încearcă alt nume sau elimină filtrele.',
                      action: TextButton(
                        onPressed: () => setState(() {
                          _muscle = 'Toate';
                          _equipment = 'Toate';
                        }),
                        child: const Text('Resetează filtrele'),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ExerciseTile(
                          exercise: filtered[index],
                          onTap: () => _showExercise(context, filtered[index]),
                        ),
                      ),
                      childCount: filtered.length,
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
}

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  String _category = 'Toate';

  Future<void> _createRoutine() async {
    final routine = await Navigator.of(context).push<Routine>(
      MaterialPageRoute(builder: (_) => _RoutineBuilder(store: widget.store)),
    );
    if (routine == null || !mounted) return;
    try {
      await widget.store.saveRoutine(routine);
      if (mounted) {
        _message(context, 'Rutina „${routine.name}” a fost salvată.');
      }
    } catch (error) {
      if (mounted) {
        _message(context, 'Rutina nu a putut fi salvată. Încearcă din nou.');
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
                    _category == 'Toate' || routine.category == _category,
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              const _Eyebrow('PLANUL TĂU. RITMUL TĂU.'),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Antrenamente.',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.4,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Creează rutină',
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
                'Un plan bun face loc progresului.',
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
                              'Antrenament în desfășurare',
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
                            'Azi scrii tu planul.',
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
                      'Pornește liber și adaugă exerciții pe parcurs.',
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
                        label: const Text('Începe antrenament liber'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              SectionHeading(
                title: 'Rutine',
                action: 'Creează',
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
                    final label = index == 0 ? 'Toate' : categories[index - 1];
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
                  title: 'Următorul plan începe aici',
                  description:
                      'Creează o rutină cu exercițiile tale preferate.',
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
  Timer? _ticker;
  DateTime? _restUntil;
  int _restDuration = 90;
  bool _saving = false;
  final _notes = TextEditingController();

  int get _restRemaining {
    final end = _restUntil;
    if (end == null) return 0;
    final milliseconds = end.difference(DateTime.now()).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_restUntil != null && _restRemaining == 0) {
        _restUntil = null;
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.alert);
        _message(context, 'Pauza s-a încheiat. Pregătit pentru următorul set?');
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _notes.dispose();
    super.dispose();
  }

  void _startRest() => setState(
    () => _restUntil = DateTime.now().add(Duration(seconds: _restDuration)),
  );

  Future<void> _addExercise() async {
    final exercise = await _pickExercise(context, widget.store.exercises);
    if (exercise == null || !mounted) return;
    await _perform(() => widget.store.addExercise(exercise.id));
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _message(
          context,
          'Modificarea nu a putut fi salvată. Încearcă din nou.',
        );
      }
    }
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renunți la antrenament?'),
        content: const Text(
          'Seturile acestui antrenament vor fi șterse. Progresul salvat anterior rămâne în istoric.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuă'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Renunță',
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
      if (mounted) _message(context, 'Antrenamentul nu a putut fi șters.');
    }
  }

  Future<void> _finish() async {
    FocusScope.of(context).unfocus();
    final session = widget.store.activeSession;
    if (session == null || _saving) return;
    if (session.completedSets == 0) {
      _message(
        context,
        'Bifează cel puțin un set efectuat înainte de a salva.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Antrenament încheiat?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${session.completedSets} seturi efectuate · ${_volume(session.volume)} kg volum\nDoar seturile bifate intră în progres.',
                style: TextStyle(color: PiColors.muted(context), height: 1.6),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _notes,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Cum te-ai simțit? Note opționale.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mai continui'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvează'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.store.finishWorkout(notes: _notes.text.trim());
      if (!mounted) return;
      _message(context, 'Antrenament salvat. Încă un pas înainte!');
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _message(
          context,
          'Antrenamentul nu a putut fi salvat. Datele rămân disponibile.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final session = widget.store.activeSession;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Antrenament în curs'),
          actions: [
            TextButton(
              onPressed: _saving ? null : _finish,
              child: Text(
                _saving ? 'Se salvează…' : 'Încheie',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: session == null
            ? const _EmptyState(
                icon: Icons.fitness_center_rounded,
                title: 'Niciun antrenament activ',
                description: 'Alege o rutină sau începe un antrenament liber.',
              )
            : SafeArea(
                top: false,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    const _Eyebrow('FII PREZENT. FII MAI PUTERNIC.'),
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
                    Row(
                      children: [
                        Expanded(
                          child: _SessionStat(
                            value: _duration(session.duration),
                            label: 'DURATĂ',
                            icon: Icons.timer_outlined,
                          ),
                        ),
                        Expanded(
                          child: _SessionStat(
                            value: _volume(session.volume),
                            label: 'VOLUM · KG',
                            icon: Icons.fitness_center_rounded,
                          ),
                        ),
                        Expanded(
                          child: _SessionStat(
                            value:
                                '${session.completedSets}/${session.totalSets}',
                            label: 'SETURI',
                            icon: Icons.check_circle_outline_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _restCard(context),
                    const SizedBox(height: 24),
                    if (session.exercises.isEmpty)
                      const _EmptyState(
                        icon: Icons.add_circle_outline_rounded,
                        title: 'Primul exercițiu te așteaptă',
                        description:
                            'Adaugă un exercițiu și notează fiecare set.',
                      ),
                    for (
                      var exerciseIndex = 0;
                      exerciseIndex < session.exercises.length;
                      exerciseIndex++
                    )
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _workoutExercise(
                          context,
                          session,
                          exerciseIndex,
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _addExercise,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Adaugă exercițiu'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _finish,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Încheie și salvează'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _saving ? null : _discard,
                      child: const Text(
                        'Renunță la antrenament',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    Text(
                      'Poți reveni în aplicație fără să pierzi antrenamentul. Pauza de pe acest ecran este un temporizator local.',
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.hourglass_bottom_rounded,
                color: PiColors.lime,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      remaining > 0
                          ? 'Respiră. Revino mai puternic.'
                          : 'Pauză între seturi',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      remaining > 0
                          ? _seconds(remaining)
                          : '${_restDuration}s · pornește după fiecare set',
                      style: TextStyle(
                        color: PiColors.muted(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (remaining > 0)
                IconButton(
                  tooltip: 'Oprește pauza',
                  onPressed: () => setState(() => _restUntil = null),
                  icon: const Icon(Icons.close_rounded),
                )
              else
                IconButton(
                  tooltip: 'Pornește pauza',
                  onPressed: _startRest,
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (remaining > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (remaining / _restDuration).clamp(0.0, 1.0),
                minHeight: 4,
                color: PiColors.lime,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final seconds in [30, 60, 90, 120])
                _FilterPill(
                  label: '${seconds}s',
                  selected: _restDuration == seconds,
                  compact: true,
                  onTap: () => setState(() {
                    _restDuration = seconds;
                    if (_restUntil != null) {
                      _restUntil = DateTime.now().add(
                        Duration(seconds: seconds),
                      );
                    }
                  }),
                ),
              if (remaining > 0)
                ActionChip(
                  label: const Text('+30s'),
                  onPressed: () => setState(
                    () => _restUntil = _restUntil!.add(
                      const Duration(seconds: 30),
                    ),
                  ),
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
    return PiCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showExercise(context, exercise),
            child: Row(
              children: [
                _ExerciseGlyph(muscle: exercise.muscle, size: 46),
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
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(width: 32, child: _columnLabel(context, 'SET')),
              const SizedBox(width: 8),
              Expanded(child: _columnLabel(context, 'KG')),
              const SizedBox(width: 10),
              Expanded(child: _columnLabel(context, 'REPS')),
              const SizedBox(width: 8),
              SizedBox(width: 42, child: _columnLabel(context, 'GATA')),
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
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _saving
                  ? null
                  : () => _perform(() => widget.store.addSet(exerciseIndex)),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Adaugă set', style: TextStyle(fontSize: 12)),
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
            label: 'Greutate set ${widget.number}, kg',
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
            label: 'Repetări set ${widget.number}',
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          height: 46,
          child: IconButton(
            tooltip: widget.set.completed
                ? 'Marchează setul neefectuat'
                : 'Marchează setul efectuat',
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
            tooltip: 'Șterge setul ${widget.number}',
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
    final exercise = await _pickExercise(context, widget.store.exercises);
    if (exercise != null && mounted) {
      setState(() => _exercises.add(RoutineExercise(exerciseId: exercise.id)));
    }
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
                  decoration: const InputDecoration(labelText: 'Seturi'),
                  validator: (value) => _integerError(value, 1, 20),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reps,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Repetări / set',
                  ),
                  validator: (value) => _integerError(value, 1, 999),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Greutate (kg)',
                    helperText: '0 pentru greutatea corpului',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(
                      (value ?? '').replaceAll(',', '.'),
                    );
                    return parsed == null ||
                            !parsed.isFinite ||
                            parsed < 0 ||
                            parsed > 2000
                        ? 'Introdu o greutate între 0 și 2000 kg.'
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
            child: const Text('Anulează'),
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
            child: const Text('Aplică'),
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
      _message(context, 'Adaugă cel puțin un exercițiu.');
      return;
    }
    Navigator.pop(
      context,
      Routine(
        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        subtitle: 'Creat de tine, pentru ritmul tău.',
        exercises: List.of(_exercises),
        estimatedMinutes:
            (_exercises.fold<int>(
                      0,
                      (total, exercise) => total + exercise.sets,
                    ) *
                    2.5)
                .ceil(),
        category: 'Personalizat',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Rutina ta'),
      actions: [TextButton(onPressed: _save, child: const Text('Salvează'))],
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _Eyebrow('CREEAZĂ CE ȚI SE POTRIVEȘTE'),
          const SizedBox(height: 14),
          const Text(
            'Un plan pe măsura ta.',
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
              labelText: 'Numele rutinei',
              hintText: 'Ex. Upper body · Luni',
            ),
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Dă un nume rutinei tale.'
                : null,
          ),
          const SizedBox(height: 20),
          SectionHeading(title: 'Exerciții', action: 'Adaugă', onAction: _add),
          const SizedBox(height: 14),
          if (_exercises.isEmpty)
            const _EmptyState(
              icon: Icons.playlist_add_rounded,
              title: 'Alege primul exercițiu',
              description:
                  'Atinge un exercițiu adăugat pentru a modifica seturile, repetările și greutatea.',
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
                            '${_exercises[index].sets} seturi × ${_exercises[index].reps} reps · ${_weightValue(_exercises[index].weight)} kg',
                            style: TextStyle(
                              color: PiColors.muted(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Șterge exercițiul',
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
            label: const Text('Adaugă exercițiu'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Salvează rutina')),
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
    padding: const EdgeInsets.all(20),
    onTap: onDetail,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PLAN ${number.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: PiColors.muted(context),
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: PiColors.lime.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                routine.category.toUpperCase(),
                style: TextStyle(
                  color: _accent(context),
                  fontSize: 9,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Text(
          routine.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          routine.subtitle,
          style: TextStyle(
            color: PiColors.muted(context),
            height: 1.45,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: PiColors.muted(context),
                ),
                const SizedBox(width: 5),
                Text(
                  '~${routine.estimatedMinutes} min',
                  style: TextStyle(
                    color: PiColors.muted(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fitness_center_rounded,
                  size: 15,
                  color: PiColors.muted(context),
                ),
                const SizedBox(width: 5),
                Text(
                  '${routine.exercises.length} exerciții · ${routine.totalSets} seturi',
                  style: TextStyle(
                    color: PiColors.muted(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 17),
        Text(
          routine.exercises
              .take(3)
              .map((exercise) => store.exerciseById(exercise.exerciseId).name)
              .join('  /  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: PiColors.muted(context),
            fontSize: 11,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: onDetail,
                child: const Text(
                  'Vezi rutina',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded, size: 17),
                label: const Text('Începe'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
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
    padding: const EdgeInsets.all(13),
    child: Row(
      children: [
        _ExerciseGlyph(muscle: exercise.muscle),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${exercise.muscle} · ${exercise.equipment}',
                style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
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

class _ExerciseGlyph extends StatelessWidget {
  const _ExerciseGlyph({required this.muscle, this.size = 56});
  final String muscle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalized = _searchText(muscle);
    final icon = normalized.contains('cardio')
        ? Icons.directions_run_rounded
        : normalized.contains('picio') ||
              normalized.contains('cvad') ||
              normalized.contains('femur') ||
              normalized.contains('fesier')
        ? Icons.directions_walk_rounded
        : normalized.contains('abdom') || normalized.contains('core')
        ? Icons.accessibility_new_rounded
        : Icons.fitness_center_rounded;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PiColors.lime.withValues(alpha: .18),
            PiColors.lime.withValues(alpha: .04),
          ],
        ),
        borderRadius: BorderRadius.circular(size * .28),
        border: Border.all(color: PiColors.lime.withValues(alpha: .12)),
      ),
      child: Icon(
        icon,
        size: size * .46,
        color: Theme.of(context).brightness == Brightness.dark
            ? PiColors.lime
            : const Color(0xFF527500),
      ),
    );
  }
}

class _SessionStat extends StatelessWidget {
  const _SessionStat({
    required this.value,
    required this.label,
    required this.icon,
  });
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: PiColors.muted(context), size: 18),
      const SizedBox(height: 10),
      Text(
        value,
        style: const TextStyle(
          fontSize: 23,
          letterSpacing: -.7,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: PiColors.muted(context),
        ),
      ),
    ],
  );
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
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? PiColors.lime : PiColors.surface(context),
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 13 : 17,
          vertical: compact ? 8 : 12,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: compact ? 10 : 11,
            color: selected ? const Color(0xFF121610) : PiColors.muted(context),
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

Future<void> _showExercise(BuildContext context, Exercise exercise) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .78,
        minChildSize: .4,
        maxChildSize: .94,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 36),
          children: [
            Row(
              children: [
                _ExerciseGlyph(muscle: exercise.muscle, size: 70),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Eyebrow(exercise.muscle.toUpperCase()),
                      const SizedBox(height: 7),
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        exercise.equipment,
                        style: TextStyle(
                          color: PiColors.muted(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Text(
              exercise.description,
              style: TextStyle(
                color: PiColors.muted(context),
                height: 1.7,
                fontSize: 14,
              ),
            ),
            if (exercise.secondaryMuscles.isNotEmpty) ...[
              const SizedBox(height: 18),
              PiCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.accessibility_new_rounded, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mușchi secundari',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            exercise.secondaryMuscles,
                            style: TextStyle(
                              color: PiColors.muted(context),
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 26),
            const SectionHeading(title: 'Cum execuți'),
            const SizedBox(height: 16),
            for (var index = 0; index < exercise.steps.length; index++)
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
                        color: PiColors.lime.withValues(alpha: .15),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? PiColors.lime
                              : const Color(0xFF527500),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        exercise.steps[index],
                        style: const TextStyle(height: 1.7, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            if (exercise.tips.isNotEmpty) ...[
              const SizedBox(height: 8),
              const SectionHeading(title: 'Detaliile fac diferența'),
              const SizedBox(height: 14),
              PiCard(
                child: Column(
                  children: [
                    for (final tip in exercise.tips)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 17,
                              color: PiColors.lime,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tip,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );

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
          '~${routine.estimatedMinutes} minute · ${routine.totalSets} seturi',
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
          label: const Text('Începe antrenamentul'),
        ),
      ],
    ),
  ),
);

Future<Exercise?> _pickExercise(
  BuildContext context,
  List<Exercise> exercises,
) => showModalBottomSheet<Exercise>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _ExercisePicker(exercises: exercises),
);

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker({required this.exercises});
  final List<Exercise> exercises;

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.exercises
        .where(
          (exercise) => _searchText(
            '${exercise.name} ${exercise.muscle} ${exercise.equipment}',
          ).contains(_searchText(_query)),
        )
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .82,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Adaugă exercițiu',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.7,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                autofocus: false,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Caută în bibliotecă',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? const SingleChildScrollView(
                      child: _EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Niciun rezultat',
                        description:
                            'Încearcă un alt nume sau o grupă musculară.',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) => _ExerciseTile(
                        exercise: filtered[index],
                        onTap: () => Navigator.pop(context, filtered[index]),
                        trailing: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 22,
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

Future<void> _startTraining(
  BuildContext context,
  AppStore store, {
  Routine? routine,
}) async {
  if (store.activeSession != null) {
    final resume = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ai un antrenament în curs'),
        content: const Text(
          'Continuă sesiunea curentă. O poți încheia sau poți renunța la ea înainte de a începe alta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Înapoi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuă sesiunea'),
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
      _message(
        context,
        'Antrenamentul nu a putut fi pornit. Încearcă din nou.',
      );
    }
  }
}

void _openActive(BuildContext context, AppStore store) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ActiveWorkoutScreen(store: store)),
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
      ? 'Introdu un număr între $minimum și $maximum.'
      : null;
}

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
