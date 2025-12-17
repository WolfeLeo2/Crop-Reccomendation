// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:farmwise/main.dart';

import 'package:farmwise/features/crop_recommendation/data/inference_service.dart';
import 'package:farmwise/features/weather/data/weather_service.dart';
import 'package:farmwise/features/history/data/history_service.dart';
import 'package:get_it/get_it.dart';

class FakeInferenceService implements InferenceService {
  @override
  String predict(Map<String, double>? inputFeatures) => 'rice';
  @override
  Future<void> init() async {}
  @override
  bool get isLoaded => true;
  @override
  List<String> get labels => ['rice'];
}

class FakeWeatherService implements WeatherService {
  @override
  Future<Map<String, double>> getCurrentWeather() async {
    return {'temperature': 25.0, 'humidity': 80.0, 'rainfall': 100.0};
  }
}

class FakeHistoryService implements HistoryService {
  @override
  Future<void> init() async {}
  @override
  Future<void> saveRecommendation(String crop, String details) async {}
  @override
  Future<List<Map<String, dynamic>>> getHistory() async => [];
}

void main() {
  setUp(() {
    GetIt.I.registerSingleton<InferenceService>(FakeInferenceService());
    GetIt.I.registerSingleton<WeatherService>(FakeWeatherService());
    GetIt.I.registerSingleton<HistoryService>(FakeHistoryService());
  });

  tearDown(() {
    GetIt.I.reset();
  });

  testWidgets('FarmWise smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FarmWiseApp());

    // Verify that FarmWise title and form exist.
    expect(find.text('FarmWise'), findsOneWidget);
    expect(find.text('Enter Soil & Weather Details'), findsOneWidget);
    expect(find.text('N'), findsOneWidget);
  });
}
