import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel foregroundChannel = AndroidNotificationChannel(
    'foreground_channel', // id
    'Foreground Service', // title
    description: 'Used for the persistent background monitoring.', // description
    importance: Importance.low, // Low importance so it doesn't ping on start
  );

  const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
    'alert_channel', // id
    'Emergency Alerts', // title
    description: 'Used for critical CMD limit alerts.', // description
    importance: Importance.high, // High importance for heads-up banner
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(foregroundChannel);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(alertChannel);

  await flutterLocalNotificationsPlugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'foreground_channel',
      initialNotificationTitle: 'Energy Monitoring',
      initialNotificationContent: 'Monitoring energy load in background',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  service.startService();

}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Use the globally initialized plugin
  // final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool hasNotified = false;
  double cmdLimit = 800.0;

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    try {
      final data = await ApiService.fetchSensorData();
      if (data != null) {
        double sumKva = 0;
        final mainMeterSuffixes = ['6', '108', '201'];
        for (var suffix in mainMeterSuffixes) {
          sumKva += double.tryParse(data['Total_KVA_meter_$suffix']?.toString() ?? '0') ?? 0;
        }

        if (sumKva > cmdLimit) {
          if (!hasNotified) {
            hasNotified = true;
            await flutterLocalNotificationsPlugin.show(
        id: 999,
        title: 'KVA Limit Exceeded!',
        body: 'Live kVA (${sumKva.toStringAsFixed(2)}) is over limit (${cmdLimit}).',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'alert_channel',
            'Emergency Alerts',
            icon: '@mipmap/ic_launcher',
            color: Color(0xFFEF5350), // Red
            colorized: true,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
          }
        } else {
          hasNotified = false;
        }
      }
    } catch (e) {
      // Background error
    }
  });
}
