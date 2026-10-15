import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? lastError;

  bool get supported =>
      !kIsWeb &&
      _initialized &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      timezone_data.initializeTimeZones();
      final deviceZone = await FlutterTimezone.getLocalTimezone();
      timezone.setLocalLocation(timezone.getLocation(deviceZone.identifier));
      final result = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _initialized = result != false;
      if (!_initialized) {
        lastError = 'Notificările nu au putut fi inițializate.';
      }
    } on MissingPluginException {
      lastError =
          'Notificările necesită o aplicație Android sau iOS instalată.';
    } on PlatformException catch (error) {
      lastError = 'Inițializarea notificărilor a eșuat: ${error.code}.';
    } on ArgumentError {
      lastError = 'Fusul orar al dispozitivului nu este recunoscut.';
    } on Exception {
      lastError =
          'Notificările nu au putut fi inițializate pe acest dispozitiv.';
    }
  }

  Future<void> schedule(String id, DateTime date, String title) async {
    if (!_initialized) await initialize();
    if (!supported) {
      throw UnsupportedError(
        lastError ??
            'Reminderele sunt disponibile în aplicația Android și iOS.',
      );
    }
    if (!date.isAfter(DateTime.now())) {
      throw ArgumentError(
        'Reminderul trebuie programat pentru o dată viitoare.',
      );
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final allowed = defaultTargetPlatform == TargetPlatform.android
        ? await android?.requestNotificationsPermission()
        : await ios?.requestPermissions(alert: true, badge: true, sound: true);
    if (allowed == false) {
      throw StateError(
        'Activează notificările pentru Pi Fit în setările telefonului.',
      );
    }
    final notificationId = stableId(id);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final pending = await _plugin.pendingNotificationRequests();
      if (pending.length >= 60 &&
          !pending.any((notification) => notification.id == notificationId)) {
        throw StateError(
          'iOS permite un număr limitat de remindere. '
          'Programează cel mult 60 de sesiuni cu reminder în același timp.',
        );
      }
    }
    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'E timpul pentru $title',
      body: 'Antrenamentul tău te așteaptă. Hai să facem progres! ⚡',
      scheduledDate: timezone.TZDateTime.from(date, timezone.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'pi_fit_workouts',
          'Antrenamente programate',
          channelDescription: 'Remindere pentru antrenamentele tale Pi Fit',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Avoids exact-alarm permission; Android may defer this in power saving.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: id,
    );
  }

  Future<void> cancel(String id) async {
    if (!supported) return;
    await _plugin.cancel(id: stableId(id));
  }

  /// Stable across app launches; Dart's String.hashCode is not guaranteed stable.
  @visibleForTesting
  static int stableId(String id) {
    var hash = 0x811c9dc5;
    for (final unit in id.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
