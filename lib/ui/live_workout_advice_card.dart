import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/coach_service.dart';
import '../services/firebase_gateway.dart';
import '../services/live_workout_advice.dart';
import '../services/workout_clock.dart';
import '../state/app_store.dart';
import 'theme.dart';

class LiveWorkoutAdviceCard extends StatefulWidget {
  const LiveWorkoutAdviceCard({
    super.key,
    required this.store,
    this.service,
    this.exerciseIndex,
  });
  final AppStore store;
  final CoachService? service;
  final int? exerciseIndex;
  @override
  State<LiveWorkoutAdviceCard> createState() => _LiveWorkoutAdviceCardState();
}

class _LiveWorkoutAdviceCardState extends State<LiveWorkoutAdviceCard> {
  late final CoachService _coach;
  Timer? _debounce;
  String? _signature, _onlineText, _onlineIssue;
  DateTime? _lastRequest;
  bool _onlineEnabled = false, _requesting = false;
  int _generation = 0;
  List<String> _previousExercises = const [];
  int? _focusedExerciseIndex;
  String? _sessionId;
  String? _accountId;
  bool _scopeKnown = false;
  @override
  void initState() {
    super.initState();
    _coach = widget.service ?? CoachService();
    widget.store.addListener(_changed);
    _changed();
  }

  bool get _canUseOnline =>
      _coach.remoteConfigured &&
      widget.store.profile.coachConsent &&
      FirebaseGateway.instance.currentUser?.uid == widget.store.accountId &&
      widget.store.accountId != null;
  void _changed() {
    if (_scopeKnown && _accountId != widget.store.accountId) {
      _onlineEnabled = false;
      _lastRequest = null;
      _requesting = false;
    }
    _scopeKnown = true;
    _accountId = widget.store.accountId;
    final active = widget.store.activeSession;
    final exercises =
        active?.exercises.map((e) => jsonEncode(e.toJson())).toList() ??
        <String>[];
    if (_sessionId != active?.id) {
      _focusedExerciseIndex = null;
      _previousExercises = const [];
      _sessionId = active?.id;
    }
    for (var i = 0; i < exercises.length; i++) {
      if (i < _previousExercises.length &&
          exercises[i] != _previousExercises[i]) {
        _focusedExerciseIndex = i;
      }
    }
    _previousExercises = exercises;
    final signature = jsonEncode({
      'account': widget.store.accountId,
      'session': widget.store.activeSession?.toJson(),
      'profile': widget.store.profile.toJson(),
      'goal': widget.store.goal,
    });
    if (signature == _signature) return;
    _signature = signature;
    _generation++;
    _onlineText = null;
    _onlineIssue = null;
    _debounce?.cancel();
    if (mounted) setState(() {});
    if (_onlineEnabled && _canUseOnline && widget.store.activeSession != null) {
      final elapsed = _lastRequest == null
          ? 15000
          : DateTime.now().difference(_lastRequest!).inMilliseconds;
      _debounce = Timer(
        Duration(milliseconds: elapsed >= 15000 ? 900 : 15000 - elapsed),
        _requestAdvice,
      );
    }
  }

  Future<void> _requestAdvice() async {
    if (!_canUseOnline ||
        !_onlineEnabled ||
        widget.store.activeSession == null) {
      return;
    }
    final generation = _generation;
    _lastRequest = DateTime.now();
    setState(() {
      _requesting = true;
      _onlineIssue = null;
    });
    try {
      final result = await _coach.reply(
        'Give one concise suggestion for my next workout set. Focus on currentExerciseId and currentExercise, its user-reported effort (RPE 1–10), and comparable previous sessions. Do not change any data. Do not invent heart rate or prescribe a maximal load.',
        context: _focusedContext(),
        localContext: widget.store.localCoachContext,
        allowRemote: true,
      );
      if (mounted && generation == _generation && _onlineEnabled) {
        setState(() => _onlineText = result);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _onlineIssue =
              'Online feedback is unavailable. Your on-device guidance is still up to date.',
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  String _focusedContext() {
    final data = Map<String, dynamic>.from(
      jsonDecode(widget.store.coachContext) as Map,
    );
    final active = widget.store.activeSession;
    if (active != null) {
      final advice = workoutAdvice(
        session: active,
        catalog: widget.store.exercises,
        history: widget.store.history,
        focusedExerciseIndex: widget.exerciseIndex ?? _focusedExerciseIndex,
      );
      if (advice != null) {
        final exercise = active.exercises[advice.exerciseIndex];
        data['currentExerciseId'] = exercise.exerciseId;
        data['currentExercise'] = {
          'name': widget.store.exerciseById(exercise.exerciseId).name,
          'exerciseId': exercise.exerciseId,
          'sets': exercise.sets
              .skip(exercise.sets.length > 8 ? exercise.sets.length - 8 : 0)
              .map((s) => s.toJson())
              .toList(),
        };
      }
    }
    while (jsonEncode(data).length > 23000 &&
        (data['recentSessions'] as List? ?? []).isNotEmpty) {
      (data['recentSessions'] as List).removeLast();
    }
    return jsonEncode(data);
  }

  Future<void> _applyLoad(
    WorkoutAdvice advice,
    String sessionId,
    String? accountId,
  ) async {
    final active = widget.store.activeSession;
    if (active == null ||
        active.id != sessionId ||
        widget.store.accountId != accountId ||
        advice.nextSetIndex == null ||
        advice.suggestedWeight == null) {
      return;
    }
    final item = active.exercises.elementAtOrNull(advice.exerciseIndex);
    if (item?.exerciseId != advice.exerciseId ||
        item!.sets.elementAtOrNull(advice.nextSetIndex!)?.completed != false) {
      return;
    }
    try {
      await widget.store.updateSet(
        advice.exerciseIndex,
        advice.nextSetIndex!,
        weight: advice.suggestedWeight,
      );
      if (mounted && widget.store.accountId == accountId) {
        toast(
          context,
          'Next-set load updated. Your completed sets are unchanged.',
        );
      }
    } catch (_) {
      if (mounted) toast(context, 'The change could not be saved. Try again.');
    }
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    widget.store.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.store.activeSession;
    if (active == null) return const SizedBox.shrink();
    final advice = workoutAdvice(
      session: active,
      catalog: widget.store.exercises,
      history: widget.store.history,
      focusedExerciseIndex: widget.exerciseIndex ?? _focusedExerciseIndex,
    );
    if (advice == null) return const SizedBox.shrink();
    final account = widget.store.accountId;
    return PiCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Live coach',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'ON DEVICE',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1,
                  color: PiColors.muted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            widget.store.exerciseById(advice.exerciseId).name,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            advice.title,
            key: const Key('live-advice-title'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 5),
          Text(
            advice.text,
            key: const Key('live-advice-text'),
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: PiColors.muted(context),
            ),
          ),
          if (advice.restSeconds != null || advice.suggestedWeight != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 3,
              children: [
                if (advice.restSeconds case final seconds?)
                  TextButton.icon(
                    onPressed: () {
                      WorkoutClock.instance.selectRestSeconds(seconds);
                      WorkoutClock.instance.startRest();
                    },
                    icon: const Icon(Icons.timer_outlined, size: 16),
                    label: Text('Rest ${seconds}s'),
                  ),
                if (advice.suggestedWeight case final weight?)
                  TextButton.icon(
                    key: const Key('apply-live-load'),
                    onPressed: () => _applyLoad(advice, active.id, account),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: Text('Next set: $weight kg'),
                  ),
              ],
            ),
          ],
          if (_canUseOnline)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Online feedback',
                style: TextStyle(fontSize: 12),
              ),
              subtitle: const Text(
                'Updates after set or effort changes',
                style: TextStyle(fontSize: 10),
              ),
              value: _onlineEnabled,
              onChanged: (enabled) {
                setState(() => _onlineEnabled = enabled);
                _generation++;
                _debounce?.cancel();
                _onlineText = null;
                if (enabled) _requestAdvice();
              },
            ),
          if (_requesting)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (_onlineText != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _onlineText!,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          if (_onlineIssue != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _onlineIssue!,
                style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
              ),
            ),
        ],
      ),
    );
  }
}
