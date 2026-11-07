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

  // Active handle being dragged:
  // 0..3: Corners (TL, TR, BR, BL), 4..7: Edges (Top, Right, Bottom, Left), 8: Body Pan
  int? _activeTarget;
  Offset? _lastPanPos;
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
    HapticFeedback.lightImpact();
    setState(() {
      _tl = const Offset(0.01, 0.01);
      _tr = const Offset(0.99, 0.01);
      _br = const Offset(0.99, 0.99);
      _bl = const Offset(0.01, 0.99);
    });
  }

  void _resetToDocumentFit() {
    HapticFeedback.lightImpact();
    setState(() {
      _tl = const Offset(0.06, 0.06);
      _tr = const Offset(0.94, 0.06);
      _br = const Offset(0.94, 0.94);
      _bl = const Offset(0.06, 0.94);
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

  void _updateHandleDelta(int target, double dx, double dy) {
    setState(() {
      switch (target) {
        case 0: // Top-Left corner
          final newX = (_tl.dx + dx).clamp(0.0, _tr.dx - 0.05);
          final newY = (_tl.dy + dy).clamp(0.0, _bl.dy - 0.05);
          _tl = Offset(newX, newY);
          break;
        case 1: // Top-Right corner
          final newX = (_tr.dx + dx).clamp(_tl.dx + 0.05, 1.0);
          final newY = (_tr.dy + dy).clamp(0.0, _br.dy - 0.05);
          _tr = Offset(newX, newY);
          break;
        case 2: // Bottom-Right corner
          final newX = (_br.dx + dx).clamp(_bl.dx + 0.05, 1.0);
          final newY = (_br.dy + dy).clamp(_tr.dy + 0.05, 1.0);
          _br = Offset(newX, newY);
          break;
        case 3: // Bottom-Left corner
          final newX = (_bl.dx + dx).clamp(0.0, _br.dx - 0.05);
          final newY = (_bl.dy + dy).clamp(_tl.dy + 0.05, 1.0);
          _bl = Offset(newX, newY);
          break;
        case 4: // Top Edge
          final newTlY = (_tl.dy + dy).clamp(0.0, _bl.dy - 0.05);
          final newTrY = (_tr.dy + dy).clamp(0.0, _br.dy - 0.05);
          _tl = Offset(_tl.dx, newTlY);
          _tr = Offset(_tr.dx, newTrY);
          break;
        case 5: // Right Edge
          final newTrX = (_tr.dx + dx).clamp(_tl.dx + 0.05, 1.0);
          final newBrX = (_br.dx + dx).clamp(_bl.dx + 0.05, 1.0);
          _tr = Offset(newTrX, _tr.dy);
          _br = Offset(newBrX, _br.dy);
          break;
        case 6: // Bottom Edge
          final newBlY = (_bl.dy + dy).clamp(_tl.dy + 0.05, 1.0);
          final newBrY = (_br.dy + dy).clamp(_tr.dy + 0.05, 1.0);
          _bl = Offset(_bl.dx, newBlY);
          _br = Offset(_br.dx, newBrY);
          break;
        case 7: // Left Edge
          final newTlX = (_tl.dx + dx).clamp(0.0, _tr.dx - 0.05);
          final newBlX = (_bl.dx + dx).clamp(0.0, _br.dx - 0.05);
          _tl = Offset(newTlX, _tl.dy);
          _bl = Offset(newBlX, _bl.dy);
          break;
        case 8: // Entire Box Move
          final minX = min(min(_tl.dx, _tr.dx), min(_bl.dx, _br.dx));
          final maxX = max(max(_tl.dx, _tr.dx), max(_bl.dx, _br.dx));
          final minY = min(min(_tl.dy, _tr.dy), min(_bl.dy, _br.dy));
          final maxY = max(max(_tl.dy, _tr.dy), max(_bl.dy, _br.dy));

          final safeDx = dx.clamp(-minX, 1.0 - maxX);
          final safeDy = dy.clamp(-minY, 1.0 - maxY);

          _tl = Offset(_tl.dx + safeDx, _tl.dy + safeDy);
          _tr = Offset(_tr.dx + safeDx, _tr.dy + safeDy);
          _br = Offset(_br.dx + safeDx, _br.dy + safeDy);
          _bl = Offset(_bl.dx + safeDx, _bl.dy + safeDy);
          break;
      }
    });
  }

  int _findHitTarget(Offset touch, double w, double h) {
    final corners = [
      Offset(_tl.dx * w, _tl.dy * h),
      Offset(_tr.dx * w, _tr.dy * h),
      Offset(_br.dx * w, _br.dy * h),
      Offset(_bl.dx * w, _bl.dy * h),
    ];

    // 1. Check corners (48dp touch radius)
    for (int i = 0; i < 4; i++) {
      if ((touch - corners[i]).distance <= 48.0) {
        return i;
      }
    }

    // 2. Check edge midpoints (40dp touch radius)
    final edges = [
      Offset((_tl.dx + _tr.dx) * 0.5 * w, (_tl.dy + _tr.dy) * 0.5 * h),
      Offset((_tr.dx + _br.dx) * 0.5 * w, (_tr.dy + _br.dy) * 0.5 * h),
      Offset((_bl.dx + _br.dx) * 0.5 * w, (_bl.dy + _br.dy) * 0.5 * h),
      Offset((_tl.dx + _bl.dx) * 0.5 * w, (_tl.dy + _bl.dy) * 0.5 * h),
    ];
    for (int i = 0; i < 4; i++) {
      if ((touch - edges[i]).distance <= 40.0) {
        return 4 + i;
      }
    }

    // 3. Check inside box
    if (_isInsideQuad(touch, corners)) {
      return 8;
    }

    // 4. Check closest corner if reasonably close
    int closest = -1;
    double minD = double.infinity;
    for (int i = 0; i < 4; i++) {
      final d = (touch - corners[i]).distance;
      if (d < minD) {
        minD = d;
        closest = i;
      }
    }
    return minD <= 64.0 ? closest : -1;
  }

  bool _isInsideQuad(Offset p, List<Offset> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      if (((poly[i].dy > p.dy) != (poly[j].dy > p.dy)) &&
          (p.dx < (poly[j].dx - poly[i].dx) * (p.dy - poly[i].dy) / (poly[j].dy - poly[i].dy) + poly[i].dx)) {
        inside = !inside;
      }
    }
    return inside;
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.t('cropTitle'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: l10n.t('fullImage'),
            icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
            onPressed: _resetToFull,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

                          final tlPix = Offset(_tl.dx * renderW, _tl.dy * renderH);
                          final trPix = Offset(_tr.dx * renderW, _tr.dy * renderH);
                          final brPix = Offset(_br.dx * renderW, _br.dy * renderH);
                          final blPix = Offset(_bl.dx * renderW, _bl.dy * renderH);

                          final topMidPix = Offset((tlPix.dx + trPix.dx) * 0.5, (tlPix.dy + trPix.dy) * 0.5);
                          final rightMidPix = Offset((trPix.dx + brPix.dx) * 0.5, (trPix.dy + brPix.dy) * 0.5);
                          final botMidPix = Offset((blPix.dx + brPix.dx) * 0.5, (blPix.dy + brPix.dy) * 0.5);
                          final leftMidPix = Offset((tlPix.dx + blPix.dx) * 0.5, (tlPix.dy + blPix.dy) * 0.5);

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

                              // Quadrilateral lines & shadow overlay
                              SizedBox(
                                width: renderW,
                                height: renderH,
                                child: CustomPaint(
                                  painter: CropBorderPainter(
                                    tl: tlPix,
                                    tr: trPix,
                                    br: brPix,
                                    bl: blPix,
                                  ),
                                ),
                              ),

                              // Gesture detector for moving corners, edges, and body
                              Positioned.fill(
                                child: GestureDetector(
                                  onPanStart: (details) {
                                    final pos = details.localPosition;
                                    final target = _findHitTarget(pos, renderW, renderH);
                                    if (target < 0) return;
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _activeTarget = target;
                                      _lastPanPos = pos;
                                      _touchPosition = pos;
                                    });
                                  },
                                  onPanUpdate: (details) {
                                    if (_activeTarget == null || _activeTarget! < 0 || _lastPanPos == null) return;
                                    final pos = details.localPosition;
                                    final dx = (pos.dx - _lastPanPos!.dx) / renderW;
                                    final dy = (pos.dy - _lastPanPos!.dy) / renderH;
                                    _lastPanPos = pos;

                                    _updateHandleDelta(_activeTarget!, dx, dy);
                                    setState(() {
                                      _touchPosition = pos;
                                    });
                                  },
                                  onPanEnd: (_) {
                                    setState(() {
                                      _activeTarget = null;
                                      _lastPanPos = null;
                                      _touchPosition = null;
                                    });
                                  },
                                ),
                              ),

                              // 4 Edge Midpoint Handles (Draggable sides)
                              _buildEdgeHandlePositioned(topMidPix, isVertical: false, isActive: _activeTarget == 4),
                              _buildEdgeHandlePositioned(rightMidPix, isVertical: true, isActive: _activeTarget == 5),
                              _buildEdgeHandlePositioned(botMidPix, isVertical: false, isActive: _activeTarget == 6),
                              _buildEdgeHandlePositioned(leftMidPix, isVertical: true, isActive: _activeTarget == 7),

                              // 4 Corner Handles (Draggable corners)
                              _buildCornerHandlePositioned(tlPix, isActive: _activeTarget == 0),
                              _buildCornerHandlePositioned(trPix, isActive: _activeTarget == 1),
                              _buildCornerHandlePositioned(brPix, isActive: _activeTarget == 2),
                              _buildCornerHandlePositioned(blPix, isActive: _activeTarget == 3),

                              // Zoom Magnifier Loupe above touch position
                              if (_activeTarget != null && _touchPosition != null && _activeTarget! < 4)
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

                // Bottom sleek ergonomic controls
                Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 14,
                    bottom: MediaQuery.of(context).padding.bottom + 14,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF111827),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quick Tools Row (Auto, Fit, Full, Rotate)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildQuickActionBtn(
                            icon: Icons.auto_awesome_rounded,
                            label: l10n.t('autoDetect'),
                            iconColor: AppColors.secondary,
                            onTap: _autoDetectCorners,
                          ),
                          _buildQuickActionBtn(
                            icon: Icons.crop_portrait_rounded,
                            label: l10n.t('fitPage'),
                            onTap: _resetToDocumentFit,
                          ),
                          _buildQuickActionBtn(
                            icon: Icons.fullscreen_rounded,
                            label: l10n.t('fullImage'),
                            onTap: _resetToFull,
                          ),
                          _buildQuickActionBtn(
                            icon: Icons.rotate_right_rounded,
                            label: l10n.t('rotateRight'),
                            onTap: () => _rotateImage(true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Action Buttons Row (Retake & Next)
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
                          const SizedBox(width: 14),
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

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final effectiveColor = iconColor ?? Colors.white;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: effectiveColor, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: iconColor != null ? effectiveColor : Colors.white70,
                fontSize: 11,
                fontWeight: iconColor != null ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerHandlePositioned(Offset pos, {bool isActive = false}) {
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

  Widget _buildEdgeHandlePositioned(Offset pos, {required bool isVertical, bool isActive = false}) {
    return Positioned(
      left: pos.dx - (isVertical ? 7 : 18),
      top: pos.dy - (isVertical ? 18 : 7),
      child: IgnorePointer(
        child: Container(
          width: isVertical ? 14 : 36,
          height: isVertical ? 36 : 14,
          decoration: BoxDecoration(
            color: isActive ? AppColors.secondary : Colors.white,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
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

/// Custom painter for quadrilateral borders and alignment grid
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
    canvas.drawPath(bgPath, Paint()..color = Colors.black.withOpacity(0.50));

    // Subtle 3x3 alignment grid inside document quad
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 1.0;

    // Horizontal grid lines
    final h1L = Offset(tl.dx + (bl.dx - tl.dx) / 3, tl.dy + (bl.dy - tl.dy) / 3);
    final h1R = Offset(tr.dx + (br.dx - tr.dx) / 3, tr.dy + (br.dy - tr.dy) / 3);
    canvas.drawLine(h1L, h1R, gridPaint);

    final h2L = Offset(tl.dx + (bl.dx - tl.dx) * 2 / 3, tl.dy + (bl.dy - tl.dy) * 2 / 3);
    final h2R = Offset(tr.dx + (br.dx - tr.dx) * 2 / 3, tr.dy + (br.dy - tr.dy) * 2 / 3);
    canvas.drawLine(h2L, h2R, gridPaint);

    // Vertical grid lines
    final v1T = Offset(tl.dx + (tr.dx - tl.dx) / 3, tl.dy + (tr.dy - tl.dy) / 3);
    final v1B = Offset(bl.dx + (br.dx - bl.dx) / 3, bl.dy + (br.dy - bl.dy) / 3);
    canvas.drawLine(v1T, v1B, gridPaint);

    final v2T = Offset(tl.dx + (tr.dx - tl.dx) * 2 / 3, tl.dy + (tr.dy - tl.dy) * 2 / 3);
    final v2B = Offset(bl.dx + (br.dx - bl.dx) * 2 / 3, bl.dy + (br.dy - bl.dy) * 2 / 3);
    canvas.drawLine(v2T, v2B, gridPaint);

    // Cyan border line
    final linePaint = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CropBorderPainter oldDelegate) =>
      oldDelegate.tl != tl || oldDelegate.tr != tr || oldDelegate.br != br || oldDelegate.bl != bl;
}
