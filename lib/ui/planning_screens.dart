import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../services/notification_service.dart';
import '../state/app_store.dart';
import 'theme.dart';
import 'training_screens.dart';

const _months = [
  'Ianuarie',
  'Februarie',
  'Martie',
  'Aprilie',
  'Mai',
  'Iunie',
  'Iulie',
  'August',
  'Septembrie',
  'Octombrie',
  'Noiembrie',
  'Decembrie',
];
const _weekdays = ['Lu', 'Ma', 'Mi', 'Jo', 'Vi', 'Sâ', 'Du'];
const _fullWeekdays = [
  'Luni',
  'Marți',
  'Miercuri',
  'Joi',
  'Vineri',
  'Sâmbătă',
  'Duminică',
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
          builder: (_) => ActiveWorkoutScreen(store: widget.store),
        ),
      );
    } catch (error) {
      if (mounted) {
        toast(context, 'Antrenamentul nu a putut fi deschis: $error');
      }
    }
  }

  Future<void> _remove(ScheduledWorkout event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ștergi programarea?'),
        content: Text(
          '${widget.store.routineById(event.routineId)?.name ?? 'Antrenament'}\n${formatDate(event.date)} · ${formatTime(event.date)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Păstrează'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Șterge'),
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
        toast(context, 'Programarea a fost ștearsă.');
      }
    } catch (error) {
      if (mounted) {
        toast(context, 'Nu am putut finaliza ștergerea: $error');
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
              child: const Text('Astăzi'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: PageBody(
          children: [
            Text(
              'Fă loc progresului.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              upcoming == 0
                  ? 'Un plan bun începe cu următorul antrenament.'
                  : '$upcoming ${upcoming == 1 ? 'antrenament programat' : 'antrenamente programate'}. Ține-te de ritmul tău.',
              style: TextStyle(color: PiColors.muted(context)),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _schedule,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Programează antrenamente'),
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
                        tooltip: 'Luna precedentă',
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
                        tooltip: 'Luna următoare',
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
                        'Programat',
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
                        'Finalizat',
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
                title: 'Zi liberă în calendar',
                subtitle:
                    'Planifică o sesiune sau păstrează timp pentru recuperare.',
                action: 'Adaugă o sesiune',
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
                      '${formatDate(date)}${planned ? ', antrenament programat' : ''}${done ? ', antrenament finalizat' : ''}',
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
                      routine?.name ?? 'Rutină indisponibilă',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      routine == null
                          ? 'Rutina originală nu mai există.'
                          : '${routine.exercises.length} exerciții · ~${routine.estimatedMinutes} min',
                      style: TextStyle(
                        color: PiColors.muted(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Șterge programarea',
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
                      ? 'Reminder solicitat · verifică permisiunile'
                      : (past ? 'Sesiune planificată' : 'În calendar'),
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
                  widget.store.activeSession == null ? 'Începe' : 'Continuă',
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
      helpText: 'Prima zi din plan',
    );
    if (chosen != null && mounted) {
      setState(() => _start = chosen);
    }
  }

  Future<void> _pickTime() async {
    final chosen = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Ora antrenamentelor',
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
        '$added ${added == 1 ? 'antrenament salvat' : 'antrenamente salvate'} în calendar.${_reminder && added > 0 ? ' Remindere programate pe acest dispozitiv.' : ''}',
      );
    } catch (error) {
      final added = widget.store.schedule
          .where((event) => !before.contains(event.id))
          .length;
      final storageFailure = error.toString().contains('Salvarea locală');
      if (!mounted) {
        return;
      }
      if (added > 0 && !storageFailure) {
        Navigator.pop(
          context,
          '$added ${added == 1 ? 'antrenament salvat' : 'antrenamente salvate'} în calendar. Reminderele nu au putut fi programate complet: ${_errorText(error)}',
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
              'Planul tău, ritmul tău.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'O sesiune sau o rutină pentru următoarele săptămâni.',
              style: TextStyle(color: PiColors.muted(context)),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('O sesiune')),
                  ButtonSegment(value: true, label: Text('În serie')),
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
                decoration: const InputDecoration(
                  labelText: 'Rutina de antrenament',
                ),
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
              const Text('Creează întâi o rutină din fila Antrenament.'),
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
                'Zilele în care te antrenezi',
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
                      'Durata planului',
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
                          '${index + 1} ${index == 0 ? 'săptămână' : 'săptămâni'}',
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
                'Reminder la ora antrenamentului',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                supported
                    ? 'Permisiunea se solicită când salvezi planul.'
                    : 'Disponibil în aplicația instalată pe Android și iOS.',
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
                          '${dates.length} ${dates.length == 1 ? 'sesiune nouă' : 'sesiuni noi'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          dates.isEmpty
                              ? 'Alege o dată viitoare și cel puțin o zi. Programările identice sunt omise.'
                              : '${formatDate(dates.first)}${dates.length > 1 ? ' — ${formatDate(dates.last)}' : ''}\nProgramările identice și orele trecute sunt omise.',
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
                      ? 'Se salvează…'
                      : 'Adaugă ${dates.length} ${dates.length == 1 ? 'sesiune' : 'sesiuni'}',
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

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final history = [...store.history]
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      final totalSets = history.fold<int>(
        0,
        (sum, session) => sum + session.completedSets,
      );
      final records = _records(history);
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Progres',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: PageBody(
          children: [
            Text(
              'Fiecare set contează.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Progresul tău, din antrenamentele finalizate.',
              style: TextStyle(color: PiColors.muted(context)),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(
                    width: (constraints.maxWidth - 12) / 2,
                    value: '${history.length}',
                    label: 'antrenamente',
                    icon: Icons.fitness_center_rounded,
                  ),
                  _StatCard(
                    width: (constraints.maxWidth - 12) / 2,
                    value: '$totalSets',
                    label: 'seturi completate',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  _StatCard(
                    width: (constraints.maxWidth - 12) / 2,
                    value: _volume(store.totalVolume),
                    label: 'kg volum total',
                    icon: Icons.monitor_weight_outlined,
                  ),
                  _StatCard(
                    width: (constraints.maxWidth - 12) / 2,
                    value: '${store.weeklyCount}',
                    label: 'săptămâna aceasta',
                    icon: Icons.local_fire_department_outlined,
                  ),
                ],
              ),
            ),
            const SectionHeading(title: 'Consecvența ta'),
            _WeeklyChart(history: history),
            const SectionHeading(title: 'Recorduri personale'),
            if (records.isEmpty)
              const _PlanningEmpty(
                icon: Icons.emoji_events_outlined,
                title: 'Primul record te așteaptă',
                subtitle:
                    'Finalizează un antrenament cu seturi bifate. Aici apar greutățile și repetările tale reale.',
              )
            else
              PiCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 4,
                ),
                child: Column(
                  children: List.generate(records.length, (index) {
                    final record = records[index];
                    final exercise = _exerciseName(store, record.exerciseId);
                    return Column(
                      children: [
                        if (index > 0) const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: PiColors.lime.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.emoji_events_outlined,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exercise,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      formatDate(record.date),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: PiColors.muted(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    record.weight > 0
                                        ? '${_number(record.weight)} kg'
                                        : '${record.reps} rep',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    record.weight > 0
                                        ? '× ${record.reps} rep'
                                        : 'greutate corporală',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: PiColors.muted(context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            SectionHeading(
              title: 'Jurnal de antrenament',
              action: history.isEmpty ? null : '${history.length} sesiuni',
            ),
            if (history.isEmpty)
              const _PlanningEmpty(
                icon: Icons.history_rounded,
                title: 'Povestea ta începe aici',
                subtitle:
                    'Pornește un antrenament, bifează seturile și salvează sesiunea. Jurnalul și graficele se completează automat.',
              ),
            for (final session in history) ...[
              _HistoryCard(store: store, session: session),
              const SizedBox(height: 12),
            ],
          ],
        ),
      );
    },
  );

  List<_PersonalRecord> _records(List<WorkoutSession> history) {
    final records = <String, _PersonalRecord>{};
    for (final session in history) {
      for (final exercise in session.exercises) {
        for (final set in exercise.sets.where((set) => set.completed)) {
          final current = records[exercise.exerciseId];
          if (current == null ||
              set.weight > current.weight ||
              (set.weight == current.weight && set.reps > current.reps)) {
            records[exercise.exerciseId] = _PersonalRecord(
              exercise.exerciseId,
              set.weight,
              set.reps,
              session.startedAt,
            );
          }
        }
      }
    }
    return records.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }
}

class _PersonalRecord {
  const _PersonalRecord(this.exerciseId, this.weight, this.reps, this.date);
  final String exerciseId;
  final double weight;
  final int reps;
  final DateTime date;
}

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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
          ),
        ],
      ),
    ),
  );
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.history});
  final List<WorkoutSession> history;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
    final starts = List.generate(
      8,
      (index) => monday.subtract(Duration(days: (7 - index) * 7)),
    );
    final counts = starts
        .map(
          (start) => history
              .where(
                (session) =>
                    !session.startedAt.isBefore(start) &&
                    session.startedAt.isBefore(
                      start.add(const Duration(days: 7)),
                    ),
              )
              .length,
        )
        .toList();
    final maxValue = math.max(1, counts.fold<int>(0, math.max));
    final total = counts.fold<int>(0, (sum, count) => sum + count);
    return PiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$total antrenamente',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ultimele 8 săptămâni',
                      style: TextStyle(
                        color: PiColors.muted(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.bar_chart_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 172,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(8, (index) {
                final count = counts[index];
                return Expanded(
                  child: Semantics(
                    label:
                        'Săptămâna ${formatDate(starts[index])}: $count antrenamente',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: PiColors.muted(context),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Container(
                            height: count == 0 ? 3 : 100 * count / maxValue,
                            width: 25,
                            decoration: BoxDecoration(
                              color: count == 0
                                  ? Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.1)
                                  : PiColors.lime.withValues(
                                      alpha: index == 7 ? 1 : 0.45,
                                    ),
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            '${starts[index].day}/${starts[index].month}',
                            style: TextStyle(
                              fontSize: 9,
                              color: PiColors.muted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Fără sesiuni finalizate în această perioadă.',
                style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
              ),
            ),
        ],
      ),
    );
  }
}

String _exerciseName(AppStore store, String id) {
  for (final exercise in store.exercises) {
    if (exercise.id == id) {
      return exercise.name;
    }
  }
  return 'Exercițiu salvat';
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.store, required this.session});
  final AppStore store;
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) => PiCard(
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
                style: TextStyle(color: PiColors.muted(context), fontSize: 11),
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
                    label: '${session.completedSets} seturi',
                  ),
                  _InlineMetric(
                    icon: Icons.fitness_center_rounded,
                    label: '${_volume(session.volume)} kg',
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
      Text(
        label,
        style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
      ),
    ],
  );
}

class _SessionDetails extends StatelessWidget {
  const _SessionDetails({required this.store, required this.session});
  final AppStore store;
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
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
                label: '${session.completedSets} / ${session.totalSets} seturi',
              ),
              _InlineMetric(
                icon: Icons.fitness_center_rounded,
                label: '${_volume(session.volume)} kg volum',
              ),
            ],
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
                          'GREUTATE × REP',
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
                              style: TextStyle(color: PiColors.muted(context)),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${exercise.sets[index].weight == 0 ? 'Corp' : '${_number(exercise.sets[index].weight)} kg'} × ${exercise.sets[index].reps}',
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
                          Icon(
                            exercise.sets[index].completed
                                ? Icons.check_circle_rounded
                                : Icons.remove_circle_outline_rounded,
                            color: exercise.sets[index].completed
                                ? Theme.of(context).colorScheme.primary
                                : PiColors.muted(context),
                            size: 19,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (session.notes.trim().isNotEmpty) ...[
            const SectionHeading(title: 'Notițele tale'),
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
              child: const Text('Închide'),
            ),
          ),
        ],
      ),
    ),
  );
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
