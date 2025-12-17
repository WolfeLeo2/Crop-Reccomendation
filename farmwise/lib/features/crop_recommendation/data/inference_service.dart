import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class InferenceService {
  Interpreter? _interpreter;
  List<String>? _labels;
  Map<String, dynamic>? _normalizationParams;

  bool get isLoaded =>
      _interpreter != null && _labels != null && _normalizationParams != null;

  List<String> get labels => _labels ?? [];

  Future<void> init() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      final labelsData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsData.split('\n').where((s) => s.isNotEmpty).toList();
      final normData = await rootBundle.loadString('assets/normalization.json');
      _normalizationParams = jsonDecode(normData);
    } catch (e) {
      throw Exception('Failed to load assets: $e');
    }
  }

  String predict(Map<String, double> inputFeatures) {
    if (!isLoaded) throw Exception('Model not loaded');

    // 1. Prepare Input
    final input = <double>[];
    final mean = List<double>.from(_normalizationParams!['mean']);
    final std = List<double>.from(_normalizationParams!['std']);

    // Ordered features expected by the model
    final featureOrder = [
      'N',
      'P',
      'K',
      'temperature',
      'humidity',
      'ph',
      'rainfall',
    ];

    for (int i = 0; i < featureOrder.length; i++) {
      final key = featureOrder[i];
      final val = inputFeatures[key];
      if (val == null) throw Exception('Missing feature: $key');
      input.add((val - mean[i]) / std[i]);
    }

    // 2. Reshape & Run
    final inputTensor = [input];
    final outputTensor = List.filled(
      1 * labels.length,
      0.0,
    ).reshape([1, labels.length]);
    _interpreter!.run(inputTensor, outputTensor);

    // 3. Post-process
    final output = outputTensor[0] as List<double>;
    int maxIdx = 0;
    double maxVal = output[0];
    for (int i = 1; i < output.length; i++) {
      if (output[i] > maxVal) {
        maxVal = output[i];
        maxIdx = i;
      }
    }

    return labels[maxIdx];
  }
}
