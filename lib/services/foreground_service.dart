import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:audioplayers/audioplayers.dart';

class ForegroundService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'ricemill_alerts_v2',
        initialNotificationTitle: '⚠️ Alert Active',
        initialNotificationContent: 'Monitoring system running',
      ),
      iosConfiguration: IosConfiguration(),
    );
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  final player = AudioPlayer();
  bool isRunning = false;

  service.on('start_siren').listen((event) async {
    isRunning = true;

    // Set loop mode ONCE
    await player.setReleaseMode(ReleaseMode.loop);

    // Play continuously
    await player.play(AssetSource('beep.mp3'));
  });

  service.on('stop_siren').listen((event) async {
    isRunning = false;
    await player.stop();
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}
