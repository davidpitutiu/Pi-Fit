import 'package:flutter/material.dart';

import '../services/firebase_gateway.dart';
import '../services/notification_service.dart';
import '../state/app_store.dart';
import 'theme.dart';

/// This preference belongs to one local account and is off until the user
/// explicitly enables it. OS permission is requested only from this control.
class WorkoutShortcutsCard extends StatefulWidget {
  const WorkoutShortcutsCard({
    super.key,
    required this.store,
    this.notifications,
  });
  final AppStore store;
  final NotificationService? notifications;
  @override
  State<WorkoutShortcutsCard> createState() => _WorkoutShortcutsCardState();
}

class _WorkoutShortcutsCardState extends State<WorkoutShortcutsCard> {
  NotificationService get _service =>
      widget.notifications ?? NotificationService.instance;
  bool _busy = false;
  String? _error;
  Future<void> _setEnabled(bool enabled) async {
    final scope = widget.store.accountId;
    final key = NotificationService.workoutPreferenceKey(scope);
    setState(() => _busy = true);
    try {
      if (enabled) await _service.requestWorkoutPermission();
      if (!mounted ||
          widget.store.accountId != scope ||
          FirebaseGateway.instance.currentUser?.uid != scope) {
        return;
      }
      if (!await widget.store.preferences.setBool(key, enabled)) {
        throw StateError('The notification preference could not be saved.');
      }
      _service.reportWorkoutError(null);
      _service.workoutPreferencesChanged();
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Unsupported operation: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.store, _service]),
    builder: (context, _) {
      final enabled =
          widget.store.preferences.getBool(
            NotificationService.workoutPreferenceKey(widget.store.accountId),
          ) ??
          false;
      return PiCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Workout shortcuts',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Switch.adaptive(
                  value: enabled,
                  onChanged: _busy || !_service.mobilePlatform
                      ? null
                      : _setEnabled,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _service.mobilePlatform
                  ? 'Keep your workout and rest timer in notifications. “Check set” completes only the next unchecked set; “Skip rest” uses the same timer as this screen. Actions open Pi Fit.'
                  : 'Workout notifications are available in the installed Android and iPhone apps.',
              style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
            ),
            if (_service.mobilePlatform) ...[
              const SizedBox(height: 7),
              Text(
                'Android shows a system timer. iPhone shows the rest deadline. This device preference is separate for each account.',
                style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
              ),
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if ((_error ?? _service.workoutError) != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error ?? _service.workoutError!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
