import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/api_service.dart';
import 'services/alert_service.dart';
import 'screens/monitoring_screen.dart';
import 'dart:typed_data';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  if (message.data['action'] == 'stop_alert') {
    await flutterLocalNotificationsPlugin.cancelAll();
    await AlertService.stopAlert();
    return;
  }
  
  if (message.data['action'] != 'trigger_alert') {
    return; // Only handle our specific alerts
  }
  
  // Initialize local notifications (required for background isolates)
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

  // Show a notification with custom beep sound and FLAG_INSISTENT
  final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'ricemill_alerts', // channel id
    'Ricemill Alerts', // channel name
    importance: Importance.max,
    priority: Priority.high,
    sound: const RawResourceAndroidNotificationSound('beep'), // be sure to add res/raw/beep.mp3
    additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT for looping sound
  );
  final NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(
    id: message.messageId?.hashCode ?? 0,
    title: message.data['title'] ?? 'Alert',
    body: message.data['body'] ?? 'Limit Exceeded',
    notificationDetails: platformChannelSpecifics,
  );
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Permission.notification.request();
  const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
    );

await flutterLocalNotificationsPlugin.initialize(
  settings:initializationSettings,
);

const AndroidNotificationChannel channel =
    AndroidNotificationChannel(
      'ricemill_alerts',
      'Ricemill Alerts',
      description: 'Critical alert notifications',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('beep'),
    );

await flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(channel);
  // Setup FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    if (message.data['action'] == 'stop_alert') {
      flutterLocalNotificationsPlugin.cancelAll();
      AlertService.stopAlert();
    } else if (message.data['action'] == 'trigger_alert') {
      // In foreground, we also want the notification to pop up so the user can see it if they are on another screen
      final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'ricemill_alerts', // channel id
        'Ricemill Alerts', // channel name
        importance: Importance.max,
        priority: Priority.high,
        sound: const RawResourceAndroidNotificationSound('beep'), // be sure to add res/raw/beep.mp3
        additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT for looping sound
      );
      final NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
      await flutterLocalNotificationsPlugin.show(
        id: message.messageId?.hashCode ?? 0,
        title: message.data['title'] ?? 'Alert',
        body: message.data['body'] ?? 'Limit Exceeded',
        notificationDetails: platformChannelSpecifics,
      );
    }
  });

  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    print("FCM Token: $token");
    // Register token with backend for global user
    ApiService.registerFcmToken('global_user', token);
  }
  
  // Keep background service for other background tasks if needed, 
  // but FCM handles the actual notifications now.
  runApp(const RiceMillApp());
}

class RiceMillApp extends StatelessWidget {
  const RiceMillApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vishnu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF28a745)),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const MonitoringScreen(),
    );
  }
}
