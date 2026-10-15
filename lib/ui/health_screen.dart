import 'package:flutter/material.dart';

import '../services/health_service.dart';
import '../state/app_store.dart';
import 'live_heart_rate_card.dart';
import 'theme.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key, required this.store, this.service});
  final AppStore store;
  final HealthService? service;
  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  late HealthService _service;
  HealthAvailability? _availability;
  HealthSnapshot? _snapshot;
  String? _energySource;
  String? _error;
  String? _accountId;
  bool _busy = false;
  int _operation = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? HealthService();
    _accountId = widget.store.accountId;
    widget.store.addListener(_accountChanged);
    _inspect();
  }

  @override
  void didUpdateWidget(covariant HealthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_accountChanged);
      widget.store.addListener(_accountChanged);
      _accountChanged();
    }
  }

  void _accountChanged() {
    if (_accountId == widget.store.accountId) return;
    _accountId = widget.store.accountId;
    _operation++;
    if (mounted) {
      setState(() {
        _snapshot = null;
        _energySource = null;
        _error = null;
        _busy = false;
        _service = widget.service ?? HealthService();
      });
    }
  }

  Future<void> _inspect() async {
    final availability = await _service.inspect();
    if (mounted) setState(() => _availability = availability);
  }

  Future<void> _installProvider() async {
    final operation = _operation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.installProvider();
      if (mounted && operation == _operation) await _inspect();
    } catch (_) {
      if (mounted && operation == _operation) {
        setState(
          () => _error =
              'The installer could not be opened. Install or update Health Connect from your app store, then check again.',
        );
      }
    } finally {
      if (mounted && operation == _operation) setState(() => _busy = false);
    }
  }

  Future<void> _read({required bool connect}) async {
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snapshot = await (connect
          ? _service.connect()
          : _service.refresh());
      if (!mounted || operation != _operation) return;
      setState(() {
        _snapshot = snapshot;
        if (!snapshot.energySources.contains(_energySource)) {
          _energySource = snapshot.energySources.firstOrNull;
        }
      });
    } catch (error) {
      if (!mounted || operation != _operation) return;
      setState(() {
        _snapshot = null;
        _error = error is HealthReadException
            ? error.message
            : 'Health data could not be read. Check permissions in your health app and try again.';
      });
    } finally {
      if (mounted && operation == _operation) setState(() => _busy = false);
    }
  }

  Future<void> _importBody(HealthBodyRecord record) async {
    final accountId = widget.store.accountId;
    final operation = _operation;
    final weight = record.kind == HealthBodyKind.weight;
    final value = '${_number(record.value)} ${weight ? 'kg' : 'cm'}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Import ${weight ? 'weight' : 'height'}?'),
        content: Text(
          '$value · ${formatDate(record.measuredAt)}\n${record.sourceName}\n\nOnly this selected measurement will be saved to this profile. It can be used in reports, backups and local coaching. Online AI receives profile details only if you enable personalization. An older record will not replace a newer value in your profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Import measurement'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        accountId != widget.store.accountId ||
        operation != _operation) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.recordBodyMeasurement(
        weightKg: weight ? record.value : null,
        heightCm: weight ? null : record.value,
        measuredAt: record.measuredAt,
        source: 'health',
        sourceRecordId: record.id,
        sourceName: record.sourceName,
      );
      if (mounted &&
          accountId == widget.store.accountId &&
          operation == _operation) {
        toast(context, 'Measurement added to your history.');
      }
    } catch (error) {
      if (mounted &&
          accountId == widget.store.accountId &&
          operation == _operation) {
        setState(
          () => _error = error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Invalid argument(s): ', ''),
        );
      }
    } finally {
      if (mounted &&
          accountId == widget.store.accountId &&
          operation == _operation) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _bodyRecord(HealthBodyRecord record) {
    final imported = widget.store.bodyMeasurements.any(
      (m) => m.source == 'health' && m.sourceRecordId == record.id,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PiCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${record.kind == HealthBodyKind.weight ? 'Weight' : 'Height'} · ${_number(record.value)} ${record.kind == HealthBodyKind.weight ? 'kg' : 'cm'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              '${formatDate(record.measuredAt)} · ${formatTime(record.measuredAt)}\n${record.sourceName}',
              style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: ValueKey('health-import-${record.id}'),
              onPressed: _busy || imported ? null : () => _importBody(record),
              icon: Icon(imported ? Icons.check_rounded : Icons.add_rounded),
              label: Text(
                imported ? 'Already imported' : 'Import this measurement',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _operation++;
    widget.store.removeListener(_accountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return GlassBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Health and activity')),
        body: PageBody(
          children: [
            LiveHeartRateCard(store: widget.store),
            const SizedBox(height: 16),
            PiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    color: PiColors.mint,
                    size: 32,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _service.providerName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Steps, active energy and workouts from the last 7 days, plus available body measurements and heart rate records.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Health data stays on this screen unless you explicitly import a body measurement. Imported values become part of your profile and can be used in reports, backups and local coaching. Online AI receives profile details only with your personalization permission. Other Health data stays here. Your training score is based on your Pi Fit journal.',
                    style: TextStyle(color: PiColors.muted(context)),
                  ),
                  const SizedBox(height: 18),
                  if (_availability == null)
                    const LinearProgressIndicator()
                  else if (_availability == HealthAvailability.unsupported)
                    const Text(
                      'Available on Android through Health Connect and on iPhone through Apple Health. Browsers and desktop apps cannot access this data.',
                      key: ValueKey('health-unsupported'),
                    )
                  else if (_availability ==
                      HealthAvailability.installRequired) ...[
                    const Text(
                      'Install or update Health Connect, then check availability again.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton(
                          onPressed: _busy ? null : _installProvider,
                          child: const Text('Open installation'),
                        ),
                        OutlinedButton(
                          onPressed: _busy ? null : _inspect,
                          child: const Text('Check again'),
                        ),
                      ],
                    ),
                  ] else if (_availability ==
                      HealthAvailability.unavailable) ...[
                    const Text(
                      'The health service is unavailable here. Health Connect needs a compatible device; on iOS check access to Apple Health.',
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _busy ? null : _inspect,
                      child: const Text('Check again'),
                    ),
                  ] else ...[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          key: const ValueKey('health-connect'),
                          onPressed: _busy ? null : () => _read(connect: true),
                          icon: const Icon(Icons.health_and_safety_outlined),
                          label: Text(
                            snapshot == null
                                ? 'Connect and choose access'
                                : 'Review permissions',
                          ),
                        ),
                        if (snapshot != null)
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _read(connect: false),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Refresh'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We request read-only access to steps, active energy, workouts, weight, height and heart rate. Change or withdraw access in Apple Health or Health Connect settings.',
                      style: TextStyle(
                        fontSize: 12,
                        color: PiColors.muted(context),
                      ),
                    ),
                  ],
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (snapshot != null) ...[
              const SectionHeading(title: 'Last 7 days'),
              Text(
                'Read at ${formatDate(snapshot.updatedAt)} · ${formatTime(snapshot.updatedAt)}',
                style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
              ),
              const SizedBox(height: 12),
              if (snapshot.iosReadAccessUndisclosed)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: PiCard(
                    child: Text(
                      'Apple does not disclose whether read access was denied. An empty list may mean no data or no permission; opening this screen does not confirm all permissions.',
                    ),
                  ),
                ),
              for (final warning in snapshot.warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PiCard(child: Text(warning)),
                ),
              if (snapshot.latestHeartRate != null) ...[
                const SectionHeading(title: 'Latest synced heart rate'),
                PiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_number(snapshot.latestHeartRate!.beatsPerMinute)} bpm',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${formatDate(snapshot.latestHeartRate!.measuredAt)} · ${formatTime(snapshot.latestHeartRate!.measuredAt)}\n${snapshot.latestHeartRate!.sourceName}',
                        style: TextStyle(color: PiColors.muted(context)),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'This is the latest record synced by your health platform, not a live watch reading.',
                      ),
                    ],
                  ),
                ),
              ],
              const SectionHeading(title: 'Body measurements from Health'),
              Text(
                'Read window: up to ${snapshot.bodyLookbackDays} days. Select an individual record to import it into your profile. Nothing is imported automatically.',
                style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
              ),
              const SizedBox(height: 12),
              if (snapshot.bodyRecords.isEmpty)
                const PiCard(
                  child: Text(
                    'No accessible weight or height records in this read window. Check your sources and permissions.',
                  ),
                ),
              ...snapshot.bodyRecords.map(_bodyRecord),
              const SectionHeading(title: 'Steps and active energy'),
              PiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Steps reported by your platform',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      snapshot.totalSteps?.toString() ?? '—',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Totals use platform aggregation. A dash means the data could not be read.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recorded active energy',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${snapshot.totalEnergy(_energySource)?.round().toString() ?? '—'} kcal',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    if (snapshot.energySources.isNotEmpty)
                      DropdownButtonFormField<String>(
                        key: ValueKey('energy-$_energySource'),
                        initialValue: _energySource,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Energy source',
                        ),
                        items: snapshot.energySources
                            .map(
                              (source) => DropdownMenuItem(
                                value: source,
                                child: Text(
                                  source.isEmpty ? 'Unnamed source' : source,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (source) =>
                            setState(() => _energySource = source),
                      ),
                    const SizedBox(height: 10),
                    const Text(
                      'One source is shown at a time to avoid adding apps that report the same activity. These are source records; Pi Fit does not estimate calories.',
                    ),
                  ],
                ),
              ),
              const SectionHeading(title: 'By day'),
              PiCard(
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Day',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Steps',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'kcal',
                            textAlign: TextAlign.end,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final day in snapshot.days.reversed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(formatDate(day.date)),
                            ),
                            Expanded(child: Text(day.steps?.toString() ?? '—')),
                            Expanded(
                              child: Text(
                                snapshot
                                        .energyForDay(day.date, _energySource)
                                        ?.round()
                                        .toString() ??
                                    '—',
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Energy is grouped by the start of each record. Records crossing midnight are not split using estimates.',
                      style: TextStyle(
                        fontSize: 12,
                        color: PiColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              SectionHeading(
                title: 'Workout records (${snapshot.workouts.length})',
              ),
              if (snapshot.workouts.isEmpty)
                const PiCard(
                  child: Text(
                    'No accessible workouts in this period. Check sources and permissions in your health app.',
                  ),
                ),
              for (final workout in snapshot.workouts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workout.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${formatDate(workout.start)} · ${formatTime(workout.start)} – ${formatTime(workout.end)} · ${workout.duration.inMinutes} min',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          workout.source,
                          style: TextStyle(
                            fontSize: 12,
                            color: PiColors.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 5),
              Text(
                'External workouts are not imported into the Pi Fit journal and do not increase your streak or score. This version does not write workouts to your health platform.',
                style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
