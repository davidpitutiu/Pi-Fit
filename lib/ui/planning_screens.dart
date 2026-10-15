import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/training_analytics.dart';
import '../services/notification_service.dart';
import '../state/app_store.dart';
import 'theme.dart';
import 'health_screen.dart';
import 'export_screen.dart';
import 'training_screens.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
const _fullWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _number(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

String _volume(double value) =>
    value >= 100000 ? '${(value / 1000).toStringAsFixed(1)}k' : _number(value);

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selected = DateTime.now();
  late DateTime _month = DateTime(_selected.year, _selected.month);

  Future<void> _schedule() async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _ScheduleSheet(store: widget.store, initialDate: _selected),
    );
    if (mounted && message != null) {
      toast(context, message);
    }
  }

  Future<void> _start(Routine routine) async {
    try {
      await widget.store.startWorkout(routine);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/workout'),
          builder: (_) => ActiveWorkoutScreen(store: widget.store),
        ),
      );
    } catch (error) {
      if (mounted) {
        toast(context, 'Could not open the workout: $error');
      }
    }
  }

  Future<void> _remove(ScheduledWorkout event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this scheduled workout?'),
        content: Text(
          '${widget.store.routineById(event.routineId)?.name ?? 'Workout'}\n${formatDate(event.date)} · ${formatTime(event.date)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.store.removeScheduled(event.id);
      if (mounted) {
        toast(context, 'Scheduled workout deleted.');
      }
    } catch (error) {
      if (mounted) {
        toast(context, 'Could not delete the workout: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final events =
          widget.store.schedule
              .where((event) => _sameDay(event.date, _selected))
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      final completed = widget.store.history
          .where((session) => _sameDay(session.startedAt, _selected))
          .toList();
      final upcoming = widget.store.schedule
          .where((event) => event.date.isAfter(DateTime.now()))
          .length;
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Calendar',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            TextButton(
              onPressed: () => setState(() {
                _selected = DateTime.now();
                _month = DateTime(_selected.year, _selected.month);
              }),
              child: const Text('Today'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: PageBody(
          children: [
            Text(
              'Make room for progress.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              upcoming == 0
                  ? 'A good plan starts with your next workout.'
                  : '$upcoming ${upcoming == 1 ? 'scheduled workout' : 'scheduled workouts'}. Keep your own rhythm.',
              style: TextStyle(color: PiColors.muted(context)),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _schedule,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Schedule workouts'),
              ),
            ),
            const SizedBox(height: 22),
            PiCard(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        onPressed: () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month - 1),
                        ),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          '${_months[_month.month - 1]} ${_month.year}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next month',
                        onPressed: () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month + 1),
                        ),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _weekdays
                        .map(
                          (label) => Expanded(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: PiColors.muted(context),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  _calendarGrid(context),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _LegendDot(color: PiColors.lime),
                      Text(
                        'Scheduled',
                        style: TextStyle(
                          fontSize: 11,
                          color: PiColors.muted(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _LegendDot(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 11,
                          color: PiColors.muted(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SectionHeading(
              title:
                  '${_fullWeekdays[_selected.weekday - 1]}, ${_selected.day} ${_months[_selected.month - 1].toLowerCase()}',
            ),
            if (events.isEmpty && completed.isEmpty)
              _PlanningEmpty(
                icon: Icons.event_available_rounded,
                title: 'An open day',
                subtitle: 'Plan a session or make time for recovery.',
                action: 'Add a session',
                onAction: _schedule,
              ),
            for (final event in events) ...[
              _eventCard(context, event),
              const SizedBox(height: 12),
            ],
            for (final session in completed) ...[
              _HistoryCard(store: widget.store, session: session),
              const SizedBox(height: 12),
            ],
          ],
        ),
      );
    },
  );

  Widget _calendarGrid(BuildContext context) {
    final first = DateTime(_month.year, _month.month);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final cells = ((leading + days) / 7).ceil() * 7;
    return Column(
      children: List.generate(
        cells ~/ 7,
        (week) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: List.generate(7, (weekday) {
              final day = week * 7 + weekday - leading + 1;
              if (day < 1 || day > days) {
                return const Expanded(child: SizedBox(height: 46));
              }
              final date = DateTime(_month.year, _month.month, day);
              final selected = _sameDay(date, _selected);
              final today = _sameDay(date, DateTime.now());
              final planned = widget.store.schedule.any(
                (event) => _sameDay(event.date, date),
              );
              final done = widget.store.history.any(
                (event) => _sameDay(event.startedAt, date),
              );
              return Expanded(
                child: Semantics(
                  label:
                      '${formatDate(date)}${planned ? ', scheduled workout' : ''}${done ? ', completed workout' : ''}',
                  selected: selected,
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _selected = date),
                    child: Container(
                      height: 46,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: selected ? PiColors.lime : null,
                        borderRadius: BorderRadius.circular(14),
                        border: today && !selected
                            ? Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.5),
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontWeight: selected || today
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: selected ? const Color(0xFF142000) : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 4,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (planned)
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0xFF142000)
                                          : PiColors.lime,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (planned && done) const SizedBox(width: 3),
                                if (done)
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0xFF142000)
                                          : PiColors.muted(context),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _eventCard(BuildContext context, ScheduledWorkout event) {
    final routine = widget.store.routineById(event.routineId);
    final past = event.date.isBefore(DateTime.now());
    return PiCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: PiColors.lime.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  formatTime(event.date),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine?.name ?? 'Routine unavailable',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      routine == null
                          ? 'The original routine is no longer available.'
                          : '${routine.exercises.length} exercises · ~${routine.estimatedMinutes} min',
                      style: TextStyle(
                        color: PiColors.muted(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete scheduled workout',
                onPressed: () => _remove(event),
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                event.reminder
                    ? Icons.notifications_none_rounded
                    : Icons.event_outlined,
                size: 15,
                color: PiColors.muted(context),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  event.reminder
                      ? 'Reminder requested · check permissions'
                      : (past ? 'Scheduled session' : 'In your calendar'),
                  style: TextStyle(
                    fontSize: 11,
                    color: PiColors.muted(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: routine == null ? null : () => _start(routine),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(
                  widget.store.activeSession == null ? 'Start' : 'Continue',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    margin: const EdgeInsets.only(right: 5),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.store, required this.initialDate});
  final AppStore store;
  final DateTime initialDate;
  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late String? _routineId = widget.store.routines.isEmpty
      ? null
      : widget.store.routines.first.id;
  late DateTime _start = _initialDate();
  late TimeOfDay _time = TimeOfDay.fromDateTime(
    DateTime.now().add(const Duration(hours: 1)),
  );
  late final Set<int> _days = {_start.weekday};
  int _weeks = 4;
  bool _bulk = false;
  bool _reminder = false;
  bool _saving = false;
  String? _error;

  DateTime _initialDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = widget.initialDate.isBefore(today)
        ? today
        : DateTime(
            widget.initialDate.year,
            widget.initialDate.month,
            widget.initialDate.day,
          );
    // Keep the initial suggestion in the future when the next hour is tomorrow.
    return _sameDay(selected, today) && now.hour == 23
        ? DateTime(today.year, today.month, today.day + 1)
        : selected;
  }

  List<DateTime> get _preview {
    if (_routineId == null) {
      return [];
    }
    final dates = <DateTime>[];
    for (var offset = 0; offset < (_bulk ? _weeks * 7 : 1); offset++) {
      final date = DateTime(
        _start.year,
        _start.month,
        _start.day + offset,
        _time.hour,
        _time.minute,
      );
      if ((_bulk && !_days.contains(date.weekday)) ||
          !date.isAfter(DateTime.now())) {
        continue;
      }
      if (widget.store.schedule.any(
        (event) => event.routineId == _routineId && event.date == date,
      )) {
        continue;
      }
      dates.add(date);
    }
    return dates;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final chosen = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(math.max(now.year, _start.year) + 3, 12, 31),
      helpText: 'First day of your plan',
    );
    if (chosen != null && mounted) {
      setState(() => _start = chosen);
    }
  }

  Future<void> _pickTime() async {
    final chosen = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Workout time',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (chosen != null && mounted) {
      setState(() => _time = chosen);
    }
  }

  Future<void> _save() async {
    if (_saving || _routineId == null || _preview.isEmpty) {
      return;
    }
    final before = widget.store.schedule.map((event) => event.id).toSet();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final added = await widget.store.scheduleBulk(
        routineId: _routineId!,
        start: _start,
        weeks: _bulk ? _weeks : 1,
        weekdays: _bulk ? _days : {_start.weekday},
        time: _time,
        reminder: _reminder,
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(
        context,
        '$added ${added == 1 ? 'saved workout' : 'saved workouts'} in your calendar.${_reminder && added > 0 ? ' Reminders scheduled on this device.' : ''}',
      );
    } catch (error) {
      final added = widget.store.schedule
          .where((event) => !before.contains(event.id))
          .length;
      final storageFailure =
          (error.toString().contains('Salvarea locală') ||
          error.toString().contains('Local save'));
      if (!mounted) {
        return;
      }
      if (added > 0 && !storageFailure) {
        Navigator.pop(
          context,
          '$added ${added == 1 ? 'saved workout' : 'saved workouts'} in your calendar. Some reminders could not be scheduled: ${_errorText(error)}',
        );
      } else {
        setState(() {
          _saving = false;
          _error = _errorText(error);
        });
      }
    }
  }

  String _errorText(Object error) => error.toString().replaceFirst(
    RegExp(r'^(Bad state: |Unsupported operation: |Invalid argument\(s\): )'),
    '',
  );

  @override
  Widget build(BuildContext context) {
    final dates = _preview;
    final supported = NotificationService.instance.supported;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22,
          2,
          22,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your plan. Your pace.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'One session or a routine for the weeks ahead.',
              style: TextStyle(color: PiColors.muted(context)),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('One session')),
                  ButtonSegment(value: true, label: Text('Repeat')),
                ],
                selected: {_bulk},
                onSelectionChanged: _saving
                    ? null
                    : (value) => setState(() => _bulk = value.first),
              ),
            ),
            const SizedBox(height: 22),
            if (widget.store.routines.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _routineId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Workout routine'),
                items: widget.store.routines
                    .map(
                      (routine) => DropdownMenuItem(
                        value: routine.id,
                        child: Text(
                          routine.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _routineId = value),
              )
            else
              const Text('First create a routine in the Train tab.'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickDate,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.calendar_today_rounded, size: 17),
                    label: Text(formatDate(_start)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickTime,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(
                      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),
            if (_bulk) ...[
              const SizedBox(height: 20),
              Text(
                'Your training days',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 5,
                children: List.generate(
                  7,
                  (index) => FilterChip(
                    label: Text(_weekdays[index]),
                    selected: _days.contains(index + 1),
                    showCheckmark: false,
                    onSelected: _saving
                        ? null
                        : (selected) => setState(() {
                            selected
                                ? _days.add(index + 1)
                                : _days.remove(index + 1);
                          }),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Plan length',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  DropdownButton<int>(
                    value: _weeks,
                    underline: const SizedBox.shrink(),
                    items: List.generate(
                      12,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text(
                          '${index + 1} ${index == 0 ? 'week' : 'weeks'}',
                        ),
                      ),
                    ),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _weeks = value!),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _reminder,
              title: const Text(
                'Remind me at workout time',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                supported
                    ? 'Permission is requested when you save this plan.'
                    : 'Available in the installed Android and iOS app.',
                style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
              ),
              onChanged: !supported || _saving
                  ? null
                  : (value) => setState(() => _reminder = value),
            ),
            const SizedBox(height: 12),
            PiCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 21,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${dates.length} ${dates.length == 1 ? 'new session' : 'new sessions'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          dates.isEmpty
                              ? 'Choose a future date and at least one day. Duplicate sessions are skipped.'
                              : '${formatDate(dates.first)}${dates.length > 1 ? ' — ${formatDate(dates.last)}' : ''}\nDuplicate sessions and past times are skipped.',
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
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: dates.isEmpty || _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _saving
                      ? 'Saving…'
                      : 'Add ${dates.length} ${dates.length == 1 ? 'session' : 'sessions'}',
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _days = 28;
  _TrendMetric _metric = _TrendMetric.volume;
  String? _exerciseId;
  bool _showEstimatedMax = false;
  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final analytics = store.analytics;
      final allTimeCount = completedTrainingSessions(
        store.history,
        now: analytics.asOf,
      ).length;
      final series = buildTrainingSeries(
        history: store.history,
        exercises: store.exercises,
        days: _days,
        now: analytics.asOf,
      );
      final records = analytics.records;
      final selectedId =
          records.any((record) => record.exerciseId == _exerciseId)
          ? _exerciseId
          : (records.isEmpty ? null : records.first.exerciseId);
      final exercise = selectedId == null
          ? null
          : store.exerciseById(selectedId);
      final progression = exercise == null
          ? <ExerciseProgressPoint>[]
          : buildExerciseProgression(
              history: store.history,
              exercise: exercise,
              days: _days,
              now: analytics.asOf,
            );
      final history = [
        ...completedTrainingSessions(store.history, now: analytics.asOf),
      ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Progress',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'Export progress',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExportScreen(store: store),
                ),
              ),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ],
        ),
        body: PageBody(
          children: [
            Text(
              'YOUR PROGRESS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: PiColors.muted(context),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Better, at your own pace.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'Real numbers. Personal goals. Every step, visible.',
              style: TextStyle(color: PiColors.muted(context)),
            ),
            const SizedBox(height: 24),
            PiCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(
                    Icons.fitness_center_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$allTimeCount completed ${allTimeCount == 1 ? 'workout' : 'workouts'}',
                          key: const ValueKey('all-time-workout-count'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'All time · every completed session counts once',
                          style: TextStyle(
                            fontSize: 11,
                            color: PiColors.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _ConsistencyCard(analytics: analytics),
            const SizedBox(height: 14),
            _StreakCard(
              streak: analytics.streak,
              activeDates: series.activeDates,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final days in [7, 28, 90])
                  ChoiceChip(
                    key: ValueKey('period-$days'),
                    label: Text('$days days'),
                    selected: _days == days,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _days = days),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your last $_days days',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'How your statistics work',
                  onPressed: () => _showExplanation(
                    context,
                    'About your statistics',
                    [
                      'The selected period includes the last $_days calendar days, including today. Only completed sessions with valid checked sets are included.',
                      analytics.volumeExplanation,
                      'Minutes are the logged time between starting and finishing a session, including rests.',
                    ],
                  ),
                  icon: Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: PiColors.muted(context),
                  ),
                ),
              ],
            ),
            Text(
              '${formatDate(series.start)} — ${formatDate(series.asOf)}',
              style: TextStyle(color: PiColors.muted(context), fontSize: 12),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      width: width,
                      value: '${series.workoutCount}',
                      label: 'saved workouts',
                      icon: Icons.fitness_center_rounded,
                    ),
                    _StatCard(
                      width: width,
                      value: '${series.completedSets}',
                      label: 'completed sets',
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    _StatCard(
                      width: width,
                      value: _volume(series.volume),
                      label: 'kg · external volume',
                      icon: Icons.monitor_weight_outlined,
                    ),
                    _StatCard(
                      width: width,
                      value: '${series.activeDays}',
                      label: 'active days',
                      icon: Icons.calendar_today_rounded,
                    ),
                  ],
                );
              },
            ),
            const SectionHeading(title: 'Training over time'),
            _TrainingTrendCard(
              series: series,
              metric: _metric,
              onMetric: (metric) => setState(() => _metric = metric),
            ),
            const SectionHeading(title: 'Stronger, session by session'),
            if (records.isEmpty)
              const _PlanningEmpty(
                icon: Icons.show_chart_rounded,
                title: 'Your first progress point is ahead',
                subtitle:
                    'Save weighted strength sets to track the weight and estimated 1RM for each exercise.',
              )
            else
              PiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      key: const ValueKey('progress-exercise'),
                      initialValue: selectedId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Exercise'),
                      items: [
                        for (final record in records)
                          DropdownMenuItem(
                            value: record.exerciseId,
                            child: Text(
                              record.exerciseName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => _exerciseId = value),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Weight'),
                          selected: !_showEstimatedMax,
                          showCheckmark: false,
                          onSelected: (_) =>
                              setState(() => _showEstimatedMax = false),
                        ),
                        ChoiceChip(
                          label: const Text('Estimated 1RM'),
                          selected: _showEstimatedMax,
                          showCheckmark: false,
                          onSelected: (_) =>
                              setState(() => _showEstimatedMax = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _ExerciseProgressChart(
                      points: progression,
                      estimated: _showEstimatedMax,
                      start: series.start,
                      asOf: series.asOf,
                    ),
                  ],
                ),
              ),
            const SectionHeading(title: 'Beyond the gym'),
            PiCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HealthScreen(store: store),
                ),
              ),
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Health & movement',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Steps, energy and movement minutes',
                          style: TextStyle(
                            fontSize: 12,
                            color: PiColors.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SectionHeading(title: 'Where you put in the work'),
            if (series.muscles.isEmpty)
              _PlanningEmpty(
                icon: Icons.accessibility_new_rounded,
                title: 'Your muscle map is taking shape',
                subtitle:
                    'Checked sets from the last $_days days appear here, grouped by the primary muscle.',
              )
            else
              _MuscleDistribution(muscles: series.muscles, days: _days),
            SectionHeading(
              title: 'Personal records',
              action: 'About 1RM',
              onAction: () => _showExplanation(
                context,
                'Records and estimates',
                [analytics.recordsExplanation],
              ),
            ),
            if (analytics.records.isEmpty)
              const _PlanningEmpty(
                icon: Icons.emoji_events_outlined,
                title: 'Your first record is ahead',
                subtitle:
                    'Save a weighted strength set to see your best set and, where eligible, an estimated 1RM.',
              )
            else ...[
              Text(
                'All time · weighted strength sets',
                style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
              ),
              const SizedBox(height: 12),
              PiCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < analytics.records.length;
                      index++
                    ) ...[
                      if (index > 0) const Divider(height: 1),
                      _RecordRow(record: analytics.records[index]),
                    ],
                  ],
                ),
              ),
            ],
            SectionHeading(
              title: 'Your training log',
              action: history.isEmpty ? null : '${history.length} sessions',
              onAction: history.isEmpty
                  ? null
                  : () => _openHistory(context, store, history),
            ),
            if (history.isEmpty)
              _PlanningEmpty(
                icon: Icons.history_rounded,
                title: 'Log your first workout',
                subtitle:
                    'Choose a routine, check off the sets you complete, then save. Your workouts build your statistics.',
                action: 'Choose a workout',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RoutinesScreen(store: store),
                  ),
                ),
              ),
            for (final session in history.take(6)) ...[
              _HistoryCard(store: store, session: session),
              const SizedBox(height: 12),
            ],
            if (history.length > 6)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _openHistory(context, store, history),
                  child: Text('View all ${history.length} sessions'),
                ),
              ),
          ],
        ),
      );
    },
  );
}

void _openHistory(
  BuildContext context,
  AppStore store,
  List<WorkoutSession> history,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (context) => Scaffold(
      appBar: AppBar(title: const Text('Workout history')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
        itemCount: history.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) =>
            _HistoryCard(store: store, session: history[index]),
      ),
    ),
  ),
);

Future<void> _showExplanation(
  BuildContext context,
  String title,
  List<String> paragraphs,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final paragraph in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(paragraph),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Got it'),
      ),
    ],
  ),
);

enum _TrendMetric {
  volume('Volume', 'kg'),
  sets('Sets', 'sets'),
  sessions('Sessions', 'sessions'),
  minutes('Minutes', 'min');

  const _TrendMetric(this.label, this.unit);
  final String label;
  final String unit;

  double daily(DailyTrainingActivity point) => switch (this) {
    volume => point.volume,
    sets => point.completedSets.toDouble(),
    sessions => point.workoutCount.toDouble(),
    minutes => point.durationMinutes,
  };

  double total(TrainingSeries series) => switch (this) {
    volume => series.volume,
    sets => series.completedSets.toDouble(),
    sessions => series.workoutCount.toDouble(),
    minutes => series.durationMinutes,
  };
}

class _TrendBin {
  const _TrendBin(this.start, this.end, this.value);
  final DateTime start;
  final DateTime end;
  final double value;

  String get dateLabel => _sameDay(start, end)
      ? formatDate(start)
      : '${formatDate(start)} — ${formatDate(end)}';
}

class _TrainingTrendCard extends StatefulWidget {
  const _TrainingTrendCard({
    required this.series,
    required this.metric,
    required this.onMetric,
  });
  final TrainingSeries series;
  final _TrendMetric metric;
  final ValueChanged<_TrendMetric> onMetric;

  @override
  State<_TrainingTrendCard> createState() => _TrainingTrendCardState();
}

class _TrainingTrendCardState extends State<_TrainingTrendCard> {
  int? _selected;

  @override
  void didUpdateWidget(covariant _TrainingTrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series.days != widget.series.days ||
        oldWidget.metric != widget.metric) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.series.points;
    final binSize = widget.series.days == 7 ? 1 : 7;
    final bins = <_TrendBin>[];
    for (var index = 0; index < points.length; index += binSize) {
      final values = points.skip(index).take(binSize).toList();
      bins.add(
        _TrendBin(
          values.first.date,
          values.last.date,
          values.fold(0, (total, day) => total + widget.metric.daily(day)),
        ),
      );
    }
    final maxValue = math.max(
      1.0,
      bins.fold<double>(0, (value, bin) => math.max(value, bin.value)),
    );
    var selected = _selected ?? bins.lastIndexWhere((bin) => bin.value > 0);
    if (selected < 0 || selected >= bins.length) selected = bins.length - 1;
    final unit = widget.metric.unit;
    return PiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final metric in _TrendMetric.values)
                ChoiceChip(
                  key: ValueKey('metric-${metric.name}'),
                  label: Text(metric.label),
                  selected: widget.metric == metric,
                  showCheckmark: false,
                  onSelected: (_) => widget.onMetric(metric),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _number(widget.metric.total(widget.series)),
                    key: const ValueKey('trend-total'),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(color: PiColors.muted(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'over the last ${widget.series.days} days',
            style: TextStyle(color: PiColors.muted(context), fontSize: 12),
          ),
          if (widget.series.workoutCount == 0) ...[
            const SizedBox(height: 28),
            const _ChartEmpty(
              message:
                  'No completed sessions in this period. Your next workout will become the first point on your chart.',
            ),
          ] else ...[
            const SizedBox(height: 24),
            Text(
              '${bins[selected].dateLabel} · ${_number(bins[selected].value)} $unit',
              key: const ValueKey('trend-selected'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 142,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var index = 0; index < bins.length; index++)
                    Expanded(
                      child: Semantics(
                        label:
                            '${bins[index].dateLabel}: ${_number(bins[index].value)} $unit',
                        button: true,
                        selected: selected == index,
                        child: Tooltip(
                          message:
                              '${bins[index].dateLabel}: ${_number(bins[index].value)} $unit',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _selected = index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: math.max(
                                    3,
                                    136 * bins[index].value / maxValue,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(9),
                                    color: bins[index].value == 0
                                        ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: .08)
                                        : null,
                                    gradient: bins[index].value == 0
                                        ? null
                                        : LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              PiColors.lime.withValues(
                                                alpha: selected == index
                                                    ? 1
                                                    : .65,
                                              ),
                                              PiColors.lime.withValues(
                                                alpha: selected == index
                                                    ? .38
                                                    : .15,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${points.first.date.day}/${points.first.date.month}',
                  style: TextStyle(
                    fontSize: 11,
                    color: PiColors.muted(context),
                  ),
                ),
                const Spacer(),
                Text(
                  '${points.last.date.day}/${points.last.date.month}',
                  style: TextStyle(
                    fontSize: 11,
                    color: PiColors.muted(context),
                  ),
                ),
              ],
            ),
            if (bins.length > 1)
              Slider(
                key: const ValueKey('trend-slider'),
                value: selected.toDouble(),
                min: 0,
                max: (bins.length - 1).toDouble(),
                divisions: bins.length - 1,
                semanticFormatterCallback: (value) {
                  final bin = bins[value.round()];
                  return '${bin.dateLabel}: ${_number(bin.value)} $unit';
                },
                onChanged: (value) => setState(() => _selected = value.round()),
              ),
            Text(
              binSize == 1
                  ? 'Each bar represents one day.'
                  : 'Each bar covers 7 days; the last interval may be shorter.',
              style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  builder: (context) => SizedBox(
                    height: MediaQuery.sizeOf(context).height * .7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                          child: Text(
                            '${widget.metric.label} · chart values',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: bins.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) => ListTile(
                              title: Text(bins[index].dateLabel),
                              subtitle: Text(
                                '${_number(bins[index].value)} $unit',
                              ),
                              onTap: () {
                                setState(() => _selected = index);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                icon: const Icon(Icons.table_rows_outlined, size: 17),
                label: const Text('View values'),
              ),
            ),
          ],
          if (widget.metric == _TrendMetric.minutes)
            Text(
              'Logged session duration, including rests.',
              style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
            ),
        ],
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        Icon(
          Icons.show_chart_rounded,
          size: 36,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: PiColors.muted(context),
          ),
        ),
      ],
    ),
  );
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.activeDates});
  final TrainingStreak streak;
  final List<DateTime> activeDates;

  @override
  Widget build(BuildContext context) => PiCard(
    onTap: () => _showExplanation(context, 'How your streak works', [
      streak.explanation,
      'Current goal: ${streak.targetDaysPerWeek} active days per week. Change it in Account → Profile.',
    ]),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Show up. Build. Repeat.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: PiColors.muted(context),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StreakMetric(
                value: streak.currentWeeks,
                label: 'weeks in a row',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StreakMetric(
                value: streak.bestWeeks,
                label: 'best streak',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'This week · ${streak.activeDaysThisWeek} / ${streak.targetDaysPerWeek} days',
          style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var index = 0; index < 7; index++)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final day = DateTime(
                      streak.currentWeekStart.year,
                      streak.currentWeekStart.month,
                      streak.currentWeekStart.day + index,
                    );
                    final active = activeDates.any(
                      (date) => _sameDay(date, day),
                    );
                    return Semantics(
                      label:
                          '${_fullWeekdays[index]}, ${formatDate(day)}: ${active ? 'logged workout' : 'no logged workout'}',
                      child: Column(
                        children: [
                          Container(
                            width: 25,
                            height: 25,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? PiColors.lime
                                  : Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: .06),
                            ),
                            child: active
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Color(0xFF182000),
                                    size: 17,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _weekdays[index],
                            style: TextStyle(
                              fontSize: 10,
                              color: PiColors.muted(context),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: math.min(
              1,
              streak.activeDaysThisWeek / streak.targetDaysPerWeek,
            ),
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .07),
          ),
        ),
      ],
    ),
  );
}

class _StreakMetric extends StatelessWidget {
  const _StreakMetric({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$value', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 5),
      Text(
        label,
        style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
      ),
    ],
  );
}

class _ChartPoint {
  const _ChartPoint(this.date, this.value, this.description);
  final DateTime date;
  final double value;
  final String description;
}

class _ExerciseProgressChart extends StatefulWidget {
  const _ExerciseProgressChart({
    required this.points,
    required this.estimated,
    required this.start,
    required this.asOf,
  });
  final List<ExerciseProgressPoint> points;
  final bool estimated;
  final DateTime start;
  final DateTime asOf;

  @override
  State<_ExerciseProgressChart> createState() => _ExerciseProgressChartState();
}

class _ExerciseProgressChartState extends State<_ExerciseProgressChart> {
  int? _selected;

  @override
  void didUpdateWidget(covariant _ExerciseProgressChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.estimated != widget.estimated ||
        oldWidget.points != widget.points) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = <_ChartPoint>[
      for (final point in widget.points)
        if (!widget.estimated || point.estimatedOneRepMax != null)
          _ChartPoint(
            point.date,
            widget.estimated ? point.estimatedOneRepMax! : point.topWeight,
            widget.estimated
                ? 'Estimated 1RM'
                : '${_number(point.topWeight)} kg × ${point.topWeightReps}',
          ),
    ];
    if (points.isEmpty) {
      return _ChartEmpty(
        message: widget.estimated
            ? 'No eligible sets with 1–12 reps in this period. Choose Weight or a longer period.'
            : 'No sets for this exercise in the selected period. Choose another exercise or a longer period.',
      );
    }
    final selected = (_selected ?? points.length - 1).clamp(
      0,
      points.length - 1,
    );
    final point = points[selected];
    final delta = points.last.value - points.first.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 9,
          children: [
            Text(
              '${_number(point.value)} kg',
              key: const ValueKey('exercise-chart-value'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              widget.estimated ? 'Estimated 1RM' : 'external weight',
              style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${formatDate(point.date)} · ${point.description}',
          key: const ValueKey('exercise-chart-selected'),
          style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
        ),
        const SizedBox(height: 22),
        Semantics(
          label:
              'Chart with ${points.length} logged days. ${points.map((point) => '${formatDate(point.date)}: ${_number(point.value)} kg').join('; ')}',
          child: SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(
              painter: _ProgressLinePainter(
                points: points,
                start: widget.start,
                asOf: widget.asOf,
                selected: selected,
                color: Theme.of(context).colorScheme.primary,
                grid: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .07),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              '${widget.start.day}/${widget.start.month}',
              style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
            ),
            const Spacer(),
            Text(
              '${widget.asOf.day}/${widget.asOf.month}',
              style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
            ),
          ],
        ),
        if (points.length > 1) ...[
          Slider(
            key: const ValueKey('exercise-progress-slider'),
            min: 0,
            max: (points.length - 1).toDouble(),
            divisions: points.length - 1,
            value: selected.toDouble(),
            semanticFormatterCallback: (value) =>
                '${formatDate(points[value.round()].date)}: ${_number(points[value.round()].value)} kg',
            onChanged: (value) => setState(() => _selected = value.round()),
          ),
          Text(
            '${delta > 0 ? '+' : ''}${_number(delta)} kg between the first and last logged day in this period.',
            style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
          ),
        ] else ...[
          const SizedBox(height: 14),
          Text(
            'One logged day. Another session will show a trend.',
            style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          widget.estimated
              ? 'Epley, using sets of 1–12 reps only. The estimate is not a recommended weight.'
              : 'The heaviest checked set each day. Reps may differ.',
          style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
        ),
        const SizedBox(height: 6),
        Text(
          'Points represent logged days; missing days are left without invented values.',
          style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
        ),
      ],
    );
  }
}

class _ProgressLinePainter extends CustomPainter {
  const _ProgressLinePainter({
    required this.points,
    required this.start,
    required this.asOf,
    required this.selected,
    required this.color,
    required this.grid,
  });
  final List<_ChartPoint> points;
  final DateTime start;
  final DateTime asOf;
  final int selected;
  final Color color;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 8.0;
    final plot = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var index = 0; index <= 3; index++) {
      final y = plot.top + plot.height * index / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }
    final highest = points.fold<double>(
      1,
      (value, point) => math.max(value, point.value),
    );
    final span = math.max(
      1,
      DateTime.utc(
        asOf.year,
        asOf.month,
        asOf.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays,
    );
    final positions = points
        .map(
          (point) => Offset(
            plot.left +
                plot.width *
                    DateTime.utc(
                          point.date.year,
                          point.date.month,
                          point.date.day,
                        )
                        .difference(
                          DateTime.utc(start.year, start.month, start.day),
                        )
                        .inDays /
                    span,
            plot.bottom - plot.height * point.value / (highest * 1.12),
          ),
        )
        .toList();
    final line = Path()..moveTo(positions.first.dx, positions.first.dy);
    for (final position in positions.skip(1)) {
      line.lineTo(position.dx, position.dy);
    }
    if (positions.length > 1) {
      final area = Path.from(line)
        ..lineTo(positions.last.dx, plot.bottom)
        ..lineTo(positions.first.dx, plot.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: .2), color.withValues(alpha: 0)],
          ).createShader(plot),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (var index = 0; index < positions.length; index++) {
      if (index == selected) {
        canvas.drawCircle(
          positions[index],
          9,
          Paint()..color = color.withValues(alpha: .15),
        );
      }
      canvas.drawCircle(
        positions[index],
        index == selected ? 4.5 : 3,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressLinePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.selected != selected ||
      oldDelegate.color != color ||
      oldDelegate.grid != grid ||
      oldDelegate.start != start ||
      oldDelegate.asOf != asOf;
}

class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard({required this.analytics});
  final TrainingAnalytics analytics;

  @override
  Widget build(BuildContext context) => PiCard(
    onTap: () => _showScoreDetails(context, analytics),
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Consistency score',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_outward_rounded,
              size: 19,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analytics.score == null
                      ? 'Your rhythm starts here.'
                      : '${analytics.activeDaysLast28} / ${analytics.targetDaysLast28} active days',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  analytics.score == null
                      ? 'Your score appears after the first saved workout with checked sets.'
                      : 'Your goal: ${analytics.targetSessionsPerWeek} training days per week.',
                  style: TextStyle(
                    color: PiColors.muted(context),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'See the calculation',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            );
            if (constraints.maxWidth < 300) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _ScoreRing(score: analytics.score)),
                  const SizedBox(height: 20),
                  details,
                ],
              );
            }
            return Row(
              children: [
                _ScoreRing(score: analytics.score),
                const SizedBox(width: 24),
                Expanded(child: details),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Divider(height: 1, color: Theme.of(context).dividerColor),
        const SizedBox(height: 14),
        Text(
          'Consistency against your goal, over the last 28 days.',
          style: TextStyle(color: PiColors.muted(context), fontSize: 11),
        ),
      ],
    ),
  );
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score});
  final double? score;

  @override
  Widget build(BuildContext context) => Semantics(
    label: score == null
        ? 'Score unavailable. Log your first workout.'
        : 'Consistency score ${score!.round()} out of 100.',
    child: SizedBox(
      width: 136,
      height: 136,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: CircularProgressIndicator(
              value: (score ?? 0) / 100,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .07),
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score == null ? '—' : '${score!.round()}',
                  style: TextStyle(
                    fontSize: 39,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                    height: 1.1,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  score == null ? 'no data' : 'out of 100',
                  style: TextStyle(
                    color: PiColors.muted(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showScoreDetails(
  BuildContext context,
  TrainingAnalytics analytics,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('How your score is calculated'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(analytics.scoreExplanation),
          const SizedBox(height: 18),
          for (final component in analytics.components) ...[
            Text(
              component.label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              '${component.value} / ${component.target} · ${_number(component.points)} of ${_number(component.maxPoints)} points',
              key: ValueKey('score-component-${component.maxPoints.toInt()}'),
            ),
            const SizedBox(height: 5),
            Text(
              component.explanation,
              style: TextStyle(color: PiColors.muted(context), fontSize: 12),
            ),
            const SizedBox(height: 18),
          ],
          const Divider(),
          Text(analytics.formula, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 14),
          Text(
            analytics.windowExplanation,
            style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
          ),
          if (analytics.score == null) ...[
            const SizedBox(height: 14),
            const Text(
              'No data for a score yet. Save your first workout with at least one checked set.',
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Got it'),
      ),
    ],
  ),
);

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.value,
    required this.label,
    required this.icon,
  });
  final double width;
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: PiCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
          ),
        ],
      ),
    ),
  );
}

class _MuscleDistribution extends StatelessWidget {
  const _MuscleDistribution({
    required this.muscles,
    this.expanded = false,
    this.days = 28,
  });
  final List<MuscleVolume> muscles;
  final bool expanded;
  final int days;

  @override
  Widget build(BuildContext context) {
    final total = muscles.fold<int>(
      0,
      (value, muscle) => value + muscle.completedSets,
    );
    final visible = expanded ? muscles : muscles.take(6);
    return PiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sets by primary muscle',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Last $days days · secondary muscles are not counted twice',
            style: TextStyle(color: PiColors.muted(context), fontSize: 11),
          ),
          const SizedBox(height: 20),
          for (final muscle in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          muscle.muscle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${muscle.completedSets} ${muscle.completedSets == 1 ? 'set' : 'sets'}',
                        style: TextStyle(
                          color: PiColors.muted(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : muscle.completedSets / total,
                      minHeight: 6,
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .06),
                    ),
                  ),
                ],
              ),
            ),
          if (!expanded && muscles.length > 6)
            TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                  child: _MuscleDistribution(
                    muscles: muscles,
                    expanded: true,
                    days: days,
                  ),
                ),
              ),
              child: Text('View all ${muscles.length} groups'),
            ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record});
  final ExerciseRecord record;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                record.exerciseName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              '${_number(record.weight)} kg × ${record.reps}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            if (record.estimatedOneRepMax != null)
              Text(
                'Estimated 1RM · ${_number(record.estimatedOneRepMax!)} kg',
                style: TextStyle(color: PiColors.muted(context), fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          formatDate(record.date),
          style: TextStyle(color: PiColors.muted(context), fontSize: 11),
        ),
      ],
    ),
  );
}

String _exerciseName(AppStore store, String id) {
  for (final exercise in store.exercises) {
    if (exercise.id == id) {
      return exercise.name;
    }
  }
  return 'Saved exercise';
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.store, required this.session});
  final AppStore store;
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final metrics = _sessionAnalytics(store, session);
    return PiCard(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => _SessionDetails(store: store, session: session),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatDate(session.startedAt)} · ${formatTime(session.startedAt)}',
                  style: TextStyle(
                    color: PiColors.muted(context),
                    fontSize: 11,
                  ),
                ),
              ),
              Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            session.routineName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _InlineMetric(
                      icon: Icons.schedule_rounded,
                      label: '${session.duration.inMinutes} min',
                    ),
                    _InlineMetric(
                      icon: Icons.check_rounded,
                      label:
                          '${metrics.completedSetsLast28} / ${session.totalSets} sets',
                    ),
                    _InlineMetric(
                      icon: Icons.fitness_center_rounded,
                      label: '${_volume(metrics.volumeLast28)} kg external',
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 21),
            ],
          ),
        ],
      ),
    );
  }
}

TrainingAnalytics _sessionAnalytics(AppStore store, WorkoutSession session) =>
    analyzeTraining(
      history: [session],
      exercises: store.exercises,
      profile: store.profile,
      now: session.finishedAt,
    );

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: PiColors.muted(context)),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
        ),
      ),
    ],
  );
}

class _SessionDetails extends StatelessWidget {
  const _SessionDetails({required this.store, required this.session});
  final AppStore store;
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final metrics = _sessionAnalytics(store, session);
    final estimates = {
      for (final record in metrics.records)
        record.exerciseId: record.estimatedOneRepMax,
    };
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session.routineName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${formatDate(session.startedAt)} · ${formatTime(session.startedAt)}',
              style: TextStyle(color: PiColors.muted(context)),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                _InlineMetric(
                  icon: Icons.schedule_rounded,
                  label:
                      '${session.duration.inMinutes} min ${session.duration.inSeconds % 60} sec',
                ),
                _InlineMetric(
                  icon: Icons.check_circle_outline_rounded,
                  label:
                      '${metrics.completedSetsLast28} / ${session.totalSets} sets',
                ),
                _InlineMetric(
                  icon: Icons.fitness_center_rounded,
                  label:
                      '${_volume(metrics.volumeLast28)} kg externalal volume',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Statistics use checked sets with valid values. Unchecked sets show what was planned.',
              style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
            ),
            const SizedBox(height: 20),
            for (final exercise in session.exercises) ...[
              PiCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _exerciseName(store, exercise.exerciseId),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 42,
                          child: Text(
                            'SET',
                            style: TextStyle(
                              fontSize: 10,
                              color: PiColors.muted(context),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'WEIGHT × REPS',
                            style: TextStyle(
                              fontSize: 10,
                              color: PiColors.muted(context),
                            ),
                          ),
                        ),
                        Text(
                          'STATUS',
                          style: TextStyle(
                            fontSize: 10,
                            color: PiColors.muted(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (var index = 0; index < exercise.sets.length; index++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 42,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: PiColors.muted(context),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${exercise.sets[index].weight == 0 ? 'Bodyweight' : '${_number(exercise.sets[index].weight)} kg'} × ${exercise.sets[index].reps}',
                                style: TextStyle(
                                  fontWeight: exercise.sets[index].completed
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: exercise.sets[index].completed
                                      ? null
                                      : PiColors.muted(context),
                                ),
                              ),
                            ),
                            Tooltip(
                              message: exercise.sets[index].completed
                                  ? 'Completed set'
                                  : 'Planned set, not completed',
                              child: Icon(
                                exercise.sets[index].completed
                                    ? Icons.check_circle_rounded
                                    : Icons.remove_circle_outline_rounded,
                                semanticLabel: exercise.sets[index].completed
                                    ? 'Completed'
                                    : 'Planned, not completed',
                                color: exercise.sets[index].completed
                                    ? Theme.of(context).colorScheme.primary
                                    : PiColors.muted(context),
                                size: 19,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (estimates[exercise.exerciseId] != null) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Estimated 1RM · ${_number(estimates[exercise.exerciseId]!)} kg',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Epley · from the best eligible checked set (1–12 reps).',
                        style: TextStyle(
                          fontSize: 11,
                          color: PiColors.muted(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (session.notes.trim().isNotEmpty) ...[
              const SectionHeading(title: 'Your notes'),
              PiCard(
                child: SizedBox(
                  width: double.infinity,
                  child: Text(session.notes),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanningEmpty extends StatelessWidget {
  const _PlanningEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => PiCard(
    child: SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PiColors.lime.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: PiColors.muted(context), fontSize: 13),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(action!)),
          ],
          const SizedBox(height: 6),
        ],
      ),
    ),
  );
}
