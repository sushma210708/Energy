import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://13.233.76.8:5555/api';
  static const String _sensorDataUrl = '$_baseUrl/sensordata';
  static const String _settingsUrl = '$_baseUrl/settings';

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

  /// Fetches settings for a given user from the server
  static Future<Map<String, dynamic>?> fetchSettings(String userId) async {
    try {
      final response = await http.get(Uri.parse('$_settingsUrl/$userId'));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Updates settings for a given user
  static Future<bool> updateSettings(String userId, Map<String, dynamic> settings) async {
    try {
      final response = await http.post(
        Uri.parse('$_settingsUrl/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(settings),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Registers an FCM token for push notifications
  static Future<bool> registerFcmToken(String userId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_settingsUrl/$userId/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Fetches the alert history for a given user
  static Future<List<dynamic>?> fetchAlertHistory(String userId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/alerts/$userId'));
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Clears the alert history for a given user
  static Future<bool> clearAlertHistory(String userId) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/alerts/$userId'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Stops ongoing background and foreground alerts globally for this user
  static Future<bool> stopAlert(String userId) async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/alerts/$userId/stop'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
