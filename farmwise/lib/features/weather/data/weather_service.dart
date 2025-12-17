import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherService {
  Future<Map<String, double>> getCurrentWeather() async {
    // 1. Get Location
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    final position = await Geolocator.getCurrentPosition();

    // 2. Fetch Historical Average Weather (Last 30 Days) from Open-Meteo
    return await _getHistoricalWeather(position.latitude, position.longitude);
  }

  Future<Map<String, double>> _getHistoricalWeather(
    double lat,
    double lon,
  ) async {
    // Open-Meteo Archive API
    // Fetch last 30 days to get a seasonal average
    final endDate = DateTime.now().subtract(const Duration(days: 1));
    final startDate = endDate.subtract(const Duration(days: 30));

    String dateFormat(DateTime date) =>
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final url = Uri.parse(
      'https://archive-api.open-meteo.com/v1/archive?'
      'latitude=$lat&longitude=$lon&'
      'start_date=${dateFormat(startDate)}&'
      'end_date=${dateFormat(endDate)}&'
      'daily=temperature_2m_mean,relative_humidity_2m_mean,precipitation_sum&'
      'timezone=auto',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final daily = data['daily'];

        return {
          'temperature': _calculateAverage(daily['temperature_2m_mean']),
          'humidity': _calculateAverage(daily['relative_humidity_2m_mean']),
          'rainfall': _calculateSum(daily['precipitation_sum']),
        };
      } else {
        throw Exception('Failed to load weather data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching weather data: $e');
    }
  }

  double _calculateAverage(List<dynamic> values) {
    if (values.isEmpty) return 0.0;
    double sum = 0.0;
    int count = 0;
    for (var v in values) {
      if (v != null) {
        sum += (v as num).toDouble();
        count++;
      }
    }
    return count > 0 ? sum / count : 0.0;
  }

  double _calculateSum(List<dynamic> values) {
    double sum = 0.0;
    for (var v in values) {
      if (v != null) {
        sum += (v as num).toDouble();
      }
    }
    return sum;
  }
}
