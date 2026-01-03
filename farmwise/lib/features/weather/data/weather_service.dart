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

    // 2. Fetch FORECAST Weather (Next 90 Days) from Open-Meteo Seasonal API
    // This is the key change: we predict based on FUTURE conditions, not past
    return await _getForecastWeather(position.latitude, position.longitude);
  }

  Future<Map<String, double>> _getForecastWeather(
    double lat,
    double lon,
  ) async {
    // Open-Meteo Seasonal API - Next 90 days (one growing season)
    final startDate = DateTime.now();
    final endDate = startDate.add(const Duration(days: 90));

    String dateFormat(DateTime date) =>
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // Using daily aggregation from seasonal API
    // Variables: temperature_2m_mean, relative_humidity_2m_mean, precipitation_sum
    final url = Uri.parse(
      'https://seasonal-api.open-meteo.com/v1/seasonal?'
      'latitude=$lat&longitude=$lon&'
      'daily=temperature_2m_mean,relative_humidity_2m_mean,precipitation_sum&'
      'start_date=${dateFormat(startDate)}&'
      'end_date=${dateFormat(endDate)}',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final daily = data['daily'];

        // Aggregate 90 days: avg temp, avg humidity, total rain
        return {
          'temperature': _calculateAverage(daily['temperature_2m_mean'] ?? []),
          'humidity': _calculateAverage(
            daily['relative_humidity_2m_mean'] ?? [],
          ),
          'rainfall': _calculateSum(daily['precipitation_sum'] ?? []),
        };
      } else {
        throw Exception('Failed to load forecast data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching forecast data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSeasonalForecast(
    double lat,
    double lon,
  ) async {
    // Open-Meteo Seasonal API
    // Fetch next 6 months
    final startDate = DateTime.now();
    final endDate = startDate.add(const Duration(days: 180));

    String dateFormat(DateTime date) =>
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final seasonalUrl = Uri.parse(
      'https://seasonal-api.open-meteo.com/v1/seasonal?latitude=$lat&longitude=$lon&daily=temperature_2m_mean,precipitation_sum&start_date=${dateFormat(startDate)}&end_date=${dateFormat(endDate)}',
    );

    try {
      final response = await http.get(seasonalUrl);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final daily = data['daily'];
        final dates = daily['time'] as List;
        final temps = daily['temperature_2m_mean'] as List;
        final rains = daily['precipitation_sum'] as List;

        // Aggregate by Month
        Map<String, Map<String, dynamic>> monthlyData = {};

        for (int i = 0; i < dates.length; i++) {
          final date = DateTime.parse(dates[i]);
          final monthKey =
              "${date.year}-${date.month.toString().padLeft(2, '0')}"; // e.g., 2025-01

          if (!monthlyData.containsKey(monthKey)) {
            monthlyData[monthKey] = {
              'tempSum': 0.0,
              'rainSum': 0.0,
              'count': 0,
              'date': date, // Keep one date object for formatting
            };
          }
          if (temps[i] != null) {
            monthlyData[monthKey]!['tempSum'] += (temps[i] as num).toDouble();
          }
          if (rains[i] != null) {
            monthlyData[monthKey]!['rainSum'] += (rains[i] as num).toDouble();
          }
          monthlyData[monthKey]!['count']++;
        }

        List<Map<String, dynamic>> forecast = [];
        monthlyData.forEach((key, value) {
          final count = value['count'] as int;
          forecast.add({
            'month': value['date'], // DateTime object
            'avgTemp': count > 0 ? value['tempSum'] / count : 0.0,
            'totalRain': value['rainSum'],
          });
        });

        // Sort by date
        forecast.sort(
          (a, b) => (a['month'] as DateTime).compareTo(b['month'] as DateTime),
        );

        return forecast;
      } else {
        // Fallback or empty if API fails/unavailable
        return [];
      }
    } catch (e) {
      // debugPrint("Error fetching seasonal forecast: $e");
      return [];
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
