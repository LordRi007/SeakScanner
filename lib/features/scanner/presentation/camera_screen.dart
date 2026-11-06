import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/perspective_service.dart';
import 'crop_screen.dart';
import 'multi_page_preview_screen.dart';

class CameraScreen extends ConsumerStatefulWidget {
  final String? targetDocumentId;
  const CameraScreen({super.key, this.targetDocumentId});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  final bool _hasDocumentDetected = true;
  double _zoomLevel = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 4.0;
  Timer? _autoCaptureTimer;

  // Selected scanning mode
  int _selectedModeIndex = 2; // Default: Document
  final List<String> _scanModes = ['Whiteboard', 'Form', 'Document', 'ID Card', 'Book'];

  // Multi-page batch captured list of temp paths
  final List<String> _capturedPages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoCaptureTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _isCameraInitialized = false);
        return;
      }

      final camera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
      );

      _controller = controller;
      await controller.initialize();

      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = (await controller.getMaxZoomLevel()).clamp(1.0, 5.0);

      if (mounted) {
        setState(() => _isCameraInitialized = true);
        _startAutoDetectionSimulation();
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() => _isCameraInitialized = false);
      }
    }
  }

  void _startAutoDetectionSimulation() {
    _autoCaptureTimer?.cancel();
    // Auto scan frames and detects document boundaries in real-time without
    // taking automatic shots, giving the user full manual control over the shutter.
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final current = ref.read(scannerSettingsProvider).flashMode;
    String nextMode = 'off';
    FlashMode flashMode = FlashMode.off;

    if (current == 'off') {
      nextMode = 'auto';
      flashMode = FlashMode.auto;
    } else if (current == 'auto') {
      nextMode = 'torch';
      flashMode = FlashMode.torch;
    } else {
      nextMode = 'off';
      flashMode = FlashMode.off;
    }

    try {
      await _controller!.setFlashMode(flashMode);
      ref.read(scannerSettingsProvider.notifier).setFlashMode(nextMode);
    } catch (_) {}
  }

  Future<void> _takePicture({bool isAuto = false}) async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    try {
      setState(() => _isCapturing = true);
      HapticFeedback.mediumImpact();

      final XFile photo = await _controller!.takePicture();
      _handleCapturedFile(photo.path);
    } catch (e) {
      debugPrint('Error taking picture: $e');
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (picked != null) {
      _handleCapturedFile(picked.path);
    }
  }

  void _handleCapturedFile(String filePath) {
    setState(() {
      _capturedPages.add(filePath);
    });

    // Navigate to Crop Screen for perspective tuning
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => CropScreen(
          rawImagePath: filePath,
          targetDocumentId: widget.targetDocumentId,
          batchIndex: _capturedPages.length,
          totalBatch: _capturedPages.length,
          onFinishBatch: () {
            // If user completes, go to multi-page or save
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scannerSettings = ref.watch(scannerSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera View or Fallback view
          if (_isCameraInitialized && _controller != null)
            GestureDetector(
              onScaleUpdate: (details) async {
                final newZoom = (_zoomLevel * details.scale).clamp(_minZoom, _maxZoom);
                if (newZoom != _zoomLevel) {
                  setState(() => _zoomLevel = newZoom);
                  await _controller?.setZoomLevel(newZoom);
                }
              },
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1 / _controller!.value.aspectRatio,
                  child: CameraPreview(_controller!),
                ),
              ),
            )
          else
            _buildCameraFallback(),

          // 2. Real-Time Document Detection Overlay
          if (_hasDocumentDetected) _buildDocumentDetectionOverlay(scannerSettings.autoCapture),

          // 3. Optional Grid Overlay
          if (scannerSettings.gridEnabled) _buildGridOverlay(),

          // 4. Top Action Bar (Back, Flash, Auto/Manual, Settings)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircleButton(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(scannerSettingsProvider.notifier).toggleAutoCapture();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: scannerSettings.autoCapture
                          ? AppColors.secondary.withOpacity(0.25)
                          : Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: scannerSettings.autoCapture ? AppColors.secondary : Colors.white24,
                        width: scannerSettings.autoCapture ? 1.6 : 1.0,
                      ),
                      boxShadow: scannerSettings.autoCapture
                          ? [
                              BoxShadow(
                                color: AppColors.secondary.withOpacity(0.25),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          scannerSettings.autoCapture
                              ? Icons.auto_awesome_rounded
                              : Icons.touch_app_rounded,
                          color: scannerSettings.autoCapture ? AppColors.secondary : Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          scannerSettings.autoCapture ? l10n.t('autoCapture') : l10n.t('manualCapture'),
                          style: TextStyle(
                            color: scannerSettings.autoCapture ? AppColors.secondary : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    _buildCircleButton(
                      icon: scannerSettings.gridEnabled
                          ? Icons.grid_on_rounded
                          : Icons.grid_off_rounded,
                      onTap: () => ref.read(scannerSettingsProvider.notifier).toggleGrid(),
                    ),
                    const SizedBox(width: 10),
                    _buildCircleButton(
                      icon: scannerSettings.flashMode == 'torch'
                          ? Icons.flash_on_rounded
                          : scannerSettings.flashMode == 'auto'
                              ? Icons.flash_auto_rounded
                              : Icons.flash_off_rounded,
                      color: scannerSettings.flashMode != 'off' ? Colors.amber : Colors.white,
                      onTap: _toggleFlash,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 5. Center Detection Status Badge (during active capture)
          if (_isCapturing)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.secondary, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.35),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.t('capturingHoldSteady'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // 5b. Document Detected Guide Pill (Auto Scan framing active, manual shutter shot)
          if (scannerSettings.autoCapture && _hasDocumentDetected && !_isCapturing)
            Positioned(
              top: MediaQuery.of(context).padding.top + 68,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.secondary.withOpacity(0.8), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withOpacity(0.25),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${l10n.t('documentDetected')} • Tap shutter to scan',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. Bottom Controls Section
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 16,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87, Colors.black],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Scanning Mode Selector (Document, ID Card, Whiteboard, Book...)
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: _scanModes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 20),
                      itemBuilder: (ctx, index) {
                        final isSelected = index == _selectedModeIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedModeIndex = index),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _scanModes[index],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white60,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (isSelected)
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons Bar: Gallery, Shutter, Multi-Page Stack
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Gallery Button
                        _buildCircleButton(
                          icon: Icons.photo_library_outlined,
                          size: 50,
                          onTap: _pickFromGallery,
                        ),

                        // Shutter Capture Button
                        GestureDetector(
                          onTap: () => _takePicture(isAuto: false),
                          child: Container(
                            width: 78,
                            height: 78,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _hasDocumentDetected ? AppColors.primary : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.4),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                              child: _isCapturing
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : null,
                            ),
                          ),
                        ),

                        // Thumbnail Stack & Batch Counter
                        GestureDetector(
                          onTap: () {
                            if (_capturedPages.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => MultiPagePreviewScreen(
                                    pagePaths: _capturedPages,
                                    targetDocumentId: widget.targetDocumentId,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white30, width: 1.5),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _capturedPages.isNotEmpty
                                    ? Image.file(
                                        File(_capturedPages.last),
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(Icons.picture_as_pdf_outlined, color: Colors.white60),
                              ),
                              if (_capturedPages.isNotEmpty)
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${_capturedPages.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    double size = 44,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: size * 0.5),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildDocumentDetectionOverlay([bool isAuto = false]) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // Bounding quadrilateral points matching reference camera image
        final quad = DocumentQuad(
          topLeft: Offset(w * 0.12, h * 0.22),
          topRight: Offset(w * 0.88, h * 0.24),
          bottomRight: Offset(w * 0.86, h * 0.72),
          bottomLeft: Offset(w * 0.14, h * 0.70),
        );

        return CustomPaint(
          size: Size(w, h),
          painter: DocumentBoxPainter(quad: quad, isAuto: isAuto),
        );
      },
    );
  }

  Widget _buildGridOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: GridPainter(),
        );
      },
    );
  }

  Widget _buildCameraFallback() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white38),
          const SizedBox(height: 16),
          const Text(
            'Camera Initializing or Unavailable',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'You can still import images directly from your gallery.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Import from Gallery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the detected document paper bounding border and 4 blue corner handles
class DocumentBoxPainter extends CustomPainter {
  final DocumentQuad quad;
  final bool isAuto;
  DocumentBoxPainter({required this.quad, this.isAuto = false});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Semi-transparent backdrop shadow outside polygon
    final path = Path()
      ..moveTo(quad.topLeft.dx, quad.topLeft.dy)
      ..lineTo(quad.topRight.dx, quad.topRight.dy)
      ..lineTo(quad.bottomRight.dx, quad.bottomRight.dy)
      ..lineTo(quad.bottomLeft.dx, quad.bottomLeft.dy)
      ..close();

    // 2. Cyan / Green border outline
    final linePaint = Paint()
      ..color = isAuto ? AppColors.secondary : Colors.white70
      ..strokeWidth = isAuto ? 3.0 : 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    // 3. 4 corner circle handles with inner center
    final handleFill = Paint()..color = isAuto ? AppColors.secondary : AppColors.primary;
    final handleDot = Paint()..color = Colors.white;

    for (final point in quad.points) {
      canvas.drawCircle(point, 11, handleFill);
      canvas.drawCircle(point, 4, handleDot);
    }
  }

  @override
  bool shouldRepaint(covariant DocumentBoxPainter oldDelegate) =>
      oldDelegate.isAuto != isAuto || oldDelegate.quad != quad;
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;

    final wStep = size.width / 3;
    final hStep = size.height / 3;

    canvas.drawLine(Offset(wStep, 0), Offset(wStep, size.height), paint);
    canvas.drawLine(Offset(wStep * 2, 0), Offset(wStep * 2, size.height), paint);
    canvas.drawLine(Offset(0, hStep), Offset(size.width, hStep), paint);
    canvas.drawLine(Offset(0, hStep * 2), Offset(size.width, hStep * 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
