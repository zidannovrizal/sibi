import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../tflite/flex_delegate.dart';

class TfliteInferenceService {
  static Interpreter? _interpreter;
  static FlexDelegate? _flexDelegate;
  static bool _isLoading = false;
  static bool _isLoaded = false;

  static late List<int> _inputShape;
  static late TensorType _inputType;
  static late TensorType _outputType;
  static List<String> _labels = [];
  static const double _detectionThreshold = 0.10;
  static final ListQueue<List<double>> _featureWindow =
      ListQueue<List<double>>();
  static List<double>? _scalerMean;
  static List<double>? _scalerStd;
  static int _sequenceLength = 1;
  static int _featureLength = 0;
  static bool _isSequenceModel = false;

  static int get featureLength => _featureLength;
  static int get sequenceLength => _sequenceLength;

  static Future<Map<String, dynamic>> processCameraImage(
    CameraImage image,
  ) async {
    await _ensureModelLoaded();
    if (!_isLoaded) {
      return {
        'ready': false,
        'message': 'Model belum siap',
      };
    }

    if (_inputShape.length <= 2) {
      return {
        'ready': false,
        'message': 'Model memerlukan fitur pose',
      };
    }

    final Uint8List rgbBytes = _cameraImageToRgb(image);
    final Object inputBuffer =
        _buildInputBuffer(rgbBytes, image.width, image.height);

    final Tensor outputTensor = _interpreter!.getOutputTensor(0);
    final Object outputBuffer = _createOutputBuffer(outputTensor);

    try {
      _interpreter!.run(inputBuffer, outputBuffer);
    } catch (e) {
      debugPrint('TFLite inference failed: $e');
      return {
        'ready': false,
        'message': 'Inferensi gagal',
      };
    }

    final List<double> scores =
        _convertOutputToProbabilities(outputBuffer, outputTensor);

    final List<double> aggregatedScores =
        _aggregateScores(scores, outputTensor.shape);

    int maxIndex = 0;
    double maxScore = aggregatedScores[0];
    for (int i = 1; i < aggregatedScores.length; i++) {
      if (aggregatedScores[i] > maxScore) {
        maxScore = aggregatedScores[i];
        maxIndex = i;
      }
    }

    final String label =
        maxIndex < _labels.length ? _labels[maxIndex] : 'Class ${maxIndex + 1}';
    final bool detected = maxScore >= _detectionThreshold;

    debugPrint(
      '#model label=$label confidence=${maxScore.toStringAsFixed(3)} scores=${aggregatedScores.map((v) => v.toStringAsFixed(3)).toList()}',
    );

    return {
      'ready': true,
      'label': label,
      'confidence': maxScore,
      'isHandDetected': detected,
      'scores': aggregatedScores,
      'boundingBox': {
        'left': 0.3,
        'top': 0.18,
        'width': 0.4,
        'height': 0.55,
      },
      'handPosition': {'x': 0.5, 'y': 0.5},
    };
  }

  static Future<Map<String, dynamic>> processPoseFeatures(
    List<double> features,
  ) async {
    await _ensureModelLoaded();
    if (!_isLoaded) {
      return {
        'ready': false,
        'message': 'Model belum siap',
      };
    }

    if (_inputShape.length < 2) {
      return {
        'ready': false,
        'message': 'Model tidak memiliki dimensi fitur yang valid',
      };
    }

    final int featureLength = _featureLength;
    if (featureLength <= 0) {
      return {
        'ready': false,
        'message': 'Panjang fitur model tidak valid',
      };
    }

    final List<double> vector = _prepareFeatureVector(features, featureLength);

    final List<List<double>> sequenceVectors;
    if (_isSequenceModel) {
      final int required = _sequenceLength > 0 ? _sequenceLength : 1;
      _featureWindow.addLast(vector);
      while (_featureWindow.length > required) {
        _featureWindow.removeFirst();
      }
      if (_featureWindow.length < required) {
        return {
          'ready': false,
          'message': 'Mengumpulkan data pose...',
        };
      }
      sequenceVectors = List<List<double>>.from(_featureWindow);
    } else {
      if (_featureWindow.isNotEmpty) {
        _featureWindow.clear();
      }
      sequenceVectors = <List<double>>[vector];
    }

    final Object inputBuffer = _buildFeatureInputBuffer(sequenceVectors);

    final Tensor outputTensor = _interpreter!.getOutputTensor(0);
    final Object outputBuffer = _createOutputBuffer(outputTensor);

    try {
      _interpreter!.run(inputBuffer, outputBuffer);
    } catch (error) {
      debugPrint('TFLite pose inference failed: $error');
      return {
        'ready': false,
        'message': 'Inferensi pose gagal',
      };
    }

    final List<double> scores =
        _convertOutputToProbabilities(outputBuffer, outputTensor);
    final List<double> aggregatedScores =
        _aggregateScores(scores, outputTensor.shape);

    int maxIndex = 0;
    double maxScore = aggregatedScores[0];
    for (int i = 1; i < aggregatedScores.length; i++) {
      if (aggregatedScores[i] > maxScore) {
        maxScore = aggregatedScores[i];
        maxIndex = i;
      }
    }

    final String label =
        maxIndex < _labels.length ? _labels[maxIndex] : 'Class ${maxIndex + 1}';
    final bool detected = maxScore >= _detectionThreshold;

    debugPrint(
      '#model pose label=$label confidence=${maxScore.toStringAsFixed(3)} scores=${aggregatedScores.map((v) => v.toStringAsFixed(3)).toList()}',
    );

    return {
      'ready': true,
      'label': label,
      'confidence': maxScore,
      'isHandDetected': detected,
      'scores': aggregatedScores,
    };
  }

  static Future<void> reset() async {
    _featureWindow.clear();
  }

  static Future<void> _ensureModelLoaded() async {
    if (_isLoaded) return;
    if (_isLoading) {
      while (_isLoading && !_isLoaded) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return;
    }
    _isLoading = true;

    try {
      final options = InterpreterOptions()..threads = 2;
      if (!kIsWeb && Platform.isAndroid) {
        _flexDelegate ??= await FlexDelegate.create();
        options.addDelegate(_flexDelegate!);
      }

      _interpreter = await Interpreter.fromAsset(
        'assets/currently_use/sibi_compact_mlp.tflite',
        options: options,
      );

      final Tensor inputTensor = _interpreter!.getInputTensor(0);
      final Tensor outputTensor = _interpreter!.getOutputTensor(0);
      _inputShape = inputTensor.shape;
      _inputType = inputTensor.type;
      _outputType = outputTensor.type;
      _featureLength = _inputShape.isNotEmpty ? _inputShape.last : 0;
      _sequenceLength =
          _inputShape.length >= 3 ? _inputShape[_inputShape.length - 2] : 1;
      if (_sequenceLength <= 0) {
        _sequenceLength = 1;
      }
      if (_featureLength < 0) {
        _featureLength = 0;
      }
      _isSequenceModel = _sequenceLength > 1;
      _featureWindow.clear();

      final int classCount = outputTensor.shape.isNotEmpty
          ? outputTensor.shape.last
          : outputTensor.numElements();
      final int resolvedClassCount = classCount > 0 ? classCount : 1;

      await _loadLabels(resolvedClassCount);

      debugPrint(
          '#required model=assets/models/sibi_compact_mlp.tflite inputShape=$_inputShape outputShape=${outputTensor.shape} seqLen=$_sequenceLength featureLen=$_featureLength classCount=$resolvedClassCount');

      _isLoaded = true;
    } catch (e) {
      debugPrint('Failed to load TFLite model: $e');
      _interpreter?.close();
      _interpreter = null;
      _flexDelegate = null;
      _labels = [];
      _featureWindow.clear();
      _scalerMean = null;
      _scalerStd = null;
      _sequenceLength = 1;
      _featureLength = 0;
      _isSequenceModel = false;
      _isLoaded = false;
    } finally {
      _isLoading = false;
    }
  }

  static Future<void> _loadLabels(int expectedCount) async {
    try {
      // final String jsonStr = await rootBundle.loadString('assets/models/label_map.json');
      final String jsonStr = await rootBundle
          .loadString('assets/currently_use/sibi_compact_labels.json');
      final dynamic decoded = json.decode(jsonStr);
      final List<String> labels = List<String>.filled(expectedCount, '');

      if (decoded is List) {
        for (int i = 0; i < decoded.length && i < labels.length; i++) {
          labels[i] = (decoded[i] ?? '').toString();
        }
      } else if (decoded is Map<String, dynamic>) {
        decoded.forEach((key, value) {
          final int index = int.tryParse(key) ?? -1;
          if (index >= 0 && index < labels.length) {
            labels[index] = value.toString();
          }
        });
      } else {
        throw const FormatException('Unsupported label map format');
      }

      for (int i = 0; i < labels.length; i++) {
        if (labels[i].isEmpty) {
          labels[i] = 'Class ${i + 1}';
        }
      }

      debugPrint('#required labels=assets/models/sibi_compact_labels.json count=${labels.length}');
      _labels = labels;
    } catch (e) {
      debugPrint('Failed to load label map: $e');
      _labels =
          List<String>.generate(expectedCount, (index) => 'Class ${index + 1}');
    }
  }

  static Uint8List _cameraImageToRgb(CameraImage image) {
    if (image.format.group == ImageFormatGroup.yuv420) {
      return _convertYuv420ToRgb(image);
    }
    if (image.format.group == ImageFormatGroup.bgra8888) {
      return _convertBgra8888ToRgb(image);
    }
    throw UnsupportedError(
      'Unsupported camera image format: ${image.format.group}',
    );
  }

  static Object _buildInputBuffer(Uint8List rgbBytes, int width, int height) {
    final int targetHeight;
    final int targetWidth;
    if (_inputShape.length == 4) {
      targetHeight = _inputShape[1];
      targetWidth = _inputShape[2];
    } else if (_inputShape.length == 3) {
      targetHeight = _inputShape[0];
      targetWidth = _inputShape[1];
    } else {
      throw UnsupportedError('Unsupported input tensor shape: $_inputShape');
    }

    final img.Image image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgbBytes.buffer,
      numChannels: 3,
      order: img.ChannelOrder.rgb,
    );

    final img.Image resized = img.copyResize(
      image,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    final Uint8List resizedBytes =
        resized.getBytes(order: img.ChannelOrder.rgb);
    final int pixelCount = targetWidth * targetHeight * 3;

    switch (_inputType) {
      case TensorType.float32:
        final buffer = Float32List(pixelCount);
        for (int i = 0; i < pixelCount; i++) {
          buffer[i] = resizedBytes[i] / 255.0;
        }
        return buffer.reshape([1, targetHeight, targetWidth, 3]);
      case TensorType.uint8:
        final buffer = Uint8List(pixelCount);
        buffer.setAll(0, resizedBytes);
        return buffer.reshape([1, targetHeight, targetWidth, 3]);
      case TensorType.int8:
        final params = _interpreter!.getInputTensor(0).params;
        final double scale = params.scale == 0 ? 1.0 : params.scale;
        final int zeroPoint = params.zeroPoint;
        final buffer = Int8List(pixelCount);
        for (int i = 0; i < pixelCount; i++) {
          final double normalized = resizedBytes[i] / 255.0;
          final int quantized = (((normalized / scale) + zeroPoint).round())
              .clamp(-128, 127)
              .toInt();
          buffer[i] = quantized;
        }
        return buffer.reshape([1, targetHeight, targetWidth, 3]);
      default:
        throw UnsupportedError('Unsupported input tensor type: $_inputType');
    }
  }

  static List<double> _convertOutputToProbabilities(
    Object output,
    Tensor tensor,
  ) {
    List<double> values;

    if (output is Float32List) {
      values = output.toList();
    } else if (output is Uint8List) {
      final params = tensor.params;
      final double scale = params.scale == 0 ? 1.0 : params.scale;
      final int zeroPoint = params.zeroPoint;
      values = List<double>.generate(
        output.length,
        (index) => (output[index] - zeroPoint) * scale,
      );
    } else if (output is Int8List) {
      final params = tensor.params;
      final double scale = params.scale == 0 ? 1.0 : params.scale;
      final int zeroPoint = params.zeroPoint;
      values = List<double>.generate(
        output.length,
        (index) => (output[index] - zeroPoint) * scale,
      );
    } else if (output is List) {
      values = _extractFloatsFromNestedList(output, tensor);
    } else {
      throw UnsupportedError(
          'Unsupported output buffer type: ${output.runtimeType}');
    }

    final double maxValue = values.reduce((a, b) => a > b ? a : b);
    final List<double> exps =
        values.map((value) => math.exp(value - maxValue)).toList();
    final double sum = exps.fold(0.0, (a, b) => a + b);
    if (sum == 0) {
      return List<double>.filled(values.length, 0.0);
    }

    return exps.map((value) => value / sum).toList();
  }

  static Uint8List _convertYuv420ToRgb(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final Uint8List rgb = Uint8List(width * height * 3);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * width + x;
        final int uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        final int yValue = image.planes[0].bytes[yIndex];
        final int uValue = image.planes[1].bytes[uvIndex];
        final int vValue = image.planes[2].bytes[uvIndex];

        int r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
        int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
            .round()
            .clamp(0, 255);
        int b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);

        final int rgbIndex = yIndex * 3;
        rgb[rgbIndex] = r;
        rgb[rgbIndex + 1] = g;
        rgb[rgbIndex + 2] = b;
      }
    }

    return rgb;
  }

  static Uint8List _convertBgra8888ToRgb(CameraImage image) {
    final Uint8List bytes = image.planes[0].bytes;
    final Uint8List rgb = Uint8List(image.width * image.height * 3);

    for (int i = 0, j = 0; i < bytes.lengthInBytes; i += 4, j += 3) {
      rgb[j] = bytes[i + 2];
      rgb[j + 1] = bytes[i + 1];
      rgb[j + 2] = bytes[i];
    }

    return rgb;
  }

  static List<double> _prepareFeatureVector(
    List<double> features,
    int expectedLength,
  ) {
    final List<double> vector =
        List<double>.filled(expectedLength, 0.0, growable: false);
    final List<double>? mean = _scalerMean;
    final List<double>? std = _scalerStd;
    final int copyLength = math.min(expectedLength, features.length);
    for (int i = 0; i < copyLength; i++) {
      double value = features[i];
      if (mean != null && std != null && i < mean.length && i < std.length) {
        final double denom = std[i].abs() < 1e-6 ? 1.0 : std[i];
        value = (value - mean[i]) / denom;
      }
      vector[i] = value;
    }

    if (mean != null && std != null) {
      final int limit =
          math.min(expectedLength, math.min(mean.length, std.length));
      for (int i = copyLength; i < limit; i++) {
        vector[i] = 0.0;
      }
    }
    return vector;
  }

  static Object _buildFeatureInputBuffer(List<List<double>> vectors) {
    if (_inputShape.isEmpty) {
      throw UnsupportedError('Unsupported input tensor shape: $_inputShape');
    }

    final List<int> shape = List<int>.from(_inputShape);
    if (shape.isNotEmpty && shape[0] <= 0) {
      shape[0] = 1;
    }

    final int sequenceLength = _sequenceLength > 0
        ? _sequenceLength
        : (shape.length >= 3 ? shape[shape.length - 2] : 1);
    final int featureLength = _featureLength > 0
        ? _featureLength
        : (shape.isNotEmpty ? shape.last : 0);
    final int batch = shape.isNotEmpty ? shape.first : 1;

    if (shape.length >= 3) {
      final int sequenceIndex = shape.length - 2;
      if (shape[sequenceIndex] <= 0) {
        shape[sequenceIndex] = sequenceLength;
      }
    }
    if (shape.isNotEmpty && shape.last <= 0) {
      shape[shape.length - 1] = featureLength;
    }

    final int totalVectors = math.max(1, batch) * math.max(1, sequenceLength);
    final int totalValues = totalVectors * featureLength;

    List<double> vectorFor(int index) {
      if (vectors.isEmpty) {
        return List<double>.filled(featureLength, 0.0, growable: false);
      }
      if (index < vectors.length) {
        return vectors[index];
      }
      return List<double>.from(vectors.last);
    }

    switch (_inputType) {
      case TensorType.float32:
        final buffer = Float32List(totalValues);
        int offset = 0;
        for (int seqIndex = 0; seqIndex < totalVectors; seqIndex++) {
          final List<double> vector = vectorFor(seqIndex);
          for (int i = 0; i < featureLength; i++) {
            buffer[offset++] = i < vector.length ? vector[i] : 0.0;
          }
        }
        return buffer.reshape(shape);
      case TensorType.uint8:
        final buffer = Uint8List(totalValues);
        int offset = 0;
        for (int seqIndex = 0; seqIndex < totalVectors; seqIndex++) {
          final List<double> vector = vectorFor(seqIndex);
          for (int i = 0; i < featureLength; i++) {
            final double value = i < vector.length ? vector[i] : 0.0;
            final double scaled = value.clamp(0.0, 1.0) * 255.0;
            buffer[offset++] = scaled.round().clamp(0, 255);
          }
        }
        return buffer.reshape(shape);
      case TensorType.int8:
        final params = _interpreter!.getInputTensor(0).params;
        final double scale = params.scale == 0 ? 1.0 : params.scale;
        final int zeroPoint = params.zeroPoint;
        final buffer = Int8List(totalValues);
        int offset = 0;
        for (int seqIndex = 0; seqIndex < totalVectors; seqIndex++) {
          final List<double> vector = vectorFor(seqIndex);
          for (int i = 0; i < featureLength; i++) {
            final double value = i < vector.length ? vector[i] : 0.0;
            final double quantized = (value / scale) + zeroPoint;
            buffer[offset++] = quantized.round().clamp(-128, 127);
          }
        }
        return buffer.reshape(shape);
      default:
        throw UnsupportedError('Unsupported input tensor type: $_inputType');
    }
  }

  static Object _createOutputBuffer(Tensor tensor) {
    final int count = tensor.numElements();
    final List<int> shape = tensor.shape;

    switch (_outputType) {
      case TensorType.float32:
        final buffer = Float32List(count);
        return shape.isNotEmpty ? buffer.reshape(shape) : buffer;
      case TensorType.uint8:
        final buffer = Uint8List(count);
        return shape.isNotEmpty ? buffer.reshape(shape) : buffer;
      case TensorType.int8:
        final buffer = Int8List(count);
        return shape.isNotEmpty ? buffer.reshape(shape) : buffer;
      default:
        throw UnsupportedError('Unsupported output tensor type: $_outputType');
    }
  }

  static List<double> _aggregateScores(List<double> scores, List<int> shape) {
    if (scores.isEmpty) {
      return const <double>[];
    }
    if (shape.isEmpty) {
      return scores;
    }

    final int classCount = shape.isNotEmpty ? shape.last : scores.length;
    if (classCount <= 0 || scores.length == classCount) {
      return scores.take(classCount).toList();
    }

    final int outerDim = scores.length ~/ classCount;
    if (outerDim <= 1) {
      return scores.take(classCount).toList();
    }

    final List<double> aggregated = List<double>.filled(classCount, 0.0);
    for (int outer = 0; outer < outerDim; outer++) {
      final int offset = outer * classCount;
      for (int i = 0; i < classCount; i++) {
        aggregated[i] += scores[offset + i];
      }
    }
    for (int i = 0; i < classCount; i++) {
      aggregated[i] /= outerDim;
    }
    return aggregated;
  }

  static List<double> _extractFloatsFromNestedList(
    Object output,
    Tensor tensor,
  ) {
    if (_outputType == TensorType.float32) {
      return _flattenToDoubleList(output);
    }

    final params = tensor.params;
    final double scale = params.scale == 0 ? 1.0 : params.scale;
    final int zeroPoint = params.zeroPoint;
    final List<int> rawInts = _flattenToIntList(output);
    return rawInts
        .map((value) => (value - zeroPoint) * scale)
        .toList(growable: false);
  }

  static List<double> _flattenToDoubleList(Object value) {
    final result = <double>[];
    void collect(Object? element) {
      if (element is List) {
        for (final item in element) {
          collect(item);
        }
      } else if (element is Float32List) {
        result.addAll(element);
      } else if (element is Int8List) {
        result.addAll(element.map((e) => e.toDouble()));
      } else if (element is Uint8List) {
        result.addAll(element.map((e) => e.toDouble()));
      } else if (element is num) {
        result.add(element.toDouble());
      } else {
        throw UnsupportedError(
          'Unsupported nested output element type: ${element.runtimeType}',
        );
      }
    }

    collect(value);
    return result;
  }

  static List<int> _flattenToIntList(Object value) {
    final result = <int>[];
    void collect(Object? element) {
      if (element is List) {
        for (final item in element) {
          collect(item);
        }
      } else if (element is Int8List) {
        result.addAll(element);
      } else if (element is Uint8List) {
        result.addAll(element);
      } else if (element is num) {
        result.add(element.toInt());
      } else {
        throw UnsupportedError(
          'Unsupported nested quantized element type: ${element.runtimeType}',
        );
      }
    }

    collect(value);
    return result;
  }
}
