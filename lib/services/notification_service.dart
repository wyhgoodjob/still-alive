import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

/// Service for handling local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  
  // Notification IDs
  static const int reminderNotificationId = 1;
  static const int warningNotificationId = 2;
  static const int overdueNotificationId = 3;
  
  // Channel IDs
  static const String channelId = 'still_alive_reminders';
  static const String channelName = 'Check-in Reminders';
  static const String channelDescription = 'Notifications to remind you to check in';
  
  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;
    
    // Initialize timezone
    tz.initializeTimeZones();
    
    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    // Initialize
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Create notification channel for Android
    await _createNotificationChannel();
    
    _initialized = true;
  }
  
  /// Create Android notification channel
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
  
  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - could navigate to home screen
    debugPrint('Notification tapped: ${response.payload}');
  }
  
  /// Request notification permissions
  Future<bool> requestPermissions() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
  
  /// Check if notifications are permitted
  Future<bool> areNotificationsEnabled() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }
  
  /// Schedule a reminder notification
  Future<void> scheduleReminderNotification({
    required DateTime scheduledTime,
    required String title,
    required String body,
    int id = reminderNotificationId,
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) return;
    
    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
    
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzScheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
  
  /// Schedule check-in reminder notifications based on deadline
  Future<void> scheduleCheckInReminders({
    required DateTime deadline,
    required int intervalHours,
  }) async {
    // Cancel existing reminders first
    await cancelAllReminders();
    
    final now = DateTime.now();
    
    // Calculate reminder times
    // Reminder 1: At 75% of interval (gentle reminder)
    final reminder75 = deadline.subtract(Duration(hours: (intervalHours * 0.25).round()));
    if (reminder75.isAfter(now)) {
      await scheduleReminderNotification(
        id: reminderNotificationId,
        scheduledTime: reminder75,
        title: '⏰ Check-in Reminder',
        body: 'Remember to check in! You have ${(intervalHours * 0.25).round()} hours left.',
      );
    }
    
    // Reminder 2: At 90% of interval (warning)
    final reminder90 = deadline.subtract(Duration(hours: (intervalHours * 0.10).round()));
    if (reminder90.isAfter(now)) {
      await scheduleReminderNotification(
        id: warningNotificationId,
        scheduledTime: reminder90,
        title: '⚠️ Urgent: Check-in Soon!',
        body: 'Only ${(intervalHours * 0.10).round()} hours until your emergency contacts are notified!',
      );
    }
    
    // Reminder 3: At deadline (overdue)
    if (deadline.isAfter(now)) {
      await scheduleReminderNotification(
        id: overdueNotificationId,
        scheduledTime: deadline,
        title: '🚨 Check-in Overdue!',
        body: 'Your emergency contacts will be notified. Open the app to check in now!',
      );
    }
  }
  
  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
  
  /// Cancel all reminder notifications
  Future<void> cancelAllReminders() async {
    await _notifications.cancel(reminderNotificationId);
    await _notifications.cancel(warningNotificationId);
    await _notifications.cancel(overdueNotificationId);
  }
  
  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
  
  /// Show an immediate notification (for testing)
  Future<void> showTestNotification() async {
    await _notifications.show(
      99,
      '✅ Notifications Working',
      'Still Alive notifications are set up correctly!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
