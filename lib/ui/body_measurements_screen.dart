import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/body_measurement.dart';
import '../state/app_store.dart';
import 'health_screen.dart';
import 'theme.dart';

class BodyMeasurementsScreen extends StatefulWidget {
  const BodyMeasurementsScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<BodyMeasurementsScreen> createState() => _BodyMeasurementsScreenState();
}

class _BodyMeasurementsScreenState extends State<BodyMeasurementsScreen> {
  int? periodDays = 30;

  Future<void> addMeasurement() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MeasurementEditor(store: widget.store),
  );

  @override
  Widget build(BuildContext context) => GlassBackground(
    child: Scaffold(
      appBar: AppBar(title: const Text('Body measurements')),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final now = DateTime.now();
          final cutoff = periodDays == null
              ? null
              : DateTime(now.year, now.month, now.day - periodDays! + 1);
          final all = widget.store.bodyMeasurements;
          final records = all
              .where((m) => cutoff == null || !m.measuredAt.isBefore(cutoff))
              .toList();
          final weights = records
              .where((m) => m.weightKg != null)
              .toList()
              .reversed
              .toList();
          final latestWeight =
              all.where((m) => m.weightKg != null).firstOrNull?.weightKg ??
              widget.store.profile.weightKg;
          final latestHeight =
              all.where((m) => m.heightCm != null).firstOrNull?.heightCm ??
              widget.store.profile.heightCm;
          final change = weights.length < 2
              ? null
              : weights.last.weightKg! - weights.first.weightKg!;
          return PageBody(
            children: [
              Text(
                'You, over time.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 10),
              Text(
                'Track weight and height at your own pace. These are personal measurements; a change alone does not define progress.',
                style: TextStyle(color: PiColors.muted(context)),
              ),
              const SizedBox(height: 22),
              PiCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Latest weight',
                        value: latestWeight == null
                            ? '—'
                            : '${_number(latestWeight)} kg',
                        icon: Icons.monitor_weight_outlined,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 54,
                      color: Theme.of(context).dividerColor,
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _Metric(
                        label: 'Latest height',
                        value: latestHeight == null
                            ? '—'
                            : '${_number(latestHeight)} cm',
                        icon: Icons.height_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('add-measurement'),
                  onPressed: addMeasurement,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add measurement'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => HealthScreen(store: widget.store),
                    ),
                  ),
                  icon: const Icon(Icons.favorite_outline_rounded),
                  label: const Text('Data from Health'),
                ),
              ),
              const SectionHeading(title: 'Weight over time'),
              SegmentedButton<int?>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 30, label: Text('30 days')),
                  ButtonSegment(value: 90, label: Text('90 days')),
                  ButtonSegment(value: null, label: Text('All time')),
                ],
                selected: {periodDays},
                onSelectionChanged: (v) => setState(() => periodDays = v.first),
              ),
              const SizedBox(height: 14),
              PiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (weights.isEmpty) ...[
                      const Icon(Icons.show_chart_rounded, size: 30),
                      const SizedBox(height: 12),
                      const Text(
                        'No weight measurements in this period yet.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add a measurement or choose a longer period. Values between records are not estimated.',
                        style: TextStyle(color: PiColors.muted(context)),
                      ),
                    ] else ...[
                      Text(
                        change == null
                            ? 'First measurement in this period'
                            : '${weights.length} measurements · change ${_signed(change)} kg',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        change == null
                            ? 'Add a second measurement to track change.'
                            : 'From ${_number(weights.first.weightKg!)} kg to ${_number(weights.last.weightKg!)} kg. This compares the first and last measurement in the selected period.',
                        style: TextStyle(
                          fontSize: 12,
                          color: PiColors.muted(context),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Semantics(
                        label:
                            'Weight chart. ${weights.map((m) => '${formatDate(m.measuredAt)}: ${_number(m.weightKg!)} kilograms').join('; ')}',
                        child: ExcludeSemantics(
                          child: SizedBox(
                            height: 164,
                            width: double.infinity,
                            child: CustomPaint(
                              key: const Key('weight-chart'),
                              painter: _WeightPainter(
                                records: weights,
                                accent: Theme.of(context).colorScheme.primary,
                                grid: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: .08),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatDate(weights.first.measuredAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: PiColors.muted(context),
                              ),
                            ),
                          ),
                          Text(
                            formatDate(weights.last.measuredAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: PiColors.muted(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'The line connects recorded values; change between dates was not measured.',
                        style: TextStyle(
                          fontSize: 11,
                          color: PiColors.muted(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SectionHeading(
                title: 'History',
                action:
                    '${records.length} ${records.length == 1 ? 'record' : 'records'}',
              ),
              if (records.isEmpty)
                PiCard(
                  child: Text(
                    'Measurements added manually, from Profile, or explicitly imported from Health will appear here.',
                    style: TextStyle(color: PiColors.muted(context)),
                  ),
                ),
              ...records.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PiCard(
                    key: ValueKey('body-record-${m.id}'),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: PiColors.lime.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            m.source == 'health'
                                ? Icons.favorite_outline_rounded
                                : Icons.straighten_rounded,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatDate(m.measuredAt),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${m.source == 'health' ? '${formatTime(m.measuredAt)} · ' : ''}${m.sourceName ?? (m.source == 'health' ? 'Health' : 'Manual')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: PiColors.muted(context),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 14,
                                runSpacing: 4,
                                children: [
                                  if (m.weightKg != null)
                                    Text(
                                      '${_number(m.weightKg!)} kg',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  if (m.heightCm != null)
                                    Text(
                                      '${_number(m.heightCm!)} cm',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Measurements belong to this profile and are included in its backup. Changing weight or height in Profile adds a record automatically. Clearing a Profile field keeps the history.',
                style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 10),
      Text(
        value,
        style: const TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w800,
          letterSpacing: -.6,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
      ),
    ],
  );
}

class _MeasurementEditor extends StatefulWidget {
  const _MeasurementEditor({required this.store});
  final AppStore store;
  @override
  State<_MeasurementEditor> createState() => _MeasurementEditorState();
}

class _MeasurementEditorState extends State<_MeasurementEditor> {
  final form = GlobalKey<FormState>();
  final weight = TextEditingController(), height = TextEditingController();
  late final String? accountId;
  DateTime measuredAt = DateTime.now();
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    accountId = widget.store.accountId;
  }

  @override
  void dispose() {
    weight.dispose();
    height.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (widget.store.accountId != accountId || busy) return;
    if (!form.currentState!.validate()) return;
    if (weight.text.trim().isEmpty && height.text.trim().isEmpty) {
      setState(() => error = 'Enter at least your weight or height.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.recordBodyMeasurement(
        weightKg: _decimal(weight.text),
        heightCm: _decimal(height.text),
        measuredAt: measuredAt,
      );
      if (mounted && widget.store.accountId == accountId) {
        toast(context, 'Measurement saved.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted && widget.store.accountId == accountId) {
        setState(
          () => error = e
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Invalid argument(s): ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> chooseDate() async {
    final now = DateTime.now();
    final chosen = await showDatePicker(
      context: context,
      initialDate: measuredAt,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (chosen == null || !mounted || widget.store.accountId != accountId) {
      return;
    }
    setState(
      () => measuredAt = DateTime(
        chosen.year,
        chosen.month,
        chosen.day,
        measuredAt.hour,
        measuredAt.minute,
        measuredAt.second,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      22,
      4,
      22,
      MediaQuery.viewInsetsOf(context).bottom + 22,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Add measurement',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'One field is enough. An older record does not replace a more recent measurement in Profile.',
              style: TextStyle(color: PiColors.muted(context), fontSize: 12),
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('measurement-weight'),
              controller: weight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                helperText: 'Optional · 25–350 kg',
              ),
              validator: (v) => _validate(v, 25, 350),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('measurement-height'),
              controller: height,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Height (cm)',
                helperText: 'Optional · 100–250 cm',
              ),
              validator: (v) => _validate(v, 100, 250),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: busy ? null : chooseDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('Date: ${formatDate(measuredAt)}'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('save-measurement'),
              onPressed: busy ? null : save,
              child: Text(busy ? 'Saving…' : 'Save measurement'),
            ),
          ],
        ),
      ),
    ),
  );

  String? _validate(String? raw, num min, num max) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = _decimal(raw);
    return value == null || !value.isFinite || value < min || value > max
        ? 'Enter a value between $min and $max.'
        : null;
  }
}

class _WeightPainter extends CustomPainter {
  const _WeightPainter({
    required this.records,
    required this.accent,
    required this.grid,
  });
  final List<BodyMeasurement> records;
  final Color accent, grid;
  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;
    final bounds = Rect.fromLTWH(
      8,
      8,
      math.max(0, size.width - 16),
      math.max(0, size.height - 16),
    );
    final minimum = records.map((m) => m.weightKg!).reduce(math.min);
    final maximum = records.map((m) => m.weightKg!).reduce(math.max);
    final padding = math.max((maximum - minimum) * .15, .5);
    final lower = minimum - padding, upper = maximum + padding;
    final start = records.first.measuredAt.millisecondsSinceEpoch;
    final span = records.last.measuredAt.millisecondsSinceEpoch - start;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var row = 0; row < 4; row++) {
      final y = bounds.top + bounds.height * row / 3;
      canvas.drawLine(
        Offset(bounds.left, y),
        Offset(bounds.right, y),
        gridPaint,
      );
    }
    final points = records
        .map(
          (m) => Offset(
            bounds.left +
                bounds.width *
                    (span == 0
                        ? .5
                        : (m.measuredAt.millisecondsSinceEpoch - start) / span),
            bounds.bottom -
                bounds.height * ((m.weightKg! - lower) / (upper - lower)),
          ),
        )
        .toList();
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final point in points) {
      canvas.drawCircle(point, 4, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(_WeightPainter oldDelegate) =>
      oldDelegate.records != records ||
      oldDelegate.accent != accent ||
      oldDelegate.grid != grid;
}

double? _decimal(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));
String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
String _signed(double value) =>
    '${value > 0 ? '+' : ''}${_number(double.parse(value.toStringAsFixed(2)))}';
