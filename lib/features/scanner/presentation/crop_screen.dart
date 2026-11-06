import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../../app/theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/perspective_service.dart';
import '../../../core/services/storage_service.dart';
import 'enhancement_screen.dart';

class CropScreen extends StatefulWidget {
  final String rawImagePath;
  final String? targetDocumentId;
  final int batchIndex;
  final int totalBatch;
  final VoidCallback? onFinishBatch;

  const CropScreen({
    super.key,
    required this.rawImagePath,
    this.targetDocumentId,
    this.batchIndex = 1,
    this.totalBatch = 1,
    this.onFinishBatch,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  Uint8List? _imageBytes;
  img.Image? _decodedImage;
  bool _isLoading = true;
  bool _isProcessingWarp = false;

  // Normalized quad corners (0.0 to 1.0)
  Offset _tl = const Offset(0.08, 0.08);
  Offset _tr = const Offset(0.92, 0.08);
  Offset _br = const Offset(0.92, 0.92);
  Offset _bl = const Offset(0.08, 0.92);

  // Active handle being dragged
  int? _activeCornerIndex; // 0=tl, 1=tr, 2=br, 3=bl
  Offset? _touchPosition;

  int _currentRotation = 0; // 0, 90, 180, 270

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final file = File(widget.rawImagePath);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded != null) {
        // Auto-detect corners
        final detected = PerspectiveService.detectDocumentCorners(decoded);
        setState(() {
          _imageBytes = bytes;
          _decodedImage = decoded;
          _tl = detected.topLeft;
          _tr = detected.topRight;
          _br = detected.bottomRight;
          _bl = detected.bottomLeft;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading image for crop: $e');
      setState(() => _isLoading = false);
    }
  }

  void _rotateImage(bool clockwise) {
    if (_decodedImage == null) return;
    setState(() {
      _currentRotation = (_currentRotation + (clockwise ? 90 : -90)) % 360;
      if (_currentRotation < 0) _currentRotation += 360;
      _decodedImage = img.copyRotate(_decodedImage!, angle: clockwise ? 90 : -90);
      _imageBytes = Uint8List.fromList(img.encodeJpg(_decodedImage!));
    });
  }

  void _resetToFull() {
    setState(() {
      _tl = const Offset(0.02, 0.02);
      _tr = const Offset(0.98, 0.02);
      _br = const Offset(0.98, 0.98);
      _bl = const Offset(0.02, 0.98);
    });
  }

  void _autoDetectCorners() {
    if (_decodedImage == null) return;
    HapticFeedback.mediumImpact();
    final detected = PerspectiveService.detectDocumentCorners(_decodedImage!);
    setState(() {
      _tl = detected.topLeft;
      _tr = detected.topRight;
      _br = detected.bottomRight;
      _bl = detected.bottomLeft;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document edges auto-detected'),
        duration: Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _applyPerspectiveAndContinue() async {
    if (_decodedImage == null || _isProcessingWarp) return;

    try {
      setState(() => _isProcessingWarp = true);

      // Denormalize points to full image resolution
      final imgW = _decodedImage!.width.toDouble();
      final imgH = _decodedImage!.height.toDouble();

      final pixelQuad = DocumentQuad(
        topLeft: Offset(_tl.dx * imgW, _tl.dy * imgH),
        topRight: Offset(_tr.dx * imgW, _tr.dy * imgH),
        bottomRight: Offset(_br.dx * imgW, _br.dy * imgH),
        bottomLeft: Offset(_bl.dx * imgW, _bl.dy * imgH),
      );

      // Perform perspective warp
      final warpedImage = PerspectiveService.warpPerspective(_decodedImage!, pixelQuad);
      final warpedBytes = Uint8List.fromList(img.encodeJpg(warpedImage, quality: 92));

      // Save warped image to local temp
      final warpedPath = await StorageService.instance.saveImageBytes(
        warpedBytes,
        sub: 'pages',
        filename: 'cropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => EnhancementScreen(
            croppedImagePath: warpedPath,
            targetDocumentId: widget.targetDocumentId,
            batchIndex: widget.batchIndex,
            totalBatch: widget.totalBatch,
            onFinishBatch: widget.onFinishBatch,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error applying perspective warp: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessingWarp = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.t('cropTitle'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: l10n.t('rotateLeft'),
            icon: const Icon(Icons.rotate_left_rounded, color: Colors.white),
            onPressed: () => _rotateImage(false),
          ),
          IconButton(
            tooltip: l10n.t('rotateRight'),
            icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
            onPressed: () => _rotateImage(true),
          ),
          IconButton(
            tooltip: l10n.t('fullImage'),
            icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
            onPressed: _resetToFull,
          ),
          IconButton(
            tooltip: l10n.t('autoDetect'),
            icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.secondary),
            onPressed: _autoDetectCorners,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Crop interactive workspace
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          if (_imageBytes == null) return const SizedBox();

                          // Calculate fitted dimensions preserving aspect ratio
                          final imgAspect = _decodedImage!.width / _decodedImage!.height;
                          final boxAspect = constraints.maxWidth / constraints.maxHeight;

                          double renderW, renderH;
                          if (imgAspect > boxAspect) {
                            renderW = constraints.maxWidth;
                            renderH = renderW / imgAspect;
                          } else {
                            renderH = constraints.maxHeight;
                            renderW = renderH * imgAspect;
                          }

                          return Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              // Background document image
                              SizedBox(
                                width: renderW,
                                height: renderH,
                                child: Image.memory(
                                  _imageBytes!,
                                  fit: BoxFit.fill,
                                ),
                              ),

                              // Quadrilateral lines & midpoints
                              SizedBox(
                                width: renderW,
                                height: renderH,
                                child: CustomPaint(
                                  painter: CropBorderPainter(
                                    tl: Offset(_tl.dx * renderW, _tl.dy * renderH),
                                    tr: Offset(_tr.dx * renderW, _tr.dy * renderH),
                                    br: Offset(_br.dx * renderW, _br.dy * renderH),
                                    bl: Offset(_bl.dx * renderW, _bl.dy * renderH),
                                  ),
                                ),
                              ),

                              // Gesture detector for moving corner handles
                              Positioned.fill(
                                child: GestureDetector(
                                  onPanStart: (details) {
                                    final pos = details.localPosition;
                                    final cornerIdx = _findClosestCorner(pos, renderW, renderH);
                                    setState(() {
                                      _activeCornerIndex = cornerIdx;
                                      _touchPosition = pos;
                                    });
                                  },
                                  onPanUpdate: (details) {
                                    if (_activeCornerIndex == null) return;
                                    final pos = details.localPosition;
                                    final normX = (pos.dx / renderW).clamp(0.0, 1.0);
                                    final normY = (pos.dy / renderH).clamp(0.0, 1.0);

                                    setState(() {
                                      _touchPosition = pos;
                                      switch (_activeCornerIndex) {
                                        case 0:
                                          _tl = Offset(normX, normY);
                                          break;
                                        case 1:
                                          _tr = Offset(normX, normY);
                                          break;
                                        case 2:
                                          _br = Offset(normX, normY);
                                          break;
                                        case 3:
                                          _bl = Offset(normX, normY);
                                          break;
                                      }
                                    });
                                  },
                                  onPanEnd: (_) {
                                    setState(() {
                                      _activeCornerIndex = null;
                                      _touchPosition = null;
                                    });
                                  },
                                ),
                              ),

                              // Corner 0: Top-Left Handle
                              _buildHandlePositioned(
                                Offset(_tl.dx * renderW, _tl.dy * renderH),
                                isActive: _activeCornerIndex == 0,
                              ),
                              // Corner 1: Top-Right Handle
                              _buildHandlePositioned(
                                Offset(_tr.dx * renderW, _tr.dy * renderH),
                                isActive: _activeCornerIndex == 1,
                              ),
                              // Corner 2: Bottom-Right Handle
                              _buildHandlePositioned(
                                Offset(_br.dx * renderW, _br.dy * renderH),
                                isActive: _activeCornerIndex == 2,
                              ),
                              // Corner 3: Bottom-Left Handle
                              _buildHandlePositioned(
                                Offset(_bl.dx * renderW, _bl.dy * renderH),
                                isActive: _activeCornerIndex == 3,
                              ),

                              // Zoom Magnifier Loupe above touch position
                              if (_activeCornerIndex != null && _touchPosition != null)
                                Positioned(
                                  left: (_touchPosition!.dx - 55).clamp(10, renderW - 110),
                                  top: (_touchPosition!.dy - 120).clamp(10, renderH - 110),
                                  child: _buildMagnifierLoupe(renderW, renderH),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Bottom instructions and action buttons
                Container(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF111827),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.crop_rotate_rounded, color: AppColors.secondary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.t('cropInstruction'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Crop Toolbar: Auto Detect, Full Area, Rotate Left, Rotate Right
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            TextButton.icon(
                              onPressed: _autoDetectCorners,
                              icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.secondary, size: 18),
                              label: Text(
                                l10n.t('autoDetect'),
                                style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.secondary.withOpacity(0.15),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.t('fullImage'),
                              icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                              onPressed: _resetToFull,
                            ),
                            IconButton(
                              tooltip: l10n.t('rotateLeft'),
                              icon: const Icon(Icons.rotate_left_rounded, color: Colors.white),
                              onPressed: () => _rotateImage(false),
                            ),
                            IconButton(
                              tooltip: l10n.t('rotateRight'),
                              icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
                              onPressed: () => _rotateImage(true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white38),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                l10n.t('retake'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _isProcessingWarp ? null : _applyPerspectiveAndContinue,
                              child: _isProcessingWarp
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          l10n.t('continue'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  int _findClosestCorner(Offset touch, double w, double h) {
    final corners = [
      Offset(_tl.dx * w, _tl.dy * h),
      Offset(_tr.dx * w, _tr.dy * h),
      Offset(_br.dx * w, _br.dy * h),
      Offset(_bl.dx * w, _bl.dy * h),
    ];

    int closest = 0;
    double minD = double.infinity;
    for (int i = 0; i < 4; i++) {
      final dx = corners[i].dx - touch.dx;
      final dy = corners[i].dy - touch.dy;
      final d = dx * dx + dy * dy;
      if (d < minD) {
        minD = d;
        closest = i;
      }
    }
    return closest;
  }

  Widget _buildHandlePositioned(Offset pos, {bool isActive = false}) {
    return Positioned(
      left: pos.dx - 18,
      top: pos.dy - 18,
      child: IgnorePointer(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.secondary : AppColors.primary,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: (isActive ? AppColors.secondary : AppColors.primary).withOpacity(0.5),
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMagnifierLoupe(double renderW, double renderH) {
    if (_imageBytes == null) return const SizedBox();
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 12),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: 2.2,
            alignment: Alignment(
              ((_touchPosition!.dx / renderW) * 2) - 1,
              ((_touchPosition!.dy / renderH) * 2) - 1,
            ),
            child: Image.memory(
              _imageBytes!,
              fit: BoxFit.fill,
            ),
          ),
          // Crosshair
          const Icon(Icons.add, color: AppColors.secondary, size: 28),
        ],
      ),
    );
  }
}

/// Custom painter for quadrilateral borders and mid-point bars
class CropBorderPainter extends CustomPainter {
  final Offset tl;
  final Offset tr;
  final Offset br;
  final Offset bl;

  CropBorderPainter({
    required this.tl,
    required this.tr,
    required this.br,
    required this.bl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    // Dark tint outside selection
    final bgPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addPath(path, Offset.zero)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(bgPath, Paint()..color = Colors.black.withOpacity(0.45));

    // Cyan border line
    final linePaint = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    // Midpoint bar handles
    final midPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    void drawMidBar(Offset p1, Offset p2) {
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final len = sqrt(dx * dx + dy * dy);
      if (len == 0) return;
      final ux = dx / len;
      final uy = dy / len;
      canvas.drawLine(
        Offset(mid.dx - ux * 10, mid.dy - uy * 10),
        Offset(mid.dx + ux * 10, mid.dy + uy * 10),
        midPaint,
      );
    }

    drawMidBar(tl, tr);
    drawMidBar(tr, br);
    drawMidBar(br, bl);
    drawMidBar(bl, tl);
  }

  @override
  bool shouldRepaint(covariant CropBorderPainter oldDelegate) => true;
}
