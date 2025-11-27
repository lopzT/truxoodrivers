import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'dart:io' show Platform;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;
  static bool _hasPermission = false;

  static BuildContext? _context;
  static Function(String)? _onNotificationTappedCallback;
  
  // Notification channel IDs
  static const String _newRidesChannelId = 'new_rides';
  static const String _bookingUpdatesChannelId = 'booking_updates';
  static const String _driverStatusChannelId = 'driver_status';
  static const String _rideCompletedChannelId = 'ride_completed';
  
  // Notification IDs
  static const int _onlineStatusNotificationId = 999999;
  
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
      
      // Set local timezone
      final String timeZoneName = 'Asia/Kolkata'; // For India
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse: _backgroundNotificationResponse,
      );

      // Create notification channels for Android
      await _createNotificationChannels();

      _isInitialized = true;
      await _checkPermission();
      
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  // Handle background notification taps
  @pragma('vm:entry-point')
  static void _backgroundNotificationResponse(NotificationResponse response) {
    _onNotificationTapped(response);
  }

  static Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        // New Rides Channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _newRidesChannelId,
            'New Rides',
            description: 'Notifications for new ride requests',
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
            showBadge: true,
          ),
        );

        // Booking Updates Channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _bookingUpdatesChannelId,
            'Booking Updates',
            description: 'Notifications for booking status updates',
            importance: Importance.defaultImportance,
            enableVibration: true,
            playSound: true,
          ),
        );

        // Driver Status Channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _driverStatusChannelId,
            'Driver Status',
            description: 'Notifications for driver online/offline status',
            importance: Importance.low,
            enableVibration: false,
            playSound: false,
          ),
        );

        // Ride Completed Channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _rideCompletedChannelId,
            'Ride Completed',
            description: 'Notifications for completed rides',
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
            showBadge: true,
          ),
        );
      }
    }
  }

  static Future<bool> requestPermission() async {
    try {
      // For Android 13 (API 33) and above
      if (Platform.isAndroid) {
        final androidInfo = await Permission.notification.status;
        
        if (androidInfo.isGranted) {
          _hasPermission = true;
          return true;
        }

        if (androidInfo.isPermanentlyDenied) {
          // Guide user to settings
          if (_context != null) {
            final result = await showDialog<bool>(
              context: _context!,
              builder: (BuildContext context) => AlertDialog(
                title: const Text('Notification Permission Required'),
                content: const Text(
                  'Please enable notifications in app settings to receive ride alerts.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop(true);
                      await openAppSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            );
            return result ?? false;
          }
          return false;
        }

        final status = await Permission.notification.request();
        _hasPermission = status.isGranted;
        
        return _hasPermission;
      }
      
      // For other platforms, assume permission is granted
      _hasPermission = true;
      return true;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  static Future<void> _checkPermission() async {
    try {
      if (Platform.isAndroid) {
        _hasPermission = await Permission.notification.isGranted;
      } else {
        _hasPermission = true;
      }
    } catch (e) {
      debugPrint('Error checking notification permission: $e');
      _hasPermission = false;
    }
  }

  static int _generateNotificationId(String input) {
    return input.hashCode.abs() % 2147483647;
  }

  static Future<void> showNewRideNotification({
    required String bookingId,
    String? pickupLocation,
    String? dropLocation,
  }) async {
    if (!_hasPermission || !_isInitialized) {
      debugPrint('Cannot show notification: Permission: $_hasPermission, Initialized: $_isInitialized');
      return;
    }

    try {
      final String bigText = pickupLocation != null && dropLocation != null
          ? 'New ride request from $pickupLocation to $dropLocation. Tap to view details and accept.'
          : 'A new ride request is waiting for you. Tap to view details.';

      AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        _newRidesChannelId,
        'New Rides',
        channelDescription: 'Notifications for new ride requests',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        // Remove DrawableResourceAndroidBitmap if causing issues
        // largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          bigText,
          contentTitle: '🚗 New Ride Request!',
          summaryText: 'Tap to accept',
        ),
      );

      NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
      );

      await _notificationsPlugin.show(
        _generateNotificationId(bookingId),
        '🚗 New Ride Request!',
        'Tap to view ride details',
        notificationDetails,
        payload: 'new_ride:$bookingId',
      );
      
      debugPrint('New ride notification shown for booking: $bookingId');
    } catch (e) {
      debugPrint('Error showing new ride notification: $e');
    }
  }

  static Future<void> showBookingAcceptedNotification({
    String? clientName,
    String? destination,
  }) async {
    if (!_hasPermission || !_isInitialized) return;

    try {
      final String message = clientName != null 
          ? 'You accepted the ride request from $clientName'
          : 'You accepted the ride request';
          
      final String bigText = destination != null
          ? '$message\nDestination: $destination'
          : message;

      AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        _bookingUpdatesChannelId,
        'Booking Updates',
        channelDescription: 'Notifications for booking status updates',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(
          bigText,
          contentTitle: '✅ Booking Accepted',
        ),
      );

      NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
      );

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '✅ Booking Accepted',
        message,
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing accepted notification: $e');
    }
  }

  static Future<void> showOnlineStatusNotification({
    required bool isOnline,
  }) async {
    if (!_hasPermission || !_isInitialized) return;

    try {
      if (isOnline) {
        AndroidNotificationDetails androidNotificationDetails =
            AndroidNotificationDetails(
          _driverStatusChannelId,
          'Driver Status',
          channelDescription: 'Notifications for driver online/offline status',
          importance: Importance.low,
          priority: Priority.low,
          showWhen: false,
          ongoing: true,
          autoCancel: false,
          icon: '@mipmap/ic_launcher',
          onlyAlertOnce: true,
        );

        NotificationDetails notificationDetails = NotificationDetails(
          android: androidNotificationDetails,
        );

        await _notificationsPlugin.show(
          _onlineStatusNotificationId,
          '🟢 You are Online',
          'Ready to receive ride requests',
          notificationDetails,
        );
      } else {
        await _notificationsPlugin.cancel(_onlineStatusNotificationId);
      }
    } catch (e) {
      debugPrint('Error showing online status notification: $e');
    }
  }

  static Future<void> showRideCompletedNotification({
    required double amount,
    String? customerName,
  }) async {
    if (!_hasPermission || !_isInitialized) return;

    try {
      final String message = customerName != null
          ? 'Ride with $customerName completed'
          : 'Ride completed successfully';

      AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        _rideCompletedChannelId,
        'Ride Completed',
        channelDescription: 'Notifications for completed rides',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(
          '$message\n\nYou earned ₹${amount.toStringAsFixed(2)}',
          contentTitle: '🎉 Ride Completed!',
          summaryText: '₹${amount.toStringAsFixed(2)} earned',
        ),
      );

      NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
      );

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '🎉 Ride Completed!',
        'You earned ₹${amount.toStringAsFixed(2)}',
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing ride completed notification: $e');
    }
  }

  // Schedule a notification
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_hasPermission || !_isInitialized) return;

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'scheduled_notifications',
            'Scheduled Notifications',
            channelDescription: 'Scheduled notifications',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  static Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      debugPrint('All notifications cancelled');
    } catch (e) {
      debugPrint('Error cancelling notifications: $e');
    }
  }

  static Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      debugPrint('Notification $id cancelled');
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('Notification tapped with payload: $payload');
    
    if (payload != null) {
      if (payload.startsWith('new_ride:')) {
        final bookingId = payload.substring('new_ride:'.length);
        debugPrint('Notification tapped for ride: $bookingId');

        // Navigate to home with the booking information
        if (_context != null) {
          Navigator.of(_context!).pushNamedAndRemoveUntil(
            '/home', // Update with your home route
            (route) => false,
            arguments: {'bookingId': bookingId, 'fromNotification': true},
          );
        }
        
        // Call the callback if set
        _onNotificationTappedCallback?.call(bookingId);
      }
    }
  }

  // Check if app was launched from notification
  static Future<NotificationAppLaunchDetails?> getAppLaunchDetails() async {
    try {
      return await _notificationsPlugin.getNotificationAppLaunchDetails();
    } catch (e) {
      debugPrint('Error getting app launch details: $e');
      return null;
    }
  }
}