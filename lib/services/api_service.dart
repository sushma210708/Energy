import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _sensorDataUrl = 'http://13.233.76.8:5555/api/sensordata';

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
}
