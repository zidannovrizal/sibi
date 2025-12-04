import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../tflite/flex_delegate.dart';

/// Utility service that can be used to inspect the bundled TFLite model and
/// experiment with different input windows without touching the production
/// inference pipeline.
class TfliteModelFeatureTester {
  TfliteModelFeatureTester({
    this.assetPath = 'assets/currently_use/sibi_compact_mlp.tflite',
    this.threads = 2,
    this.enableFlexDelegate = true,
  });

  final String assetPath;
  final int threads;
  final bool enableFlexDelegate;

  Interpreter? _interpreter;
  FlexDelegate? _flexDelegate;
  Completer<void>? _loadingCompleter;
  TfliteModelSummary? _cachedSummary;

  /// Ensures the underlying interpreter is ready for use.
  Future<void> _ensureInterpreter() async {
    if (_interpreter != null) {
      return;
    }

    final existingCompleter = _loadingCompleter;
    if (existingCompleter != null) {
      await existingCompleter.future;
      return;
    }

    final completer = Completer<void>();
    _loadingCompleter = completer;

    try {
      final options = InterpreterOptions()..threads = threads;
      if (enableFlexDelegate && !kIsWeb && Platform.isAndroid) {
        _flexDelegate = await FlexDelegate.create();
        options.addDelegate(_flexDelegate!);
      }

      _interpreter = await Interpreter.fromAsset(
        assetPath,
        options: options,
      );

      completer.complete();
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      rethrow;
    } finally {
      if (identical(_loadingCompleter, completer)) {
        _loadingCompleter = null;
      }
    }
  }

  /// Returns a cached description of the model tensors and inferred sequence settings.
  Future<TfliteModelSummary> describe({bool forceRefresh = false}) async {
    if (_cachedSummary != null && !forceRefresh) {
      return _cachedSummary!;
    }

    await _ensureInterpreter();
    final interpreter = _interpreter!;

    final inputTensors = interpreter.getInputTensors();
    final outputTensors = interpreter.getOutputTensors();

    final inputSummaries = List<TfliteTensorSummary>.generate(
      inputTensors.length,
      (index) => _mapTensor(index, inputTensors[index]),
      growable: false,
    );
    final outputSummaries = List<TfliteTensorSummary>.generate(
      outputTensors.length,
      (index) => _mapTensor(index, outputTensors[index]),
      growable: false,
    );

    final sequenceLength = _extractSequenceLength(inputSummaries);
    final featureLength = _extractFeatureLength(inputSummaries);
    final classCount = _extractClassCount(outputSummaries);

    final summary = TfliteModelSummary(
      assetPath: assetPath,
      inputTensors: inputSummaries,
      outputTensors: outputSummaries,
      sequenceLength: sequenceLength,
      featureLength: featureLength,
      classCount: classCount,
      isSequenceModel: sequenceLength > 1 && featureLength > 0,
    );

    _cachedSummary = summary;
    return summary;
  }

  /// Runs inference on a prepared feature window.
  Future<TfliteModelProbeResult> runOnFeatureWindow(
    List<List<double>> featureWindow, {
    List<String>? labelsOverride,
    double detectionThreshold = 0.4,
    bool padShortSequence = true,
  }) async {
    final summary = await describe();
    if (summary.sequenceLength <= 0 || summary.featureLength <= 0) {
      throw StateError(
          'Model summary could not determine sequence dimensions.');
    }

    final normalizedWindow = _normalizeWindow(
      featureWindow,
      summary.sequenceLength,
      summary.featureLength,
      padShortSequence,
    );

    final interpreter = _interpreter!;
    final int classCount = summary.classCount > 0
        ? summary.classCount
        : math.max(
            1,
            summary.outputTensors.isNotEmpty
                ? summary.outputTensors.first.elementCountWithoutBatch
                : 1,
          );
    final List<List<double>> output = List<List<double>>.generate(
      1,
      (_) => List<double>.filled(classCount, 0.0),
      growable: false,
    );

    try {
      interpreter.run(<List<List<double>>>[normalizedWindow], output);
    } catch (error) {
      debugPrint('TfliteModelFeatureTester.runOnFeatureWindow failed: $error');
      rethrow;
    }

    final List<double> scores = output.first;
    final labels = _resolveLabels(summary.classCount, labelsOverride);
    final int topIndex = _argMax(scores);
    final double topScore =
        scores.isNotEmpty && topIndex < scores.length ? scores[topIndex] : 0.0;

    return TfliteModelProbeResult(
      assetPath: assetPath,
      labels: labels,
      scores: List<double>.from(scores),
      topLabel: topIndex < labels.length ? labels[topIndex] : 'class_$topIndex',
      topIndex: topIndex,
      topScore: topScore,
      detectionThreshold: detectionThreshold,
      sequenceReady: normalizedWindow.length == summary.sequenceLength,
      inferenceTimeMicros: interpreter.lastNativeInferenceDurationMicroSeconds,
    );
  }

  /// Generates a synthetic constant window and performs an inference pass.
  Future<TfliteModelProbeResult> runSyntheticProbe({
    double fillValue = 0.0,
    bool randomize = false,
    int? randomSeed,
    List<String>? labelsOverride,
    double detectionThreshold = 0.4,
  }) async {
    final summary = await describe();
    if (summary.sequenceLength <= 0 || summary.featureLength <= 0) {
      throw StateError(
          'Model summary could not determine sequence dimensions.');
    }

    final math.Random? random = randomize ? math.Random(randomSeed) : null;
    final List<List<double>> window = List<List<double>>.generate(
      summary.sequenceLength,
      (_) => List<double>.generate(
        summary.featureLength,
        (_) => random?.nextDouble() ?? fillValue,
        growable: false,
      ),
      growable: false,
    );

    return runOnFeatureWindow(
      window,
      labelsOverride: labelsOverride,
      detectionThreshold: detectionThreshold,
      padShortSequence: false,
    );
  }

  /// Creates a prediction stream from an incoming feature vector stream.
  Stream<TfliteModelProbeResult> streamFromFeatureVectors(
    Stream<List<double>> featureStream, {
    List<String>? labelsOverride,
    bool padInitialWindow = true,
    double detectionThreshold = 0.4,
  }) async* {
    final summary = await describe();
    if (summary.sequenceLength <= 0 || summary.featureLength <= 0) {
      throw StateError(
          'Model summary could not determine sequence dimensions.');
    }

    final Queue<List<double>> window = Queue<List<double>>();
    await for (final rawVector in featureStream) {
      final normalizedVector = _normalizeVector(
        rawVector,
        summary.featureLength,
      );

      window.addLast(normalizedVector);
      while (window.length > summary.sequenceLength) {
        window.removeFirst();
      }

      if (padInitialWindow && window.length == 1) {
        while (window.length < summary.sequenceLength) {
          window.addLast(List<double>.from(normalizedVector));
        }
      }

      if (window.length < summary.sequenceLength) {
        continue;
      }

      final result = await runOnFeatureWindow(
        window.toList(growable: false),
        labelsOverride: labelsOverride,
        detectionThreshold: detectionThreshold,
        padShortSequence: false,
      );
      yield result;
    }
  }

  /// Releases interpreter resources and any associated delegate.
  Future<void> dispose() async {
    final completer = _loadingCompleter;
    if (completer != null) {
      try {
        await completer.future;
      } catch (_) {}
    }

    final interpreter = _interpreter;
    _interpreter = null;
    _cachedSummary = null;

    if (interpreter != null) {
      try {
        interpreter.close();
      } catch (error) {
        debugPrint(
            'TfliteModelFeatureTester.dispose interpreter error: $error');
      }
    }

    final delegate = _flexDelegate;
    _flexDelegate = null;
    if (delegate != null) {
      try {
        await delegate.delete();
      } catch (error) {
        debugPrint('TfliteModelFeatureTester.dispose delegate error: $error');
      }
    }
  }

  TfliteTensorSummary _mapTensor(int index, Tensor tensor) {
    return TfliteTensorSummary(
      index: index,
      name: tensor.name,
      shape: List<int>.from(tensor.shape),
      type: tensor.type,
      byteSize: tensor.numBytes(),
      quantizationScale: tensor.params.scale,
      quantizationZeroPoint: tensor.params.zeroPoint,
    );
  }

  List<String> _resolveLabels(int classCount, List<String>? override) {
    if (override != null && override.isNotEmpty) {
      if (override.length >= classCount) {
        return override;
      }
      final extended = List<String>.from(override);
      for (int i = override.length; i < classCount; i++) {
        extended.add('class_$i');
      }
      return extended;
    }
    return List<String>.generate(classCount, (index) => 'gesture_$index');
  }

  List<List<double>> _normalizeWindow(
    List<List<double>> window,
    int sequenceLength,
    int featureLength,
    bool padShortSequence,
  ) {
    if (sequenceLength <= 0) {
      throw ArgumentError('Sequence length must be positive.');
    }
    if (featureLength <= 0) {
      throw ArgumentError('Feature length must be positive.');
    }

    final List<List<double>> normalized = <List<double>>[];
    if (window.isNotEmpty) {
      final int startIndex = math.max(0, window.length - sequenceLength);
      for (int i = startIndex; i < window.length; i++) {
        normalized.add(_normalizeVector(window[i], featureLength));
      }
    }

    if (normalized.length < sequenceLength) {
      if (!padShortSequence) {
        throw ArgumentError(
          'Expected at least $sequenceLength feature vectors but received ${normalized.length}.',
        );
      }

      final List<double> padVector = normalized.isNotEmpty
          ? normalized.last
          : List<double>.filled(featureLength, 0.0);
      while (normalized.length < sequenceLength) {
        normalized.add(List<double>.from(padVector));
      }
    }

    return normalized;
  }

  List<double> _normalizeVector(List<double> vector, int featureLength) {
    if (featureLength <= 0) {
      throw ArgumentError('Feature length must be positive.');
    }

    if (vector.length == featureLength) {
      return List<double>.from(vector, growable: false);
    }

    final List<double> normalized =
        List<double>.filled(featureLength, 0.0, growable: false);
    final int copyLength = math.min(vector.length, featureLength);
    for (int i = 0; i < copyLength; i++) {
      normalized[i] = vector[i];
    }

    if (copyLength == 0) {
      return normalized;
    }

    final double padValue = normalized[copyLength - 1];
    for (int i = copyLength; i < featureLength; i++) {
      normalized[i] = padValue;
    }
    return normalized;
  }

  int _extractSequenceLength(List<TfliteTensorSummary> inputs) {
    if (inputs.isEmpty) {
      return 0;
    }
    final List<int> shape = inputs.first.shape;
    if (shape.length >= 3) {
      return shape[shape.length - 2];
    }
    if (shape.length >= 2) {
      return shape[shape.length - 1];
    }
    return 0;
  }

  int _extractFeatureLength(List<TfliteTensorSummary> inputs) {
    if (inputs.isEmpty) {
      return 0;
    }
    final List<int> shape = inputs.first.shape;
    if (shape.isEmpty) {
      return 0;
    }
    return shape.last;
  }

  int _extractClassCount(List<TfliteTensorSummary> outputs) {
    if (outputs.isEmpty) {
      return 0;
    }
    final List<int> shape = outputs.first.shape;
    if (shape.isEmpty) {
      return 0;
    }
    final int last = shape.last;
    if (last > 0) {
      return last;
    }

    int product = 1;
    bool hasPositive = false;
    for (int i = 0; i < shape.length; i++) {
      final int dimension = shape[i];
      if (dimension <= 0) {
        continue;
      }
      if (i == 0 && dimension == 1) {
        continue;
      }
      product *= dimension;
      hasPositive = true;
    }
    return hasPositive ? product : 0;
  }

  int _argMax(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    int index = 0;
    double maxValue = values[0];
    for (int i = 1; i < values.length; i++) {
      if (values[i] > maxValue) {
        maxValue = values[i];
        index = i;
      }
    }
    return index;
  }
}

class TfliteModelSummary {
  const TfliteModelSummary({
    required this.assetPath,
    required this.inputTensors,
    required this.outputTensors,
    required this.sequenceLength,
    required this.featureLength,
    required this.classCount,
    required this.isSequenceModel,
  });

  final String assetPath;
  final List<TfliteTensorSummary> inputTensors;
  final List<TfliteTensorSummary> outputTensors;
  final int sequenceLength;
  final int featureLength;
  final int classCount;
  final bool isSequenceModel;

  Map<String, Object> toMap() {
    return <String, Object>{
      'assetPath': assetPath,
      'sequenceLength': sequenceLength,
      'featureLength': featureLength,
      'classCount': classCount,
      'isSequenceModel': isSequenceModel,
      'inputs': inputTensors.map((tensor) => tensor.toMap()).toList(),
      'outputs': outputTensors.map((tensor) => tensor.toMap()).toList(),
    };
  }
}

class TfliteTensorSummary {
  const TfliteTensorSummary({
    required this.index,
    required this.name,
    required this.shape,
    required this.type,
    required this.byteSize,
    required this.quantizationScale,
    required this.quantizationZeroPoint,
  });

  final int index;
  final String name;
  final List<int> shape;
  final TensorType type;
  final int byteSize;
  final double quantizationScale;
  final int quantizationZeroPoint;

  int get batchSize => shape.isNotEmpty ? shape.first : 1;

  int get elementCountWithoutBatch {
    if (shape.isEmpty) {
      return 0;
    }
    int product = 1;
    bool hasPositive = false;
    for (int i = 0; i < shape.length; i++) {
      final int dimension = shape[i];
      if (dimension <= 0) {
        continue;
      }
      if (i == 0 && dimension == 1) {
        continue;
      }
      product *= dimension;
      hasPositive = true;
    }
    return hasPositive ? product : 0;
  }

  Map<String, Object> toMap() {
    return <String, Object>{
      'index': index,
      'name': name,
      'shape': shape,
      'type': type.toString(),
      'byteSize': byteSize,
      'quantization': <String, Object>{
        'scale': quantizationScale,
        'zeroPoint': quantizationZeroPoint,
      },
    };
  }
}

class TfliteModelProbeResult {
  const TfliteModelProbeResult({
    required this.assetPath,
    required this.labels,
    required this.scores,
    required this.topLabel,
    required this.topIndex,
    required this.topScore,
    required this.detectionThreshold,
    required this.sequenceReady,
    required this.inferenceTimeMicros,
  });

  final String assetPath;
  final List<String> labels;
  final List<double> scores;
  final String topLabel;
  final int topIndex;
  final double topScore;
  final double detectionThreshold;
  final bool sequenceReady;
  final int inferenceTimeMicros;

  bool get meetsThreshold => topScore >= detectionThreshold;

  Map<String, Object> toMap() {
    return <String, Object>{
      'assetPath': assetPath,
      'topLabel': topLabel,
      'topIndex': topIndex,
      'topScore': topScore,
      'detectionThreshold': detectionThreshold,
      'sequenceReady': sequenceReady,
      'inferenceTimeMicros': inferenceTimeMicros,
      'scores': scores,
      'labels': labels,
    };
  }
}
