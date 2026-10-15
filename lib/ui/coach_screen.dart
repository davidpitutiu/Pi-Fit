import 'package:flutter/material.dart';

import '../domain/coach_plan.dart';
import '../services/coach_plan_service.dart';
import '../services/coach_service.dart';
import '../services/firebase_gateway.dart';
import '../state/app_store.dart';
import 'account_coach.dart' show editTrainingProfile;
import 'theme.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, required this.store, this.service});
  final AppStore store;
  final CoachPlanService? service;
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final CoachPlanService _service;
  final _messages = <({String text, bool user, CoachProposal? proposal})>[];
  String? _accountId, _targetRoutineId;
  int _generation = 0;
  bool _busy = false;
  final _applied = <String>{};
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CoachPlanService();
    _accountId = widget.store.accountId;
    widget.store.addListener(_changed);
  }

  void _changed() {
    if (_accountId == widget.store.accountId) return;
    _generation++;
    _accountId = widget.store.accountId;
    _input.clear();
    if (mounted) {
      setState(() {
        _messages.clear();
        _applied.clear();
        _busy = false;
        _targetRoutineId = null;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _generation++;
    widget.store.removeListener(_changed);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  });
  Future<void> _send([String? suggestion]) async {
    final question = (suggestion ?? _input.text).trim();
    if (question.isEmpty || _busy) return;
    final generation = ++_generation;
    final history = _messages
        .skip(_messages.length > 12 ? _messages.length - 12 : 0)
        .map((m) => {'role': m.user ? 'user' : 'assistant', 'content': m.text})
        .toList();
    setState(() {
      _messages.add((text: question, user: true, proposal: null));
      _busy = true;
      _input.clear();
    });
    _bottom();
    try {
      final reply = await _service.reply(
        question,
        store: widget.store,
        history: history,
        targetRoutineId: _targetRoutineId,
      );
      if (mounted && generation == _generation) {
        setState(
          () => _messages.add((
            text: reply.message,
            user: false,
            proposal: reply.proposal,
          )),
        );
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () =>
              _messages.add((text: _error(error), user: false, proposal: null)),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        _bottom();
      }
    }
  }

  Future<void> _review(CoachProposal proposal) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CoachPlanReviewScreen(store: widget.store, proposal: proposal),
      ),
    );
    if (mounted && result == true && _accountId == proposal.accountId) {
      setState(() => _applied.add(proposal.id));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final profile = widget.store.profile;
      final online =
          CoachService().remoteConfigured &&
          profile.coachConsent &&
          FirebaseGateway.instance.currentUser != null;
      final customs = widget.store.customRoutines;
      if (!customs.any((r) => r.id == _targetRoutineId)) {
        _targetRoutineId = null;
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pi Coach'),
          actions: [
            IconButton(
              tooltip: 'Training preferences',
              onPressed: () => editTrainingProfile(context, widget.store),
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 17,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        online
                            ? 'Online AI · tailored to you'
                            : 'Local coach · tailored to you',
                        style: TextStyle(
                          color: PiColors.muted(context),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    if (_messages.isEmpty) ...[
                      Text(
                        'A plan that\nfits your life.',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 13),
                      Text(
                        'Build a program, adjust your routines and turn advice into something you can actually follow.',
                        style: TextStyle(color: PiColors.muted(context)),
                      ),
                      const SizedBox(height: 20),
                      PiCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.store.goal,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${profile.experience} · ${profile.sessionsPerWeek} days/week · ${profile.sessionMinutes} min',
                              style: TextStyle(color: PiColors.muted(context)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              profile.equipment.isEmpty
                                  ? 'Add your equipment for a better fit.'
                                  : profile.equipment.join(' · '),
                            ),
                            TextButton(
                              onPressed: () =>
                                  editTrainingProfile(context, widget.store),
                              child: const Text('Adjust my profile'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (customs.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        key: ValueKey(_targetRoutineId),
                        initialValue: _targetRoutineId ?? '',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'What are we working on?',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Create a new program'),
                          ),
                          ...customs.map(
                            (r) => DropdownMenuItem(
                              value: r.id,
                              child: Text(
                                'Edit: ${r.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: _busy
                            ? null
                            : (v) => setState(
                                () => _targetRoutineId = v == '' ? null : v,
                              ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_messages.isEmpty) ...[
                      for (final prompt in [
                        'Create a ${profile.sessionsPerWeek}-day workout program for my equipment.',
                        if (_targetRoutineId != null)
                          'Add an exercise to this routine.',
                        if (_targetRoutineId != null)
                          'Modify this routine to fit ${profile.sessionMinutes} minutes.',
                        'Review my recent training and effort ratings.',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: PiCard(
                            onTap: _busy ? null : () => _send(prompt),
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    prompt,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.north_east_rounded, size: 17),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Plans are previews until you apply them. Your active workout and past sessions are kept as recorded.',
                        style: TextStyle(
                          fontSize: 12,
                          color: PiColors.muted(context),
                        ),
                      ),
                    ],
                    for (final item in _messages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Column(
                          crossAxisAlignment: item.user
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            PiCard(
                              padding: const EdgeInsets.all(17),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.user ? 'YOU' : 'PI COACH',
                                    style: TextStyle(
                                      fontSize: 9,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  SelectableText(item.text),
                                  if (item.proposal != null) ...[
                                    const SizedBox(height: 14),
                                    const Divider(),
                                    const SizedBox(height: 9),
                                    Text(
                                      item.proposal!.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${item.proposal!.routines.length} routines · ${item.proposal!.routines.fold<int>(0, (sum, r) => sum + r.exercises.length)} exercise entries',
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                      key: const Key('review-coach-plan'),
                                      onPressed:
                                          _applied.contains(item.proposal!.id)
                                          ? null
                                          : () => _review(item.proposal!),
                                      icon: Icon(
                                        _applied.contains(item.proposal!.id)
                                            ? Icons.check_rounded
                                            : Icons.playlist_add_check_rounded,
                                      ),
                                      label: Text(
                                        _applied.contains(item.proposal!.id)
                                            ? 'Applied to your routines'
                                            : 'Review & apply',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 5, 15, 12),
                child: TextField(
                  key: const Key('coach-message'),
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 3000,
                  decoration: InputDecoration(
                    hintText: 'Ask, create or adjust a workout…',
                    counterText: '',
                    suffixIcon: IconButton(
                      tooltip: 'Send',
                      onPressed: _busy ? null : () => _send(),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class CoachPlanReviewScreen extends StatefulWidget {
  const CoachPlanReviewScreen({
    super.key,
    required this.store,
    required this.proposal,
  });
  final AppStore store;
  final CoachProposal proposal;
  @override
  State<CoachPlanReviewScreen> createState() => _CoachPlanReviewScreenState();
}

class _CoachPlanReviewScreenState extends State<CoachPlanReviewScreen> {
  late CoachProposal _draft;
  bool _busy = false;
  String? _issue;
  @override
  void initState() {
    super.initState();
    _draft = widget.proposal;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() {
      _busy = true;
      _issue = null;
    });
    try {
      final proposal = _draft;
      await widget.store.applyCoachProposal(proposal);
      if (mounted && widget.store.accountId == proposal.accountId) {
        Navigator.pop(context, true);
        toast(
          context,
          proposal.schedule == null
              ? 'Your program is ready in Routines.'
              : 'Program and calendar dates saved.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _issue = _error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _schedule(bool enabled) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    setState(
      () => _draft = enabled
          ? _draft.copyWith(
              schedule: CoachScheduleDraft(
                routineIndex: 0,
                weeks: 4,
                weekdays: widget.store.profile.preferredDays.isEmpty
                    ? [1, 3, 5]
                    : widget.store.profile.preferredDays,
                startDate: tomorrow,
              ),
            )
          : _draft.copyWith(clearSchedule: true),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      if (widget.store.accountId != widget.proposal.accountId) {
        return Scaffold(
          appBar: AppBar(title: const Text('Program preview')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Your account changed. Open Coach to create a plan for this profile.',
              ),
            ),
          ),
        );
      }
      return _review(context);
    },
  );
  Widget _review(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your program preview')),
    body: PageBody(
      children: [
        PiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _draft.source == CoachProposalSource.online
                    ? 'AI PROGRAM'
                    : 'LOCAL PROGRAM BUILDER',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _draft.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(_draft.summary),
            ],
          ),
        ),
        const SectionHeading(title: 'The routines'),
        for (final routine in _draft.routines)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PiCard(
              padding: const EdgeInsets.all(5),
              child: ExpansionTile(
                initiallyExpanded: _draft.routines.length == 1,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(routine.name),
                subtitle: Text(
                  '${routine.targetRoutineId == null ? 'New routine' : 'Update saved routine'} · ${routine.estimatedMinutes} min · ${routine.exercises.length} exercises',
                ),
                children: [
                  for (final entry in routine.exercises)
                    ListTile(
                      dense: true,
                      title: Text(
                        widget.store.exerciseById(entry.exerciseId).name,
                      ),
                      subtitle: Text(
                        '${entry.sets} sets × ${entry.reps} reps${entry.weight > 0 ? ' · ${entry.weight} kg' : ' · choose your own load'}',
                      ),
                    ),
                ],
              ),
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Schedule a routine'),
          subtitle: const Text(
            'Add dates to your calendar as part of this plan.',
          ),
          value: _draft.schedule != null,
          onChanged: _busy ? null : _schedule,
        ),
        if (_draft.schedule case final schedule?)
          PiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: schedule.routineIndex,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Routine to schedule',
                  ),
                  items: [
                    for (var i = 0; i < _draft.routines.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          _draft.routines[i].name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(
                    () => _draft = _draft.copyWith(
                      schedule: schedule.copyWith(routineIndex: v),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(child: Text('Weeks')),
                    IconButton(
                      onPressed: schedule.weeks > 1
                          ? () => setState(
                              () => _draft = _draft.copyWith(
                                schedule: schedule.copyWith(
                                  weeks: schedule.weeks - 1,
                                ),
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('${schedule.weeks}'),
                    IconButton(
                      onPressed: schedule.weeks < 12
                          ? () => setState(
                              () => _draft = _draft.copyWith(
                                schedule: schedule.copyWith(
                                  weeks: schedule.weeks + 1,
                                ),
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      FilterChip(
                        label: Text(
                          const [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ][day - 1],
                        ),
                        selected: schedule.weekdays.contains(day),
                        onSelected: (selected) {
                          final days = [...schedule.weekdays];
                          selected ? days.add(day) : days.remove(day);
                          if (days.isNotEmpty) {
                            setState(
                              () => _draft = _draft.copyWith(
                                schedule: schedule.copyWith(weekdays: days),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _pickerDate(schedule.startDate),
                          firstDate: DateUtils.dateOnly(DateTime.now()),
                          lastDate: DateUtils.dateOnly(
                            DateTime.now(),
                          ).add(const Duration(days: 365)),
                        );
                        if (date != null && mounted) {
                          setState(
                            () => _draft = _draft.copyWith(
                              schedule: schedule.copyWith(startDate: date),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(formatDate(schedule.startDate)),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: schedule.hour,
                            minute: schedule.minute,
                          ),
                        );
                        if (time != null && mounted) {
                          setState(
                            () => _draft = _draft.copyWith(
                              schedule: schedule.copyWith(
                                hour: time.hour,
                                minute: time.minute,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        '${schedule.hour.toString().padLeft(2, '0')}:${schedule.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reminders'),
                  subtitle: const Text(
                    'Local reminders follow your phone permissions.',
                  ),
                  value: schedule.reminder,
                  onChanged: (enabled) => setState(
                    () => _draft = _draft.copyWith(
                      schedule: schedule.copyWith(reminder: enabled),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_issue != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _issue!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const Key('apply-coach-plan'),
          onPressed: _busy ? null : _apply,
          icon: const Icon(Icons.check_rounded),
          label: Text(_busy ? 'Saving…' : 'Apply program'),
        ),
        const SizedBox(height: 12),
        Text(
          'Applying saves the routines shown above. Existing routine updates are checked against the version you reviewed.',
          style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
        ),
      ],
    ),
  );
}

String _error(Object error) => error.toString().replaceFirst(
  RegExp(r'^(Bad state: |Invalid argument\(s\): |FormatException: )'),
  '',
);

DateTime _pickerDate(DateTime proposed) {
  final first = DateUtils.dateOnly(DateTime.now());
  final last = first.add(const Duration(days: 365));
  if (proposed.isBefore(first)) return first;
  return proposed.isAfter(last) ? last : proposed;
}
