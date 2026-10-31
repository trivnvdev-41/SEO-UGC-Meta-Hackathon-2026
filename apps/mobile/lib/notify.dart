// Local notification Android: info saat job selesai selagi app di background.
// Tap notifikasi artikel → dibuka via callback [onNotifTap] (payload = URL).
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _notif = FlutterLocalNotificationsPlugin();
bool _ready = false;

/// Dipasang oleh UI (punya akses MethodChannel `openUrl`); null = tanpa aksi tap.
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

/// shortcut: no-op sebelum init / tanpa pesan — pemanggil tak perlu cek state.
Future<void> notifyJob(String title, String body, {String? payload}) async {
  if (!_ready || body.isEmpty) return;
  const details = AndroidNotificationDetails(
    'seougc_jobs',
    'SEO UGC jobs',
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
