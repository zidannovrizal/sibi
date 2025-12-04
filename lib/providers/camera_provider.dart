import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:movenet_hands_bridge/movenet_hands_bridge.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/compact_feature_builder.dart';
import '../services/sentence_builder.dart';
import '../services/tflite_inference_service.dart';
import '../services/tflite_model_feature_service.dart';

class CameraProvider extends ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isInitialized = false;
  bool _isCameraActive = false;
  bool _isFlashOn = false;

  String _recognizedText = 'Menunggu kamera...';
  double _confidence = 0.0;
  String _gestureType = '';
  Map<String, double> _handPosition = {'x': 0.5, 'y': 0.5};
  Map<String, double> _handBox = {
    'left': 0.3,
    'top': 0.18,
    'width': 0.4,
    'height': 0.55,
  };
  bool _isHandDetected = false;

  bool _isProcessingFrame = false;
  DateTime? _lastFrameAt;

  final TfliteModelFeatureTester _modelFeatureTester =
      TfliteModelFeatureTester();
  bool _isModelFeatureTesterLoading = false;
  bool _isModelFeatureTesterReady = false;
  String? _modelFeatureTesterError;
  TfliteModelSummary? _modelSummary;
  TfliteModelProbeResult? _syntheticProbeResult;
  final MovenetHandsBridge _handsBridge = MovenetHandsBridge();
  CompactFeatureBuilder? _compactBuilder;
  bool _isBridgeReady = false;
  bool _scalerLoaded = false;
  static const String _blankLabel = 'idle';
  final SentenceBuilder _sentenceBuilder = SentenceBuilder(
    maxWords: 3,
    timeout: const Duration(seconds: 3),
    minConfidence: 0.10,
  );

  // Samakan dengan window ~1.4s @ ~16-20 fps input (≈60 ms per frame)
  static const Duration _minFrameInterval = Duration(milliseconds: 60);
  static const ResolutionPreset _cameraResolution = ResolutionPreset.low;

  CameraController? get controller => _controller;
  List<CameraDescription> get cameras => _cameras;
  bool get isInitialized => _isInitialized;
  bool get isCameraActive => _isCameraActive;
  bool get isFlashOn => _isFlashOn;
  String get recognizedText => _recognizedText;
  double get confidence => _confidence;
  String get gestureType => _gestureType;
  Map<String, double> get handPosition => _handPosition;
  Map<String, double> get handBox => _handBox;
  bool get isHandDetected => _isHandDetected;
  bool get isModelFeatureTesterLoading => _isModelFeatureTesterLoading;
  bool get isModelFeatureTesterReady => _isModelFeatureTesterReady;
  String? get modelFeatureTesterError => _modelFeatureTesterError;
  TfliteModelSummary? get modelSummary => _modelSummary;
  TfliteModelProbeResult? get syntheticProbeResult => _syntheticProbeResult;

  Future<void> ensureModelFeatureTesterInitialized() async {
    if (_isModelFeatureTesterReady || _isModelFeatureTesterLoading) {
      return;
    }

    _isModelFeatureTesterLoading = true;
    _modelFeatureTesterError = null;
    notifyListeners();

    try {
      final summary = await _modelFeatureTester.describe();
      _modelSummary = summary;
      _syntheticProbeResult = null;

      if (_supportsSyntheticProbe(summary)) {
        final labels = await _loadModelLabels(summary.classCount);
        final probe = await _modelFeatureTester.runSyntheticProbe(
          randomize: true,
          randomSeed: DateTime.now().millisecondsSinceEpoch,
          labelsOverride: labels.isNotEmpty ? labels : null,
        );
        _syntheticProbeResult = probe;
      } else {
        debugPrint(
          'Synthetic probe skipped: model input shape ${summary.inputTensors.isNotEmpty ? summary.inputTensors.first.shape : []} not supported.',
        );
      }

      _isModelFeatureTesterReady = true;
    } catch (e) {
      debugPrint('Failed to initialize model feature tester: $e');
      _modelFeatureTesterError = e.toString();
      _isModelFeatureTesterReady = false;
    } finally {
      _isModelFeatureTesterLoading = false;
      notifyListeners();
    }
  }

  Future<void> _ensureBridgeInitialized() async {
    if (_isBridgeReady) return;
    try {
      await _handsBridge.initialize(
        movenetModelAsset: 'assets/currently_use/movenet_thunder.tflite',
        handTaskAsset: 'assets/currently_use/hand_landmarker.task',
      );
      await _ensureCompactScaler();
      _compactBuilder ??= CompactFeatureBuilder(
        scalerMean: _compactScalerMean,
        scalerStd: _compactScalerStd,
      );
      debugPrint(
          '#required bridge=initialized movenet=assets/models/movenet_thunder.tflite hands=assets/models/hand_landmarker.task scalerLoaded=$_scalerLoaded');
      _isBridgeReady = true;
    } catch (error) {
      debugPrint('Failed to initialize MoveNet+Hands bridge: $error');
      _isBridgeReady = false;
    }
  }

  List<double>? _compactScalerMean;
  List<double>? _compactScalerStd;

  Future<void> _ensureCompactScaler() async {
    if (_scalerLoaded) return;
    _scalerLoaded = true;
    try {
      final String jsonStr =
          await rootBundle.loadString('assets/currently_use/compact_scaler.json');
      final Map<String, dynamic> data =
          json.decode(jsonStr) as Map<String, dynamic>;
      final List<dynamic>? meanRaw = data['mean'] as List<dynamic>?;
      final List<dynamic>? stdRaw = data['std'] as List<dynamic>?;
      if (meanRaw != null && stdRaw != null) {
        _compactScalerMean =
            meanRaw.map((e) => (e as num).toDouble()).toList(growable: false);
        _compactScalerStd =
            stdRaw.map((e) => (e as num).toDouble()).toList(growable: false);
        debugPrint(
            '#required scaler=assets/models/compact_scaler.json len=${_compactScalerMean?.length ?? 0}');
      }
    } catch (error) {
      debugPrint('Failed to load compact scaler: $error');
      _compactScalerMean = null;
      _compactScalerStd = null;
    }
  }

  Future<void> initializeCamera() async {
    try {
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Camera permission not granted');
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      await _controller?.dispose();

      final int frontIndex = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      _currentCameraIndex = frontIndex != -1
          ? frontIndex
          : _currentCameraIndex.clamp(0, _cameras.length - 1);

      _controller = CameraController(
        _cameras[_currentCameraIndex],
        _cameraResolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      await _ensureBridgeInitialized();
      _isInitialized = true;
      _isFlashOn = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to initialize camera: $e');
      _isInitialized = false;
      notifyListeners();
    }
  }

  Future<void> startCamera() async {
    if (_controller == null || !_isInitialized) {
      debugPrint('Camera not ready to start.');
      return;
    }
    if (_isCameraActive) return;

    try {
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }

      TfliteInferenceService.reset();
      await _ensureBridgeInitialized();

      await _controller!.startImageStream(_onImageFrame);
      _isCameraActive = true;
      _setWaitingState('Mengumpulkan data...');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to start camera: $e');
      _isCameraActive = false;
      notifyListeners();
    }
  }

  Future<void> stopCamera() async {
    if (_controller == null || !_isCameraActive) return;

    try {
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
      try {
        await _controller!.setFlashMode(FlashMode.off);
      } catch (_) {}
    } catch (e) {
      debugPrint('Failed to stop camera stream: $e');
    } finally {
      _isCameraActive = false;
      _isFlashOn = false;
      _isProcessingFrame = false;
      _lastFrameAt = null;
      TfliteInferenceService.reset();
      _sentenceBuilder.reset();
      _setWaitingState('Kamera dihentikan');
      notifyListeners();
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) {
      debugPrint('Only one camera available.');
      return;
    }

    final bool wasActive = _isCameraActive;

    await stopCamera();
    await _controller?.dispose();

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    _isInitialized = false;
    _isFlashOn = false;

    _controller = CameraController(
      _cameras[_currentCameraIndex],
      _cameraResolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      _isInitialized = true;
      notifyListeners();

      if (wasActive) {
        await startCamera();
      }
    } catch (e) {
      debugPrint('Failed to switch camera: $e');
      _isInitialized = false;
      notifyListeners();
    }
  }

  Future<void> toggleFlash() async {
    if (_controller == null || !_isInitialized) return;

    try {
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
        _isFlashOn = false;
      } else {
        await _controller!.setFlashMode(FlashMode.torch);
        _isFlashOn = true;
      }
      notifyListeners();
    } on CameraException catch (e) {
      debugPrint('Flash not supported: $e');
      _isFlashOn = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to toggle flash: $e');
      _isFlashOn = false;
      notifyListeners();
    }
  }

  Future<void> _onImageFrame(CameraImage image) async {
    if (!_isCameraActive || !_isInitialized) return;
    if (_isProcessingFrame) return;

    final DateTime now = DateTime.now();
    if (_lastFrameAt != null &&
        now.difference(_lastFrameAt!) < _minFrameInterval) {
      return;
    }

    _isProcessingFrame = true;
    _lastFrameAt = now;

    try {
      LandmarkPacket? packet = await _handsBridge.processFrame(image);
      if (packet == null) {
        _setWaitingState('Menunggu deteksi tangan');
        notifyListeners();
        return;
      }
      packet = _normalizeHandedness(packet);
      final bool handPresent =
          _hasNonZero(packet.leftHand) || _hasNonZero(packet.rightHand);

      if (_compactBuilder == null) {
        _setWaitingState('Pengolah fitur belum siap');
        notifyListeners();
        return;
      }

      if (kDebugMode) {
        final samplePose = packet.pose.take(8).toList();
        final sampleLeft = packet.leftHand.take(8).toList();
        final sampleRight = packet.rightHand.take(8).toList();
        debugPrint(
          '#bridge pose(${packet.pose.length}) sample=$samplePose left(${packet.leftHand.length}) sample=$sampleLeft right(${packet.rightHand.length}) sample=$sampleRight',
        );
      }

      _compactBuilder?.addPacket(packet);
      final features = _compactBuilder?.buildFeatureVector();

      final int expectedLen = TfliteInferenceService.featureLength;
      if (features == null ||
          (expectedLen > 0 && features.length != expectedLen)) {
        if (kDebugMode) {
          debugPrint(
              '#wait featuresLen=${features?.length ?? 0} expected=$expectedLen seqLen=${TfliteInferenceService.sequenceLength}');
        }
        _setWaitingState('Mengumpulkan data...');
        notifyListeners();
        return;
      }

      final Map<String, dynamic> result =
          await TfliteInferenceService.processPoseFeatures(features);

      // Override hand presence based on landmark availability, not just model confidence.
      result['isHandDetected'] = handPresent;

      if (result['ready'] != true) {
        _setWaitingState(
            result['message']?.toString() ?? 'Menunggu prediksi...');
        notifyListeners();
        return;
      }

      result['boundingBox'] ??= _handBox;
      result['handPosition'] ??= _handPosition;
      result['isHandDetected'] ??= true;

      _applyDetection(result);
      notifyListeners();
    } catch (e) {
      debugPrint('Error during frame processing: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  bool _supportsSyntheticProbe(TfliteModelSummary summary) {
    if (summary.inputTensors.isEmpty) {
      return false;
    }
    final List<int> shape = summary.inputTensors.first.shape;
    if (shape.isEmpty) {
      return false;
    }

    if (shape.length == 3) {
      return summary.sequenceLength > 0 && summary.featureLength > 0;
    }

    return false;
  }

  Future<List<String>> _loadModelLabels(int classCount) async {
    final int expected = classCount > 0 ? classCount : 1;
    try {
      final String jsonStr =
          await rootBundle.loadString('assets/currently_use/sibi_compact_labels.json');
      // await rootBundle.loadString('assets/models/label_map.json');
      final dynamic decoded = json.decode(jsonStr);
      final List<String> labels = List<String>.filled(expected, '');

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
      return labels;
    } catch (error) {
      debugPrint('Failed to load label map for feature tester: $error');
      return List<String>.generate(
        expected,
        (index) => 'Class ${index + 1}',
      );
    }
  }

  void _applyDetection(Map<String, dynamic> detection) {
    final bool detected = detection['isHandDetected'] == true;
    final double confidence = (detection['confidence'] ?? 0.0).toDouble();
    final String label = detection['label']?.toString() ?? '';
    final Map<String, dynamic> handPos =
        detection['handPosition'] as Map<String, dynamic>? ?? {};
    final Map<String, dynamic> box =
        detection['boundingBox'] as Map<String, dynamic>? ?? {};

    if (!detected) {
      _isHandDetected = false;
      _confidence = confidence;
      _recognizedText =
          label.isNotEmpty ? '$label (low confidence)' : 'Tidak ada prediksi';
      _gestureType = label.toLowerCase().replaceAll(' ', '_');
      _handPosition = {'x': 0.5, 'y': 0.5};
      _handBox = {
        'left': 0.3,
        'top': 0.18,
        'width': 0.4,
        'height': 0.55,
      };
      return;
    }

      _isHandDetected = true;
    _confidence = confidence;

    final String normalized = label.toLowerCase().trim();
    if (normalized == _blankLabel) {
      _sentenceBuilder.reset();
      _recognizedText = label;
    } else {
      // Bangun kalimat sederhana dari kata-kata yang terdeteksi.
      final String phrase = _sentenceBuilder.addWord(label, confidence);
      _recognizedText = phrase.isNotEmpty ? phrase : label;
    }

    _gestureType = normalized.replaceAll(' ', '_');
    _handPosition = {
      'x': (handPos['x'] ?? 0.5).toDouble().clamp(0.0, 1.0),
      'y': (handPos['y'] ?? 0.5).toDouble().clamp(0.0, 1.0),
    };
    _handBox = {
      'left': (box['left'] ?? 0.3).toDouble().clamp(0.0, 1.0),
      'top': (box['top'] ?? 0.18).toDouble().clamp(0.0, 1.0),
      'width': (box['width'] ?? 0.4).toDouble().clamp(0.0, 1.0),
      'height': (box['height'] ?? 0.55).toDouble().clamp(0.0, 1.0),
    };
  }

  void _setWaitingState(String message) {
    _isHandDetected = false;
    _confidence = 0.0;
    _recognizedText = message;
    _gestureType = 'waiting';
  }

  LandmarkPacket _normalizeHandedness(LandmarkPacket packet) {
    // By default gunakan handedness asli dari MediaPipe Hands/MoveNet.
    // Jika perlu pembalikan untuk perspektif mirror, ubah _swapFrontHands menjadi true.
    const bool _swapFrontHands = false;
    final bool isFront = _cameras.isNotEmpty &&
        _cameras[_currentCameraIndex].lensDirection == CameraLensDirection.front;
    if (!isFront || !_swapFrontHands) return packet;
    return LandmarkPacket(
      pose: packet.pose,
      leftHand: packet.rightHand,
      rightHand: packet.leftHand,
      width: packet.width,
      height: packet.height,
      timestampMs: packet.timestampMs,
    );
  }

  bool _hasNonZero(List<double> values) {
    for (final v in values) {
      if (v != 0.0) return true;
    }
    return false;
  }

  @override
  void dispose() {
    unawaited(stopCamera());
    unawaited(_modelFeatureTester.dispose());
    unawaited(_handsBridge.dispose());
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}
