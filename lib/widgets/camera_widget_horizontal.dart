import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/camera_provider.dart';
import '../providers/server_config_provider.dart';

class CameraWidgetHorizontal extends StatefulWidget {
  const CameraWidgetHorizontal({super.key});

  @override
  State<CameraWidgetHorizontal> createState() => _CameraWidgetHorizontalState();
}

class _CameraWidgetHorizontalState extends State<CameraWidgetHorizontal> {
  CameraProvider? _cameraProvider;

  String _fallbackRecognitionMessage(CameraProvider provider) {
    final String text = provider.recognizedText.trim();
    if (text.isEmpty || text == 'Menunggu kamera...') {
      return 'Tunjukkan tangan Anda ke kamera';
    }
    return text;
  }

  Widget _buildModeBadge(CameraProvider provider) {
    final bool online = provider.useRemote;
    final Color bg = online ? const Color(0xFF2ECC71) : const Color(0xFF95A5A6);
    final String text = online ? 'Online • GPT-5-mini' : 'Offline • Lokal';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _cameraProvider = context.read<CameraProvider>();
      final serverConfig = context.read<ServerConfigProvider>();
      final serverUrl = serverConfig.serverUrl.trim();
      bool startedRemotely = false;
      if (serverConfig.useRemote && serverUrl.isNotEmpty) {
        startedRemotely =
            await _cameraProvider!.startRemoteCamera(serverUrl);
      }
      if (!startedRemotely) {
        await _initializeAndStartCamera();
      }
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
        final orientation = MediaQuery.of(context).orientation;
        if (orientation == Orientation.portrait) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: const Center(
              child: Text(
                'Putar perangkat ke mode horizontal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: SafeArea(
            top: false,
            bottom: false,
            child: _buildCameraPane(cameraProvider),
          ),
        );
      },
    );
  }

  Widget _buildCameraPane(CameraProvider cameraProvider) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cameraWidth = screenWidth * 0.75;
    final cardWidth = (screenWidth * 0.32).clamp(280.0, 360.0);
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          if (cameraProvider.isInitialized && cameraProvider.controller != null)
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: cameraWidth,
                height: double.infinity,
                child: _buildHorizontalPreview(cameraProvider.controller!),
              ),
            )
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFFFF6B35),
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
          if (cameraProvider.isInitialized && cameraProvider.controller != null)
            Positioned(
              top: 20,
              left: 16,
              child: _circleButton(
                icon: Icons.chevron_left,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          if (cameraProvider.isInitialized && cameraProvider.controller != null)
            Positioned(
              top: 20,
              right: 16,
              child: Row(
                children: [
                  _circleButton(
                    icon: Icons.flip_camera_ios_rounded,
                    onTap: () => cameraProvider.switchCamera(),
                  ),
                  const SizedBox(width: 12),
                  _circleButton(
                    icon: cameraProvider.isFlashOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    onTap: () => cameraProvider.toggleFlash(),
                  ),
                ],
              ),
            ),
          Positioned(
            right: 16,
            top: 90,
            bottom: 24,
            child: SizedBox(
              width: cardWidth,
              child: _buildSidePanel(cameraProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel(CameraProvider cameraProvider) {
    return _buildCompactRecognitionResult(
      cameraProvider,
      dense: true,
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
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
        onPressed: onTap,
        icon: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildHorizontalPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }

    // Tampilkan preview dengan rasio video 16:9, crop otomatis (cover).
    const double targetAspect = 16 / 9;
    return AspectRatio(
      aspectRatio: targetAspect,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewSize.width,
            height: previewSize.height,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactRecognitionResult(
    CameraProvider cameraProvider, {
    bool dense = false,
  }) {
    return Container(
      width: double.infinity,
      margin: dense ? EdgeInsets.zero : const EdgeInsets.all(16),
      padding: dense ? const EdgeInsets.all(16) : const EdgeInsets.all(20),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                  decoration: TextDecoration.none,
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                    letterSpacing: 0.5,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                _buildModeBadge(cameraProvider),
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
                        decoration: TextDecoration.none,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                    fontStyle: FontStyle.italic,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFF6B35),
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                    fontStyle: FontStyle.italic,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                        decoration: TextDecoration.none,
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
                  decoration: TextDecoration.none,
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
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(cameraProvider.confidence * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      decoration: TextDecoration.none,
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
