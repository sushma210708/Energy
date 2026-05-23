import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _sensorDataUrl = 'http://13.233.76.8:5555/api/sensordata';

  static const String _settingsUrl = 'http://13.233.76.8:5555/api/settings';

  /// Fetches the latest sensor data from the API.
  /// Returns a Map of the data, or null if the request fails.
  static Future<Map<String, dynamic>?> fetchSensorData() async {
    try {
      final response = await http.get(Uri.parse(_sensorDataUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data is List && data.isNotEmpty) {
          return data[0] as Map<String, dynamic>;
        } else if (data != null && data is Map) {
           if (data.containsKey('data') && data['data'] is List && data['data'].isNotEmpty) {
              return data['data'][0] as Map<String, dynamic>;
           }
           return data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetches the alert settings from the MongoDB server.
  static Future<Map<String, dynamic>?> fetchSettings() async {
    try {
      final response = await http.get(Uri.parse(_settingsUrl));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Updates the alert settings on the MongoDB server.
  static Future<bool> updateSettings(Map<String, dynamic> settings) async {
    try {
      final response = await http.post(
        Uri.parse(_settingsUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(settings),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

