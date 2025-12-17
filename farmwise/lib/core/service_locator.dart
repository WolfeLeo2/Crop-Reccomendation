import 'package:get_it/get_it.dart';
import '../features/crop_recommendation/data/inference_service.dart';
import '../features/weather/data/weather_service.dart';
import '../features/history/data/history_service.dart';

final sl = GetIt.instance;

void setupServiceLocator() {
  sl.registerLazySingleton<InferenceService>(() => InferenceService());
  sl.registerLazySingleton<WeatherService>(() => WeatherService());
  sl.registerLazySingleton<HistoryService>(() => HistoryService());
}
