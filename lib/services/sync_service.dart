import 'package:socket_io_client/socket_io_client.dart' as IO;

class SyncService {
  late IO.Socket socket;
  Function(Map<String, dynamic>)? onSettingsUpdated;
  Function()? onAlertStopped;

  void init() {
    socket = IO.io('http://192.168.1.11:5555', IO.OptionBuilder()
      .setTransports(['websocket']) // for Flutter or Web
      .disableAutoConnect()  // disable auto-connection
      .build()
    );
    
    socket.connect();
    
    socket.onConnect((_) {
      print('✅ Connected to SyncService socket');
    });

    socket.on('settings-updated', (data) {
      if (onSettingsUpdated != null && data != null && data['settings'] != null) {
        onSettingsUpdated!(data['settings'] as Map<String, dynamic>);
      }
    });

    socket.on('alert-stopped', (_) {
      if (onAlertStopped != null) {
        onAlertStopped!();
      }
    });
    
    socket.onDisconnect((_) => print('❌ Disconnected from SyncService socket'));
  }
}
