import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Android 13+ 알림 권한 요청
    if (!kIsWeb) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  // 급여 알림 — reptileName 급여일이에요 (오전 9시)
  Future<void> scheduleFeeedingNotification(
    String reptileId,
    String reptileName,
    DateTime scheduledDate,
  ) async {
    if (kIsWeb) return;
    final tzDate = _toTZ(scheduledDate);
    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      _id('f_$reptileId'),
      '급여 알림',
      '$reptileName 급여일이에요',
      tzDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'feeding_channel',
          '급여 알림',
          channelDescription: '급여 예정일 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // 해칭 알림 — D-3일 오전 9시
  Future<void> scheduleHatchingNotification(
    String clutchId,
    String femaleName,
    DateTime expectedDate,
  ) async {
    if (kIsWeb) return;
    final notifyDate = expectedDate.subtract(const Duration(days: 3));
    final tzDate = _toTZ(notifyDate);
    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      _id('h_$clutchId'),
      '해칭 알림',
      '$femaleName 클러치 해칭 3일 전이에요',
      tzDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'hatching_channel',
          '해칭 알림',
          channelDescription: '해칭 예정일 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  tz.TZDateTime _toTZ(DateTime date) => tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        9, // 오전 9시
      );

  int _id(String key) => key.hashCode.abs() & 0x7FFFFFFF;
}
