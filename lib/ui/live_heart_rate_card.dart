import 'dart:async';

import 'package:flutter/material.dart';

import '../services/live_heart_rate_service.dart';
import '../state/app_store.dart';
import 'theme.dart';

final _sharedWatchConnection = LiveHeartRateService();

class LiveHeartRateCard extends StatefulWidget {
  const LiveHeartRateCard({super.key, required this.store, this.service});
  final AppStore store;
  final LiveHeartRateService? service;
  @override
  State<LiveHeartRateCard> createState() => _LiveHeartRateCardState();
}

class _LiveHeartRateCardState extends State<LiveHeartRateCard> {
  late final LiveHeartRateService _service;
  String? _accountId, _sessionId;
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? _sharedWatchConnection;
    _accountId = widget.store.accountId;
    _sessionId = widget.store.activeSession?.id;
    widget.store.addListener(_scopeChanged);
    _service.addListener(_updated);
    unawaited(_service.initialize());
  }

  void _updated() {
    if (mounted) setState(() {});
  }

  void _scopeChanged() {
    final session = widget.store.activeSession?.id;
    if (_accountId != widget.store.accountId ||
        (_sessionId != null && session != _sessionId)) {
      _accountId = widget.store.accountId;
      _sessionId = session;
      unawaited(_service.resetForAccountChange());
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_scopeChanged);
    _service.removeListener(_updated);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sample = _service.sample;
    final fresh = _service.isFresh;
    if (!_service.supported) {
      return PiCard(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Icon(
              Icons.watch_outlined,
              color: PiColors.muted(context),
              size: 21,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Live Apple Watch heart rate is available in the iPhone app.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    return PiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite_rounded,
                color: fresh
                    ? const Color(0xFFFF7C88)
                    : PiColors.muted(context),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Apple Watch',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: (fresh ? PiColors.lime : PiColors.muted(context))
                      .withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  fresh ? 'LIVE' : _status(_service.status),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: fresh
                        ? Theme.of(context).colorScheme.primary
                        : PiColors.muted(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                sample?.bpm.round().toString() ?? '—',
                key: const Key('live-heart-rate'),
                style: Theme.of(
                  context,
                ).textTheme.headlineLarge?.copyWith(fontSize: 43),
              ),
              const SizedBox(width: 8),
              Text('bpm', style: TextStyle(color: PiColors.muted(context))),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            sample == null
                ? _service.message ??
                      'Start a watch session to receive live heart rate.'
                : '${sample.source} · ${formatTime(sample.measuredAt.toLocal())} · ${_age(sample.ageAt(DateTime.now()))}',
            style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
          ),
          if (!fresh && sample != null)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                'Last received reading. Waiting for a fresh watch connection.',
                style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
              ),
            ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!_service.workoutRunning)
                FilledButton.icon(
                  onPressed: _service.status == LiveHeartRateStatus.starting
                      ? null
                      : _service.startWatchWorkout,
                  icon: const Icon(Icons.watch_outlined),
                  label: Text(
                    _service.status == LiveHeartRateStatus.starting
                        ? 'Starting on watch…'
                        : 'Start watch heart rate',
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _service.stopWatchWorkout,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop watch session'),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            'Requires Pi Fit installed on your paired Apple Watch and heart-rate/workout permission on the watch. Start when you are ready to train.',
            style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
          ),
        ],
      ),
    );
  }
}

String _age(Duration age) => age.inSeconds < 60
    ? '${age.inSeconds.clamp(0, 59)}s ago'
    : '${age.inMinutes}m ago';
String _status(LiveHeartRateStatus status) => switch (status) {
  LiveHeartRateStatus.streaming => 'CONNECTING',
  LiveHeartRateStatus.starting => 'STARTING',
  LiveHeartRateStatus.stale => 'LAST READING',
  LiveHeartRateStatus.disconnected => 'DISCONNECTED',
  LiveHeartRateStatus.notPaired => 'PAIR WATCH',
  LiveHeartRateStatus.notInstalled => 'INSTALL ON WATCH',
  LiveHeartRateStatus.checking => 'CHECKING',
  LiveHeartRateStatus.error => 'UNAVAILABLE',
  _ => 'READY',
};

/// Owns the shared watch connection's account/session boundary for the app,
/// including when the Health or workout screens are no longer visible.
class PiWatchScope extends StatefulWidget {
  const PiWatchScope({super.key, required this.store, required this.child});
  final AppStore store;
  final Widget child;
  @override
  State<PiWatchScope> createState() => _PiWatchScopeState();
}

class _PiWatchScopeState extends State<PiWatchScope> {
  String? _accountId, _workoutId;
  @override
  void initState() {
    super.initState();
    _accountId = widget.store.accountId;
    _workoutId = widget.store.activeSession?.id;
    widget.store.addListener(_changed);
  }

  void _changed() {
    final account = widget.store.accountId,
        workout = widget.store.activeSession?.id;
    final ended = _workoutId != null && workout != _workoutId;
    if (account != _accountId || ended) {
      unawaited(_sharedWatchConnection.resetForAccountChange());
    }
    _accountId = account;
    _workoutId = workout;
  }

  @override
  void dispose() {
    widget.store.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A compact persistent readout while the detailed controls are collapsed.
class LiveHeartRateReadout extends StatefulWidget {
  const LiveHeartRateReadout({super.key});
  @override
  State<LiveHeartRateReadout> createState() => _LiveHeartRateReadoutState();
}

class _LiveHeartRateReadoutState extends State<LiveHeartRateReadout> {
  @override
  void initState() {
    super.initState();
    _sharedWatchConnection.addListener(_changed);
    unawaited(_sharedWatchConnection.initialize());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sharedWatchConnection.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sample = _sharedWatchConnection.sample;
    if (sample == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        children: [
          const Icon(
            Icons.favorite_rounded,
            size: 16,
            color: Color(0xFFFF7C88),
          ),
          const SizedBox(width: 7),
          Text(
            '${sample.bpm.round()} bpm',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _sharedWatchConnection.isFresh
                  ? 'Apple Watch · LIVE'
                  : 'Last reading · ${_age(sample.ageAt(DateTime.now()))}',
              style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
            ),
          ),
        ],
      ),
    );
  }
}
