import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/report_export_service.dart';
import '../state/app_store.dart';
import 'theme.dart';

enum _ExportPeriod { week, month, quarter, all, custom }

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.store, this.service});
  final AppStore store;
  final ReportExportService? service;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final _title = TextEditingController(text: 'My training story');
  _ExportPeriod _period = _ExportPeriod.month;
  ReportAppearance _appearance = ReportAppearance.app;
  final _sections = <ReportSection>{
    ReportSection.summary,
    ReportSection.journal,
    ReportSection.records,
  };
  late DateTime _end = _today();
  late DateTime _start = DateTime(_end.year, _end.month, _end.day - 27);
  String? _scope;
  int _generation = 0;
  bool _busy = false;
  String? _error;
  Uint8List? _bytes;
  PiFitReport? _generatedReport;

  @override
  void initState() {
    super.initState();
    _scope = widget.store.accountId;
    widget.store.addListener(_storeChanged);
  }

  @override
  void dispose() {
    _generation++;
    widget.store.removeListener(_storeChanged);
    _title.dispose();
    super.dispose();
  }

  void _storeChanged() {
    if (!mounted) return;
    if (_scope != widget.store.accountId) {
      _scope = widget.store.accountId;
      _generation++;
      setState(() {
        _bytes = null;
        _generatedReport = null;
        _busy = false;
        _period = _ExportPeriod.month;
        _end = _today();
        _start = DateTime(_end.year, _end.month, _end.day - 27);
        _title.text = 'My training story';
        _error = 'Your account changed. Create a new report for this account.';
      });
    } else {
      final hadReport = _bytes != null || _busy;
      _generation++;
      setState(() {
        _bytes = null;
        _generatedReport = null;
        _busy = false;
        if (_period == _ExportPeriod.all) {
          _start = _earliestDate();
        }
        if (hadReport) {
          _error = 'Your training data changed. Create a fresh PDF.';
        }
      });
    }
  }

  DateTime _earliestDate() {
    final dates = [
      for (final session in ReportExportService.usableSessions(
        widget.store.history,
      ))
        session.startedAt.toLocal(),
      for (final item in widget.store.bodyMeasurements)
        if (!item.measuredAt.isAfter(DateTime.now())) item.measuredAt.toLocal(),
    ]..sort();
    return dates.isEmpty
        ? _today()
        : DateTime(dates.first.year, dates.first.month, dates.first.day);
  }

  void _change(VoidCallback change) => setState(() {
    change();
    _generation++;
    _bytes = null;
    _generatedReport = null;
    _error = null;
  });

  void _selectPeriod(_ExportPeriod period) {
    final end = _today();
    final sessions = ReportExportService.usableSessions(widget.store.history);
    final dates = [
      for (final session in sessions) session.startedAt.toLocal(),
      for (final item in widget.store.bodyMeasurements)
        if (!item.measuredAt.isAfter(DateTime.now())) item.measuredAt.toLocal(),
    ]..sort();
    _change(() {
      _period = period;
      _end = end;
      _start = switch (period) {
        _ExportPeriod.week => DateTime(end.year, end.month, end.day - 6),
        _ExportPeriod.month => DateTime(end.year, end.month, end.day - 27),
        _ExportPeriod.quarter => DateTime(end.year, end.month, end.day - 89),
        _ExportPeriod.all =>
          dates.isEmpty
              ? end
              : DateTime(dates.first.year, dates.first.month, dates.first.day),
        _ExportPeriod.custom => _start,
      };
    });
  }

  Future<void> _pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: _today(),
      initialDateRange: DateTimeRange(start: _start, end: _end),
      helpText: 'Choose report dates',
      saveText: 'Apply',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          datePickerTheme: Theme.of(context).datePickerTheme.copyWith(
            rangePickerHeaderHeadlineStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (range == null || !mounted) return;
    _change(() {
      _period = _ExportPeriod.custom;
      _start = range.start;
      _end = range.end;
    });
  }

  PiFitReport _report() => ReportExportService.create(
    options: ReportOptions(
      start: _start,
      end: _end,
      title: _title.text,
      appearance: _appearance,
      sections: _sections,
    ),
    displayName: widget.store.name,
    history: [...widget.store.history],
    exercises: widget.store.exercises,
    profile: widget.store.profile,
    measurements: [...widget.store.bodyMeasurements],
  );

  bool get _dark => switch (_appearance) {
    ReportAppearance.dark => true,
    ReportAppearance.light => false,
    ReportAppearance.app => Theme.of(context).brightness == Brightness.dark,
  };

  Future<void> _generate() async {
    if (_sections.isEmpty) return;
    final generation = ++_generation;
    final scope = widget.store.accountId;
    final report = _report();
    final dark = _dark;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await (widget.service ?? ReportExportService()).buildPdf(
        report,
        dark: dark,
      );
      if (!mounted ||
          generation != _generation ||
          scope != widget.store.accountId) {
        return;
      }
      setState(() {
        _bytes = bytes;
        _generatedReport = report;
        _busy = false;
      });
    } catch (_) {
      if (!mounted ||
          generation != _generation ||
          scope != widget.store.accountId) {
        return;
      }
      setState(() {
        _busy = false;
        _error =
            'The PDF could not be created. Your training data is unchanged. Please try again.';
      });
    }
  }

  Future<void> _share({required bool print}) async {
    final bytes = _bytes;
    final report = _generatedReport;
    final scope = _scope;
    final generation = _generation;
    if (bytes == null || report == null || scope != widget.store.accountId) {
      return;
    }
    try {
      if (print) {
        await Printing.layoutPdf(
          name: report.filename,
          onLayout: (_) async {
            if (!mounted ||
                generation != _generation ||
                scope != widget.store.accountId) {
              throw StateError('The account or report changed.');
            }
            return bytes;
          },
        );
      } else {
        if (generation != _generation || scope != widget.store.accountId) {
          return;
        }
        await Printing.sharePdf(bytes: bytes, filename: report.filename);
      }
    } catch (_) {
      if (mounted &&
          generation == _generation &&
          scope == widget.store.accountId) {
        setState(
          () => _error =
              'This device could not open the PDF action. Try Print / Save PDF or another browser.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report();
    return Scaffold(
      appBar: AppBar(title: const Text('Export your progress')),
      body: PageBody(
        children: [
          Text(
            'YOUR STORY. YOUR STYLE.',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: PiColors.muted(context),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Progress worth keeping.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Create a personal Pi Fit PDF with your training, records and saved measurements.',
            style: TextStyle(color: PiColors.muted(context)),
          ),
          const SectionHeading(title: '1. Choose a period'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in [
                (_ExportPeriod.week, '7 days'),
                (_ExportPeriod.month, '28 days'),
                (_ExportPeriod.quarter, '90 days'),
                (_ExportPeriod.all, 'All time'),
              ])
                ChoiceChip(
                  key: ValueKey('export-period-${item.$1.name}'),
                  label: Text(item.$2),
                  selected: _period == item.$1,
                  showCheckmark: false,
                  onSelected: _busy ? null : (_) => _selectPeriod(item.$1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          PiCard(
            padding: const EdgeInsets.all(16),
            onTap: _busy ? null : _pickDates,
            child: Row(
              children: [
                const Icon(Icons.date_range_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Custom dates',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatDate(_start)} — ${formatDate(_end)}',
                        key: const ValueKey('export-bounds'),
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
          const SizedBox(height: 10),
          Text(
            '${report.workoutCount} completed ${report.workoutCount == 1 ? 'workout' : 'workouts'} · ${report.activeDays} active ${report.activeDays == 1 ? 'day' : 'days'}\nBoth dates included, in your device’s local time zone.',
            key: const ValueKey('export-count'),
            style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
          ),
          const SectionHeading(title: '2. Make it yours'),
          TextField(
            controller: _title,
            enabled: !_busy,
            maxLength: 80,
            onChanged: (_) => _change(() {}),
            decoration: const InputDecoration(
              labelText: 'Report title',
              hintText: 'My training story',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in [
                (ReportAppearance.app, 'Match app'),
                (ReportAppearance.light, 'Light'),
                (ReportAppearance.dark, 'Dark'),
              ])
                ChoiceChip(
                  label: Text(item.$2),
                  selected: _appearance == item.$1,
                  showCheckmark: false,
                  onSelected: _busy
                      ? null
                      : (_) => _change(() => _appearance = item.$1),
                ),
            ],
          ),
          const SectionHeading(title: '3. Include what matters'),
          PiCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final item in [
                  (
                    ReportSection.summary,
                    'Training overview',
                    'Workout count, sets, external volume and an activity chart.',
                  ),
                  (
                    ReportSection.journal,
                    'Workout journal',
                    'Dates, routines, completed sets, volume and duration.',
                  ),
                  (
                    ReportSection.records,
                    'Best sets',
                    'Your best eligible sets within the selected dates.',
                  ),
                  (
                    ReportSection.bodyMeasurements,
                    'Saved measurements',
                    'Weight and height entries you saved or explicitly imported.',
                  ),
                ])
                  CheckboxListTile(
                    key: ValueKey('export-section-${item.$1.name}'),
                    value: _sections.contains(item.$1),
                    title: Text(
                      item.$2,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      item.$3,
                      style: TextStyle(
                        fontSize: 11,
                        color: PiColors.muted(context),
                      ),
                    ),
                    onChanged: _busy
                        ? null
                        : (selected) => _change(() {
                            if (selected == true) {
                              _sections.add(item.$1);
                            } else if (_sections.length > 1) {
                              _sections.remove(item.$1);
                            }
                          }),
                  ),
              ],
            ),
          ),
          const SectionHeading(title: 'Your report at a glance'),
          _ReportCover(report: report, dark: _dark),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(_busy ? 'Creating your PDF…' : 'Create PDF preview'),
            ),
          ),
          if (_bytes != null && _generatedReport != null) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 520,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: PdfPreview(
                  key: ValueKey('pdf-preview-$_generation'),
                  build: (_) async {
                    if (_scope != widget.store.accountId || _bytes == null) {
                      throw StateError(
                        'Create a report for the current account.',
                      );
                    }
                    return _bytes!;
                  },
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  useActions: false,
                  pdfFileName: _generatedReport!.filename,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _share(print: false),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share / Download PDF'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _share(print: true),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print / Save PDF'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'The PDF is created on your device. Health data is included only when you explicitly saved a measurement in Pi Fit.',
            style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
          ),
        ],
      ),
    );
  }
}

class _ReportCover extends StatelessWidget {
  const _ReportCover({required this.report, required this.dark});
  final PiFitReport report;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: dark ? const Color(0xFF101B17) : const Color(0xFFF5F8F2),
      border: Border.all(color: PiColors.line(context)),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: PiColors.lime,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Pi Fit',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF192600),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          report.options.title.trim().isEmpty
              ? 'My training story'
              : report.options.title,
          style: TextStyle(
            fontSize: 27,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            color: dark ? Colors.white : const Color(0xFF16251D),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          report.displayName,
          style: TextStyle(
            fontSize: 13,
            color: dark ? Colors.white70 : const Color(0xFF607168),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '${formatDate(report.options.start)} — ${formatDate(report.options.end)}',
          style: TextStyle(
            fontSize: 11,
            color: dark ? Colors.white70 : const Color(0xFF607168),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 18,
          runSpacing: 12,
          children: [
            _coverMetric('${report.workoutCount}', 'workouts'),
            _coverMetric('${report.completedSets}', 'completed sets'),
            if (report.options.sections.contains(
              ReportSection.bodyMeasurements,
            ))
              _coverMetric('${report.measurements.length}', 'measurements')
            else
              _coverMetric('${report.options.sections.length}', 'sections'),
          ],
        ),
      ],
    ),
  );

  Widget _coverMetric(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: dark ? PiColors.lime : const Color(0xFF3D6500),
        ),
      ),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: dark ? Colors.white70 : const Color(0xFF607168),
        ),
      ),
    ],
  );
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
