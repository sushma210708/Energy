import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class AlertService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isPlaying = false;
  static bool _isConfigured = false;
  static Uint8List? _buzzerBytes;

  static Future<void> _configure() async {
    if (!_isConfigured) {
      _audioPlayer.setReleaseMode(ReleaseMode.loop);
      _buzzerBytes = _createBuzzerWav();
      _isConfigured = true;
    }
  }

  static Future<void> playAlert() async {
    if (!_isPlaying) {
      await _configure();
      await _audioPlayer.play(BytesSource(_buzzerBytes!));
      _isPlaying = true;
    }
  }

  static Future<void> stopAlert() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      _isPlaying = false;
    }
  }

  static Uint8List _createBuzzerWav() {
    int sampleRate = 44100;
    double duration = 0.5; // 0.5 seconds loop
    int numSamples = (sampleRate * duration).toInt();
    int numChannels = 1;
    int bitsPerSample = 16;
    int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    int blockAlign = numChannels * bitsPerSample ~/ 8;
    int dataSize = numSamples * numChannels * bitsPerSample ~/ 8;
    int fileSize = 36 + dataSize;

    List<int> bytes = [];
    
    // RIFF header
    bytes.addAll('RIFF'.codeUnits);
    bytes.addAll(_writeInt32(fileSize));
    bytes.addAll('WAVE'.codeUnits);
    
    // fmt chunk
    bytes.addAll('fmt '.codeUnits);
    bytes.addAll(_writeInt32(16)); // Chunk size
    bytes.addAll(_writeInt16(1)); // Audio format (PCM)
    bytes.addAll(_writeInt16(numChannels));
    bytes.addAll(_writeInt32(sampleRate));
    bytes.addAll(_writeInt32(byteRate));
    bytes.addAll(_writeInt16(blockAlign));
    bytes.addAll(_writeInt16(bitsPerSample));
    
    // data chunk
    bytes.addAll('data'.codeUnits);
    bytes.addAll(_writeInt32(dataSize));
    
    // Generate buzzer sound: harsh square wave
    double frequency = 1200.0;
    for (int i = 0; i < numSamples; i++) {
      double t = i / sampleRate;
      int sample = (t * frequency % 1.0 > 0.5) ? 32767 : -32768;
      
      // On/off pattern for alarm feel (0.25s on, 0.25s off)
      if (t > 0.25) {
        sample = 0;
      }
      
      bytes.addAll(_writeInt16(sample));
    }
    
    return Uint8List.fromList(bytes);
  }

  static List<int> _writeInt16(int value) {
    return [value & 0xFF, (value >> 8) & 0xFF];
  }

  static List<int> _writeInt32(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }
}
