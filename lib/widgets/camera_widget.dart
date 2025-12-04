import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../providers/camera_provider.dart';

class CameraWidget extends StatefulWidget {
  const CameraWidget({super.key});

  @override
  State<CameraWidget> createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget> {
  CameraProvider? _cameraProvider;

  String _fallbackRecognitionMessage(CameraProvider provider) {
    final String text = provider.recognizedText.trim();
    if (text.isEmpty || text == 'Menunggu kamera...') {
      return 'Tunjukkan tangan Anda ke kamera';
    }
    return text;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _cameraProvider = context.read<CameraProvider>();
      await _initializeAndStartCamera();
      _cameraProvider!.ensureModelFeatureTesterInitialized();
    });
  }

  @override
  void dispose() {
    // Safely dispose camera without accessing context
    _cameraProvider?.stopCamera();
    super.dispose();
  }

  Future<void> _initializeAndStartCamera() async {
    if (_cameraProvider == null) return;
    if (!_cameraProvider!.isInitialized) {
      await _cameraProvider!.initializeCamera();
    }
    if (_cameraProvider!.isInitialized && !_cameraProvider!.isCameraActive) {
      await _cameraProvider!.startCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraProvider>(
      builder: (context, cameraProvider, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: Stack(
            children: [
              // Camera preview - maintain aspect ratio
              if (cameraProvider.isInitialized &&
                  cameraProvider.controller != null)
                Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.15,
                  ),
                  width: double.infinity,
                  child: CameraPreview(cameraProvider.controller!),
                )
              else
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFFFF6B35), // Changed to orange
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Menginisialisasi kamera...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),

              // Camera controls at top right
              if (cameraProvider.isInitialized &&
                  cameraProvider.controller != null)
                Positioned(
                  top: 60,
                  right: 20,
                  child: Row(
                    children: [
                      // Switch camera button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () => cameraProvider.switchCamera(),
                          icon: const Icon(
                            Icons.flip_camera_ios_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Flash toggle button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () => cameraProvider.toggleFlash(),
                          icon: Icon(
                            cameraProvider.isFlashOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Recognition result at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildCompactRecognitionResult(cameraProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactRecognitionResult(CameraProvider cameraProvider) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFFFF6B35).withOpacity(0.2), // Changed to orange
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35)
                      .withOpacity(0.1), // Changed to orange
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFFF6B35), // Changed to orange
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Hasil Pengenalan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Recognition result powered by on-device TFLite inference
          if (cameraProvider.isHandDetected &&
              cameraProvider.recognizedText.isNotEmpty)
            Column(
              children: [
                Text(
                  cameraProvider.recognizedText,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.memory_rounded,
                      color: Color(0xFF4CAF50),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'TensorFlow Lite',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else if (cameraProvider.gestureType == 'waiting')
            Column(
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFFFF6B35),
                  strokeWidth: 2,
                ),
                const SizedBox(height: 12),
                Text(
                  cameraProvider.recognizedText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          else if (cameraProvider.gestureType == 'error')
            Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFFF6B35),
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  cameraProvider.recognizedText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFF6B35),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          else
            Column(
              children: [
                const Icon(
                  Icons.pan_tool_outlined,
                  color: Color(0xFF666666),
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  _fallbackRecognitionMessage(cameraProvider),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.memory_rounded,
                      color: Color(0xFF4CAF50),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Powered by TensorFlow Lite',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),

          const SizedBox(height: 12),

          // Hand detection status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                cameraProvider.isHandDetected
                    ? Icons.pan_tool
                    : Icons.pan_tool_alt,
                color: cameraProvider.isHandDetected
                    ? const Color(0xFFFF6B35)
                    : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                cameraProvider.isHandDetected
                    ? 'Tangan Terdeteksi'
                    : 'Tangan Tidak Terdeteksi',
                style: TextStyle(
                  color: cameraProvider.isHandDetected
                      ? const Color(0xFFFF6B35)
                      : Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Compact confidence indicator (persentase saja)
          if (cameraProvider.isHandDetected && cameraProvider.confidence > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _getConfidenceColor(cameraProvider.confidence),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(cameraProvider.confidence * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return const Color(0xFF00C851);
    if (confidence >= 0.7) return const Color(0xFFFF8C00);
    return const Color(0xFFFF4444);
  }
}
