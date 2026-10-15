import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/body_measurement.dart';
import '../domain/models.dart';
import '../domain/training_analytics.dart';
import '../domain/user_profile.dart';

enum ReportSection { summary, journal, records, bodyMeasurements }

enum ReportAppearance { app, light, dark }

class ReportOptions {
  ReportOptions({
    required DateTime start,
    required DateTime end,
    this.title = 'My progress',
    this.appearance = ReportAppearance.app,
    Set<ReportSection> sections = const {
      ReportSection.summary,
      ReportSection.journal,
      ReportSection.records,
    },
  }) : start = DateTime(
         start.toLocal().year,
         start.toLocal().month,
         start.toLocal().day,
       ),
       end = DateTime(
         end.toLocal().year,
         end.toLocal().month,
         end.toLocal().day,
       ),
       sections = Set.unmodifiable(sections) {
    if (this.end.isBefore(this.start) ||
        title.trim().runes.length > 2048 ||
        this.sections.isEmpty) {
      throw ArgumentError('Choose a valid period and at least one section.');
    }
  }
  final DateTime start;
  final DateTime end;
  final String title;
  final ReportAppearance appearance;
  final Set<ReportSection> sections;
  DateTime get endExclusive => DateTime(end.year, end.month, end.day + 1);
  int get calendarDays =>
      DateTime.utc(
        end.year,
        end.month,
        end.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
      1;
}

class ReportSession {
  const ReportSession({
    required this.session,
    required this.completedSets,
    required this.volume,
    this.averageRpe,
    this.ratedSets = 0,
  });
  final WorkoutSession session;
  final int completedSets;
  final double volume;
  final double? averageRpe;
  final int ratedSets;
}

class ReportActivityBin {
  const ReportActivityBin({
    required this.start,
    required this.end,
    required this.workoutCount,
    required this.volume,
  });
  final DateTime start;
  final DateTime end;
  final int workoutCount;
  final double volume;
}

class PiFitReport {
  PiFitReport({
    required this.options,
    required this.displayName,
    required this.generatedAt,
    required List<ReportSession> sessions,
    required List<ExerciseRecord> records,
    required List<BodyMeasurement> measurements,
    required List<ReportActivityBin> activity,
  }) : sessions = List.unmodifiable(sessions),
       records = List.unmodifiable(records),
       measurements = List.unmodifiable(measurements),
       activity = List.unmodifiable(activity);
  final ReportOptions options;
  final String displayName;
  final DateTime generatedAt;
  final List<ReportSession> sessions;
  final List<ExerciseRecord> records;
  final List<BodyMeasurement> measurements;
  final List<ReportActivityBin> activity;
  int get workoutCount => sessions.length;
  int get completedSets =>
      sessions.fold(0, (sum, item) => sum + item.completedSets);
  double get volume => sessions.fold(0.0, (sum, item) => sum + item.volume);
  int get activeDays => sessions
      .map((item) => _day(item.session.startedAt.toLocal()))
      .toSet()
      .length;
  double get durationMinutes => sessions.fold(
    0.0,
    (sum, item) =>
        sum +
        item.session.duration.inMilliseconds / Duration.millisecondsPerMinute,
  );
  int get ratedSets => sessions.fold(0, (sum, item) => sum + item.ratedSets);
  double? get averageRpe => ratedSets == 0
      ? null
      : sessions.fold(
              0.0,
              (sum, item) => sum + (item.averageRpe ?? 0) * item.ratedSets,
            ) /
            ratedSets;
  String get filename =>
      'Pi-Fit-${_fileDate(options.start)}-${_fileDate(options.end)}.pdf';
}

class ReportExportService {
  /// Same valid, completed, deduplicated session rules as training analytics.
  static List<WorkoutSession> usableSessions(
    List<WorkoutSession> history, {
    DateTime? now,
  }) {
    return completedTrainingSessions(history, now: now);
  }

  static PiFitReport create({
    required ReportOptions options,
    required String displayName,
    required List<WorkoutSession> history,
    required List<Exercise> exercises,
    required UserProfile profile,
    List<BodyMeasurement> measurements = const [],
    DateTime? now,
  }) {
    final asOf = (now ?? DateTime.now()).toLocal();
    final selected = usableSessions(history, now: asOf).where((session) {
      final date = session.startedAt.toLocal();
      return !date.isBefore(options.start) &&
          date.isBefore(options.endExclusive);
    }).toList()..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final catalog = {for (final exercise in exercises) exercise.id: exercise};
    final sessions = selected.map((session) {
      var sets = 0;
      var volume = 0.0;
      final effort = <double>[];
      for (final item in session.exercises) {
        for (final set in item.sets.where(isValidCompletedSet)) {
          sets++;
          if (set.rpe != null &&
              set.rpe!.isFinite &&
              set.rpe! >= 1 &&
              set.rpe! <= 10) {
            effort.add(set.rpe!);
          }
          if (isWeightedStrengthExercise(catalog[item.exerciseId])) {
            volume += set.weight * set.reps;
          }
        }
      }
      return ReportSession(
        session: session,
        completedSets: sets,
        volume: volume,
        ratedSets: effort.length,
        averageRpe: effort.isEmpty
            ? null
            : effort.reduce((a, b) => a + b) / effort.length,
      );
    }).toList();
    final records = analyzeTraining(
      history: selected,
      exercises: exercises,
      profile: profile,
      now: asOf,
    ).records;
    final selectedMeasurements =
        measurements
            .where(
              (item) =>
                  !item.measuredAt.isAfter(asOf) &&
                  !item.measuredAt.toLocal().isBefore(options.start) &&
                  item.measuredAt.toLocal().isBefore(options.endExclusive),
            )
            .toList()
          ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    // At most 12 chronological vector bars, each covering the labelled days.
    final binDays = math.max(1, (options.calendarDays / 12).ceil());
    final activity = <ReportActivityBin>[];
    for (var offset = 0; offset < options.calendarDays; offset += binDays) {
      final start = DateTime(
        options.start.year,
        options.start.month,
        options.start.day + offset,
      );
      final endExclusive = DateTime(
        options.start.year,
        options.start.month,
        options.start.day + math.min(options.calendarDays, offset + binDays),
      );
      final inBin = sessions.where(
        (item) =>
            !item.session.startedAt.toLocal().isBefore(start) &&
            item.session.startedAt.toLocal().isBefore(endExclusive),
      );
      activity.add(
        ReportActivityBin(
          start: start,
          end: DateTime(
            endExclusive.year,
            endExclusive.month,
            endExclusive.day - 1,
          ),
          workoutCount: inBin.length,
          volume: inBin.fold(0.0, (sum, item) => sum + item.volume),
        ),
      );
    }
    return PiFitReport(
      options: options,
      displayName: displayName,
      generatedAt: asOf,
      sessions: sessions,
      records: records,
      measurements: selectedMeasurements,
      activity: activity,
    );
  }

  Future<Uint8List> buildPdf(
    PiFitReport report, {
    required bool dark,
    ByteData? fontData,
  }) async {
    final data = fontData ?? await rootBundle.load('assets/fonts/Inter.ttf');
    final font = pw.Font.ttf(data);
    final background = PdfColor.fromHex(dark ? '#101B17' : '#F5F8F2');
    final foreground = PdfColor.fromHex(dark ? '#F4F8F1' : '#16251D');
    final muted = PdfColor.fromHex(dark ? '#B3C0B8' : '#607168');
    final card = PdfColor.fromHex(dark ? '#1C2B24' : '#FFFFFF');
    final accent = PdfColor.fromHex('#C7FF3D');
    final document = pw.Document(
      title: report.options.title.trim().isEmpty
          ? 'Pi Fit · Progress report'
          : report.options.title,
      author: 'Pi Fit',
      creator: 'Pi Fit',
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );
    pw.Widget label(String text) =>
        pw.Text(text, style: pw.TextStyle(color: muted, fontSize: 9));
    pw.Widget heading(String text, String subtitle) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 24, bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            text,
            style: pw.TextStyle(
              color: foreground,
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          label(subtitle),
        ],
      ),
    );
    pw.Widget table(List<String> headers, List<List<String>> rows) =>
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          cellStyle: pw.TextStyle(color: foreground, fontSize: 8),
          headerStyle: pw.TextStyle(
            color: foreground,
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
          headerDecoration: pw.BoxDecoration(color: card),
          border: null,
          cellPadding: const pw.EdgeInsets.all(8),
          oddRowDecoration: pw.BoxDecoration(color: card),
          cellAlignment: pw.Alignment.centerLeft,
        );
    document.addPage(
      pw.MultiPage(
        maxPages: 1000,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 34),
          buildBackground: (_) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: background),
          ),
        ),
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: accent,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'Pi Fit',
                  style: pw.TextStyle(
                    fontSize: 15,
                    color: PdfColor.fromHex('#192600'),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              label('PERSONAL REPORT'),
            ],
          ),
        ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              label('Pi Fit · ${_date(report.generatedAt)}'),
              label('${context.pageNumber} / ${context.pagesCount}'),
            ],
          ),
        ),
        build: (_) => [
          pw.Text(
            report.options.title.trim().isEmpty
                ? 'My progress'
                : report.options.title.trim(),
            style: pw.TextStyle(
              fontSize: 32,
              color: foreground,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            report.displayName,
            style: pw.TextStyle(fontSize: 13, color: foreground),
          ),
          pw.SizedBox(height: 6),
          label(
            '${_date(report.options.start)} — ${_date(report.options.end)} · both dates included',
          ),
          pw.SizedBox(height: 6),
          label(
            'Calendar dates in the device local time zone: ${report.generatedAt.timeZoneName}',
          ),
          if (report.options.sections.contains(ReportSection.summary)) ...[
            heading(
              'Your rhythm, in numbers.',
              'Only completed workouts with at least one valid checked set.',
            ),
            pw.Row(
              children: [
                _pdfMetric(
                  '${report.workoutCount}',
                  'WORKOUTS',
                  card,
                  foreground,
                  muted,
                ),
                pw.SizedBox(width: 9),
                _pdfMetric(
                  '${report.completedSets}',
                  'COMPLETED SETS',
                  card,
                  foreground,
                  muted,
                ),
                pw.SizedBox(width: 9),
                _pdfMetric(
                  _number(report.volume),
                  'KG EXTERNAL VOLUME',
                  card,
                  foreground,
                  muted,
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            label(
              '${report.activeDays} active days · ${_number(report.durationMinutes)} logged minutes, including rests',
            ),
            if (report.averageRpe != null)
              label(
                'Average RPE ${_number(report.averageRpe!)} / 10 · ${report.ratedSets} rated sets; unrated sets are excluded.',
              ),
            if (report.workoutCount > 0) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                'Workouts over time',
                style: pw.TextStyle(color: foreground, fontSize: 12),
              ),
              pw.SizedBox(height: 12),
              _pdfChart(report.activity, accent, muted),
            ],
            pw.SizedBox(height: 12),
            label(
              'External volume = kg × reps, for eligible strength sets only. Bodyweight, cardio and mobility are not converted into kg.',
            ),
            if (report.workoutCount == 0)
              label('No eligible workouts in this period.'),
          ],
          if (report.options.sections.contains(ReportSection.journal)) ...[
            heading(
              'Workout journal',
              '${report.workoutCount} sessions in this period. Dates use the session start day.',
            ),
            if (report.sessions.isEmpty)
              label('No completed sessions in this period.')
            else
              table(
                ['Date', 'Workout', 'Sets', 'Volume kg', 'Minutes', 'Avg RPE'],
                [
                  for (final item in report.sessions)
                    [
                      _date(item.session.startedAt.toLocal()),
                      item.session.routineName,
                      '${item.completedSets}',
                      _number(item.volume),
                      _number(
                        item.session.duration.inMilliseconds /
                            Duration.millisecondsPerMinute,
                      ),
                      item.averageRpe == null
                          ? '—'
                          : '${_number(item.averageRpe!)} (${item.ratedSets} ${item.ratedSets == 1 ? 'set' : 'sets'})',
                    ],
                ],
              ),
          ],
          if (report.options.sections.contains(ReportSection.records)) ...[
            heading('Best sets', 'Records from the selected period only.'),
            if (report.records.isEmpty)
              label('No weighted strength sets in this period.')
            else
              table(
                ['Exercise', 'Logged set', 'Estimated 1RM', 'Date'],
                [
                  for (final record in report.records)
                    [
                      record.exerciseName,
                      '${_number(record.weight)} kg × ${record.reps}',
                      record.estimatedOneRepMax == null
                          ? '—'
                          : '${_number(record.estimatedOneRepMax!)} kg',
                      _date(record.date),
                    ],
                ],
              ),
            pw.SizedBox(height: 9),
            label(
              '1RM: Epley estimate from sets of 1–12 reps. This is not a recommended weight.',
            ),
          ],
          if (report.options.sections.contains(
            ReportSection.bodyMeasurements,
          )) ...[
            heading(
              'Saved measurements',
              'Manual or explicitly imported entries. No direct access to Health data.',
            ),
            if (report.measurements.isEmpty)
              label('No saved measurements in this period.')
            else
              table(
                ['Date', 'Weight', 'Height', 'Source'],
                [
                  for (final measurement in report.measurements)
                    [
                      _date(measurement.measuredAt.toLocal()),
                      measurement.weightKg == null
                          ? '—'
                          : '${_number(measurement.weightKg!)} kg',
                      measurement.heightCm == null
                          ? '—'
                          : '${_number(measurement.heightCm!)} cm',
                      measurement.source == 'manual'
                          ? 'Manual'
                          : (measurement.sourceName ?? 'Health import'),
                    ],
                ],
              ),
          ],
        ],
      ),
    );
    return document.save();
  }
}

pw.Widget _pdfMetric(
  String value,
  String label,
  PdfColor card,
  PdfColor foreground,
  PdfColor muted,
) => pw.Expanded(
  child: pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: card,
      borderRadius: pw.BorderRadius.circular(12),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.FittedBox(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 25,
              color: foreground,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 7),
        pw.Text(label, style: pw.TextStyle(fontSize: 7, color: muted)),
      ],
    ),
  ),
);

pw.Widget _pdfChart(
  List<ReportActivityBin> bins,
  PdfColor accent,
  PdfColor muted,
) {
  final maximum = bins.fold<int>(
    1,
    (value, bin) => math.max(value, bin.workoutCount),
  );
  return pw.SizedBox(
    height: 112,
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        for (final bin in bins)
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    '${bin.workoutCount}',
                    style: pw.TextStyle(fontSize: 8, color: muted),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    height: math.max(2.0, 76 * bin.workoutCount / maximum),
                    decoration: pw.BoxDecoration(
                      color: bin.workoutCount == 0 ? muted : accent,
                      borderRadius: pw.BorderRadius.circular(
                        math.min(
                          4.0,
                          math.max(2.0, 76 * bin.workoutCount / maximum) / 2,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    '${bin.start.day}/${bin.start.month}',
                    style: pw.TextStyle(fontSize: 7, color: muted),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

String _number(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
String _fileDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
