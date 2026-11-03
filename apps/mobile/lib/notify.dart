// Android local notification: info when a job finishes while app is in background.
// Tapping an article notification opens it via callback [onNotifTap] (payload = URL).
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _notif = FlutterLocalNotificationsPlugin();
bool _ready = false;

/// Installed by the UI (has MethodChannel `openUrl` access); null = no tap action.
Future<void> Function(String? payload)? onNotifTap;

Future<void> initNotif() async {
  if (_ready) return;
  await _notif.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveNotificationResponse: (r) => onNotifTap?.call(r.payload),
  );
  await _notif
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  _ready = true;
}

/// shortcut: no-op before init / without a message — callers skip state checks.
Future<void> notifyJob(String title, String body, {String? payload}) async {
  if (!_ready || body.isEmpty) return;
  const details = AndroidNotificationDetails(
    'saba_jobs',
    'SABA jobs',
    importance: Importance.max,
    priority: Priority.high,
  );
  await _notif.show(
    id: title.hashCode,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(android: details),
    payload: payload,
  );
}
