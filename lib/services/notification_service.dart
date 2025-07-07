import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;
  static bool _hasPermission = false;

  static BuildContext? _context;
  static Function(String)? _onNotificationTappedCallback;
  
  static bool get hasPermission => _hasPermission;
  static bool get isInitialized => _isInitialized;

  static void setContext(BuildContext context) {
    _context = context;
  }

  static void setNotificationTappedCallback(Function(String) callback) {
    _onNotificationTappedCallback = callback;
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz_data.initializeTimeZones();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      await _checkPermission();
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  static Future<bool> requestPermission() async {
    try {
      if (await Permission.notification.isGranted) {
        _hasPermission = true;
        return true;
      }

      final status = await Permission.notification.request();
      _hasPermission = status.isGranted;
      
      return _hasPermission;
    } catch (e) {
      print('Error requesting notification permission: $e');
      return false;
    }
  }

  static Future<void> _checkPermission() async {
    try {
      _hasPermission = await Permission.notification.isGranted;
    } catch (e) {
      print('Error notification permission: $e');
      _hasPermission = false;
    }
  }

  static int _generateNotificationId(String input) {
    return input.hashCode.abs() % 2147483647;
  }

  static Future<void> showNewRideNotification({
    required String bookingId,
  }) async {
    if (!_hasPermission) {
      return;
    }

    try {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'new_rides',
        'New Rides',
        channelDescription: 'Notifications for new ride requests',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        color: Color(0xFF2196F3),
        styleInformation: BigTextStyleInformation(
          'A new ride request is waiting for you. Tap to view details.',
          contentTitle: '🚗 You have a new ride!',
          summaryText: 'Tap to open app',
        ),
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
      );

      await _notificationsPlugin.show(
        _generateNotificationId(bookingId),
        '🚗 You have a new ride!',
        'Tap to view ride details',
        notificationDetails,
        payload: 'new_ride:$bookingId',
      );
    } catch (e) {
      print('Error showing new ride notification: $e');
    }
  }

  static Future<void> showBookingAcceptedNotification({
    String? clientName,
  }) async {
    if (!_hasPermission) return;

    try {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'booking_updates',
        'Booking Updates',
        channelDescription: 'Notifications for booking status updates',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF4CAF50),
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
      );

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '✅ Booking Accepted',
        'You accepted the ride request',
        notificationDetails,
      );
    } catch (e) {
      print('Error showing accepted notification: $e');
    }
  }

  static Future<void> showOnlineStatusNotification({
    required bool isOnline,
  }) async {
    if (!_hasPermission) return;

    try {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'driver_status',
        'Driver Status',
        channelDescription: 'Notifications for driver online/offline status',
        importance: Importance.low,
        priority: Priority.low,
        showWhen: true,
        ongoing: true,
        autoCancel: false,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF2196F3),
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
      );

      if (isOnline) {
        await _notificationsPlugin.show(
          999999,
          '🟢 You are Online',
          'Ready to receive ride requests',
          notificationDetails,
        );
      } else {
        await _notificationsPlugin.cancel(999999);
      }
    } catch (e) {
      print('Error showing online status notification: $e');
    }
  }

  static Future<void> showRideCompletedNotification({
    required double amount,
  }) async {
    if (!_hasPermission) return;

    try {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'ride_completed',
        'Ride Completed',
        channelDescription: 'Notifications for completed rides',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF4CAF50),
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
      );

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '🎉 Ride Completed',
        'You earned ₹${amount.toStringAsFixed(2)}',
        notificationDetails,
      );
    } catch (e) {
      print('Error showing ride completed notification: $e');
    }
  }

  static Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      print('Error cancelling notifications: $e');
    }
  }

  static Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e) {
      print('Error cancelling notification: $e');
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    
    if (payload != null && payload.startsWith('new_ride:')) {
      final bookingId = payload.substring('new_ride:'.length);
      print('Notification tapped for ride: $bookingId');

      if (_context != null) {
        Navigator.of(_context!).pushNamedAndRemoveUntil(
          '/', //home route ta padiba
          (route) => false,
        );
      }
      
      if (_onNotificationTappedCallback != null) {
        _onNotificationTappedCallback!(bookingId);
      }
    }
  }
}
//ready