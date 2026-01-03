import 'dart:convert';
import 'package:http/http.dart' as http;

/// InferenceService - API-based crop recommendation
/// Uses the FastAPI backend hosted on Render
class InferenceService {
  static const String _apiUrl = 'https://farmwise-api.onrender.com';

  bool _isReady = false;

  bool get isLoaded => _isReady;

  // Labels for reference (matches backend model)
  final List<String> labels = [
    'rice',
    'maize',
    'chickpea',
    'kidneybeans',
    'pigeonpeas',
    'mothbeans',
    'mungbean',
    'blackgram',
    'lentil',
    'pomegranate',
    'banana',
    'mango',
    'grapes',
    'watermelon',
    'muskmelon',
    'apple',
    'orange',
    'papaya',
    'coconut',
    'cotton',
    'jute',
    'coffee',
  ];

  Future<void> init() async {
    // No need to block on health check - just mark ready
    // API errors will be caught at predict time
    _isReady = true;
  }

  /// Predict crop based on soil and weather parameters
  /// Returns the recommended crop name
  Future<String> predict(Map<String, double> inputFeatures) async {
    final body = {
      'N': inputFeatures['N'],
      'P': inputFeatures['P'],
      'K': inputFeatures['K'],
      'temperature': inputFeatures['temperature'],
      'humidity': inputFeatures['humidity'],
      'ph': inputFeatures['ph'],
      'rainfall': inputFeatures['rainfall'],
    };

    try {
      final response = await http
          .post(
            Uri.parse('$_apiUrl/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 30),
          ); // Longer timeout for cold start

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['prediction'] as String;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Prediction failed');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Server is warming up. Please try again in a moment.');
      }
      throw Exception('Prediction failed: $e');
    }
  }

  /// Get prediction with confidence score
  Future<Map<String, dynamic>> predictWithConfidence(
    Map<String, double> inputFeatures,
  ) async {
    final body = {
      'N': inputFeatures['N'],
      'P': inputFeatures['P'],
      'K': inputFeatures['K'],
      'temperature': inputFeatures['temperature'],
      'humidity': inputFeatures['humidity'],
      'ph': inputFeatures['ph'],
      'rainfall': inputFeatures['rainfall'],
    };

    try {
      final response = await http
          .post(
            Uri.parse('$_apiUrl/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Prediction failed');
      }
    } catch (e) {
      throw Exception('Prediction failed: $e');
    }
  }
}
