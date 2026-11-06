import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

import '../../../app/theme.dart';
import '../../../core/localization/app_localizations.dart';

class PdfSignatureScreen extends StatefulWidget {
  final String pageImagePath;
  final String? documentId;

  const PdfSignatureScreen({
    super.key,
    required this.pageImagePath,
    this.documentId,
  });

  @override
  State<PdfSignatureScreen> createState() => _PdfSignatureScreenState();
}

class _PdfSignatureScreenState extends State<PdfSignatureScreen> {
  final List<List<Offset>> _strokes = [];
  final GlobalKey _canvasKey = GlobalKey();

  Color _selectedColor = const Color(0xFF1E3A8A); // Executive Navy
  double _strokeWidth = 3.5;
  bool _isSaving = false;

  void _clear() {
    setState(() {
      _strokes.clear();
    });
  }

  Future<void> _applySignature() async {
    if (_strokes.isEmpty || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      // 1. Render signature to image
      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final uiImage = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final signBytes = byteData.buffer.asUint8List();

      // 2. Composite signature onto document image
      final pageFile = File(widget.pageImagePath);
      final pageBytes = await pageFile.readAsBytes();
      final pageImage = img.decodeImage(pageBytes);
      final signImage = img.decodeImage(signBytes);

      if (pageImage != null && signImage != null) {
        // Stamp at bottom-right of page
        final targetW = (pageImage.width * 0.45).round();
        final resizedSign = img.copyResize(signImage, width: targetW);

        final posX = pageImage.width - resizedSign.width - (pageImage.width * 0.08).round();
        final posY = pageImage.height - resizedSign.height - (pageImage.height * 0.08).round();

        img.compositeImage(pageImage, resizedSign, dstX: posX, dstY: posY);

        final mergedBytes = img.encodeJpg(pageImage, quality: 90);
        await pageFile.writeAsBytes(mergedBytes);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error stamping signature: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('signatureTitle')),
        actions: [
          TextButton(
            onPressed: _strokes.isEmpty ? null : _clear,
            child: Text(l10n.t('clearSignature')),
          ),
          ElevatedButton(
            onPressed: _strokes.isEmpty || _isSaving ? null : _applySignature,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(l10n.t('saveSignature')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              l10n.t('signInstruction'),
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                fontSize: 14,
              ),
            ),
          ),

          // Interactive Signature Pad
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: Colors.white,
                  child: RepaintBoundary(
                    key: _canvasKey,
                    child: GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _strokes.add([details.localPosition]);
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          _strokes.last.add(details.localPosition);
                        });
                      },
                      child: CustomPaint(
                        painter: SignaturePainter(
                          strokes: _strokes,
                          color: _selectedColor,
                          strokeWidth: _strokeWidth,
                        ),
                        child: Container(
                          color: Colors.transparent,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Tools: Ink colors and stroke thickness
          Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 14,
              bottom: MediaQuery.of(context).padding.bottom + 14,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildColorButton(const Color(0xFF1E3A8A)), // Navy Blue
                    const SizedBox(width: 10),
                    _buildColorButton(const Color(0xFF0F172A)), // Black
                    const SizedBox(width: 10),
                    _buildColorButton(const Color(0xFFDC2626)), // Red
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.line_weight_rounded, size: 20),
                    Slider(
                      value: _strokeWidth,
                      min: 1.5,
                      max: 7.0,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _strokeWidth = val),
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

  Widget _buildColorButton(Color color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.secondary : Colors.grey.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  SignaturePainter({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dotted baseline guide
    final guidePaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(24, size.height * 0.75),
      Offset(size.width - 24, size.height * 0.75),
      guidePaint,
    );

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => true;
}
