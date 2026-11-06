import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

import '../../../app/theme.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/storage_service.dart';

enum AnnotationMode {
  addText,
  markup,
  redact,
}

class TextAnnotation {
  String text;
  Offset position; // in canvas local coordinates
  Color color;
  double fontSize;
  bool hasBackground;

  TextAnnotation({
    required this.text,
    required this.position,
    this.color = Colors.black,
    this.fontSize = 18.0,
    this.hasBackground = true,
  });
}

class MarkupStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final bool isHighlighter;

  MarkupStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isHighlighter = false,
  });
}

class RedactBox {
  final Rect rect; // in canvas local coordinates
  final bool isBlack;

  RedactBox({
    required this.rect,
    this.isBlack = true,
  });
}

class DocumentEditorScreen extends StatefulWidget {
  final String imagePath;
  final String? documentId;
  final int pageIndex;
  final AnnotationMode initialMode;

  const DocumentEditorScreen({
    super.key,
    required this.imagePath,
    this.documentId,
    this.pageIndex = 0,
    this.initialMode = AnnotationMode.markup,
  });

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  late AnnotationMode _currentMode;
  final GlobalKey _repaintKey = GlobalKey();

  // Annotations state
  final List<TextAnnotation> _textAnnotations = [];
  final List<MarkupStroke> _strokes = [];
  final List<RedactBox> _redactions = [];

  // Active drawing states
  List<Offset>? _currentStroke;
  Offset? _redactStart;
  Offset? _redactEnd;

  // Selected tools settings
  Color _selectedColor = const Color(0xFFEF4444); // default red
  double _strokeWidth = 3.5;
  bool _isHighlighter = false;
  bool _redactBlack = true; // true = black bar, false = whiteout

  bool _isSaving = false;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      if (mounted) {
        setState(() => _imageBytes = bytes);
      }
    } catch (e) {
      debugPrint('Error loading image for editor: $e');
    }
  }

  void _undo() {
    setState(() {
      switch (_currentMode) {
        case AnnotationMode.addText:
          if (_textAnnotations.isNotEmpty) _textAnnotations.removeLast();
          break;
        case AnnotationMode.markup:
          if (_strokes.isNotEmpty) _strokes.removeLast();
          break;
        case AnnotationMode.redact:
          if (_redactions.isNotEmpty) _redactions.removeLast();
          break;
      }
    });
  }

  void _clearAll() {
    setState(() {
      switch (_currentMode) {
        case AnnotationMode.addText:
          _textAnnotations.clear();
          break;
        case AnnotationMode.markup:
          _strokes.clear();
          break;
        case AnnotationMode.redact:
          _redactions.clear();
          break;
      }
    });
  }

  void _showAddTextDialog([int? editIndex]) {
    final l10n = AppLocalizations.of(context);
    final isEditing = editIndex != null;
    final initialText = isEditing ? _textAnnotations[editIndex].text : '';
    final ctrl = TextEditingController(text: initialText);
    Color textColor = isEditing ? _textAnnotations[editIndex].color : _selectedColor;
    double fontSize = isEditing ? _textAnnotations[editIndex].fontSize : 18.0;
    bool hasBg = isEditing ? _textAnnotations[editIndex].hasBackground : true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Text' : l10n.t('toolAddText')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter text...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                // Color Picker Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Colors.black,
                    const Color(0xFFEF4444),
                    const Color(0xFF2563EB),
                    const Color(0xFF10B981),
                    const Color(0xFFF59E0B),
                    Colors.white,
                  ].map((c) {
                    final isSel = textColor == c;
                    return GestureDetector(
                      onTap: () => setDialogState(() => textColor = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel ? AppColors.primary : Colors.grey.withOpacity(0.5),
                            width: isSel ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                // Font Size Slider
                Row(
                  children: [
                    const Text('Size: ', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: fontSize,
                        min: 12,
                        max: 36,
                        divisions: 12,
                        label: '${fontSize.round()}',
                        onChanged: (v) => setDialogState(() => fontSize = v),
                      ),
                    ),
                  ],
                ),
                // Background badge toggle
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Add white background box', style: TextStyle(fontSize: 13)),
                  value: hasBg,
                  onChanged: (v) => setDialogState(() => hasBg = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: () {
                  setState(() => _textAnnotations.removeAt(editIndex));
                  Navigator.pop(ctx);
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final txt = ctrl.text.trim();
                if (txt.isNotEmpty) {
                  setState(() {
                    if (isEditing) {
                      _textAnnotations[editIndex].text = txt;
                      _textAnnotations[editIndex].color = textColor;
                      _textAnnotations[editIndex].fontSize = fontSize;
                      _textAnnotations[editIndex].hasBackground = hasBg;
                    } else {
                      _textAnnotations.add(
                        TextAnnotation(
                          text: txt,
                          position: const Offset(60, 100),
                          color: textColor,
                          fontSize: fontSize,
                          hasBackground: hasBg,
                        ),
                      );
                    }
                  });
                  Navigator.pop(ctx);
                }
              },
              child: Text(l10n.t('apply')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCompositeImage() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final uiImage = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final decoded = img.decodeImage(pngBytes);
      if (decoded == null) return;

      final jpgBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));

      // Overwrite the existing page file
      final file = File(widget.imagePath);
      await file.writeAsBytes(jpgBytes, flush: true);

      // Also update thumbnail if documentId exists
      if (widget.documentId != null) {
        final thumbBytes = await StorageService.instance.saveImageBytes(
          jpgBytes,
          sub: 'pages',
          filename: 'edited_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        final pages = await DatabaseHelper.instance.getPagesForDocument(widget.documentId!);
        if (widget.pageIndex < pages.length) {
          final page = pages[widget.pageIndex];
          await DatabaseHelper.instance.updatePage(
            page.copyWith(enhancedImagePath: file.path, thumbnailPath: thumbBytes),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving composite image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _currentMode == AnnotationMode.addText
              ? l10n.t('toolAddText')
              : _currentMode == AnnotationMode.markup
                  ? l10n.t('toolMarkUp')
                  : l10n.t('toolHide'),
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo_rounded, color: Colors.white),
            onPressed: _undo,
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
            onPressed: _clearAll,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSaving ? null : _saveCompositeImage,
              child: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(l10n.t('save'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Mode Selector Tabs
          Container(
            color: const Color(0xFF1F2937),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildModeTab(AnnotationMode.markup, Icons.edit_rounded, l10n.t('toolMarkUp')),
                _buildModeTab(AnnotationMode.addText, Icons.text_fields_rounded, l10n.t('toolAddText')),
                _buildModeTab(AnnotationMode.redact, Icons.security_rounded, l10n.t('toolHide')),
              ],
            ),
          ),

          // Main Canvas Interactive Area
          Expanded(
            child: _imageBytes == null
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: LayoutBuilder(
                          builder: (ctx, constraints) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  // Base Image
                                  Image.memory(
                                    _imageBytes!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                    ),
                                  ),

                                  // Markup Drawings & Redactions Layer
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _AnnotationPainter(
                                        strokes: _strokes,
                                        currentStroke: _currentStroke,
                                        redactions: _redactions,
                                        currentRedact: _redactStart != null && _redactEnd != null
                                            ? Rect.fromPoints(_redactStart!, _redactEnd!)
                                            : null,
                                        currentRedactIsBlack: _redactBlack,
                                      ),
                                    ),
                                  ),

                                  // Text Annotations Layer (Draggable)
                                  ..._textAnnotations.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final item = entry.value;
                                    return Positioned(
                                      left: item.position.dx,
                                      top: item.position.dy,
                                      child: GestureDetector(
                                        onTap: () => _showAddTextDialog(idx),
                                        onPanUpdate: (details) {
                                          setState(() {
                                            item.position += details.delta;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: item.hasBackground ? Colors.white.withOpacity(0.9) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.primary, width: 1),
                                            boxShadow: item.hasBackground
                                                ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)]
                                                : null,
                                          ),
                                          child: Text(
                                            item.text,
                                            style: TextStyle(
                                              color: item.color,
                                              fontSize: item.fontSize,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),

                                  // Touch Interaction Handler
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onPanStart: (details) {
                                        if (_currentMode == AnnotationMode.markup) {
                                          setState(() {
                                            _currentStroke = [details.localPosition];
                                          });
                                        } else if (_currentMode == AnnotationMode.redact) {
                                          setState(() {
                                            _redactStart = details.localPosition;
                                            _redactEnd = details.localPosition;
                                          });
                                        }
                                      },
                                      onPanUpdate: (details) {
                                        if (_currentMode == AnnotationMode.markup && _currentStroke != null) {
                                          setState(() {
                                            _currentStroke!.add(details.localPosition);
                                          });
                                        } else if (_currentMode == AnnotationMode.redact && _redactStart != null) {
                                          setState(() {
                                            _redactEnd = details.localPosition;
                                          });
                                        }
                                      },
                                      onPanEnd: (details) {
                                        if (_currentMode == AnnotationMode.markup && _currentStroke != null) {
                                          setState(() {
                                            _strokes.add(
                                              MarkupStroke(
                                                points: List.from(_currentStroke!),
                                                color: _isHighlighter
                                                    ? _selectedColor.withOpacity(0.4)
                                                    : _selectedColor,
                                                strokeWidth: _isHighlighter ? _strokeWidth * 3.5 : _strokeWidth,
                                                isHighlighter: _isHighlighter,
                                              ),
                                            );
                                            _currentStroke = null;
                                          });
                                        } else if (_currentMode == AnnotationMode.redact &&
                                            _redactStart != null &&
                                            _redactEnd != null) {
                                          setState(() {
                                            _redactions.add(
                                              RedactBox(
                                                rect: Rect.fromPoints(_redactStart!, _redactEnd!),
                                                isBlack: _redactBlack,
                                              ),
                                            );
                                            _redactStart = null;
                                            _redactEnd = null;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
          ),

          // Bottom Controls Tool Strip
          Container(
            color: const Color(0xFF111827),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            child: _buildBottomToolbar(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(AnnotationMode mode, IconData icon, String label) {
    final isSelected = _currentMode == mode;
    return InkWell(
      onTap: () => setState(() => _currentMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    if (_currentMode == AnnotationMode.addText) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Tap button to place text on document',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            label: const Text('Add Text Box', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => _showAddTextDialog(),
          ),
        ],
      );
    }

    if (_currentMode == AnnotationMode.redact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Drag over sensitive text to redact',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Black Bar'),
                selected: _redactBlack,
                selectedColor: Colors.black,
                backgroundColor: const Color(0xFF1F2937),
                labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                onSelected: (val) => setState(() => _redactBlack = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Whiteout'),
                selected: !_redactBlack,
                selectedColor: Colors.white,
                backgroundColor: const Color(0xFF1F2937),
                labelStyle: TextStyle(color: !_redactBlack ? Colors.black : Colors.white, fontSize: 12),
                onSelected: (val) => setState(() => _redactBlack = false),
              ),
            ],
          ),
        ],
      );
    }

    // Markup controls (Pen, Highlighter, Colors, Width)
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Pen vs Highlighter toggle
            ChoiceChip(
              avatar: const Icon(Icons.edit_rounded, size: 14),
              label: const Text('Pen'),
              selected: !_isHighlighter,
              selectedColor: AppColors.primary,
              backgroundColor: const Color(0xFF1F2937),
              labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
              onSelected: (val) => setState(() => _isHighlighter = false),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: const Icon(Icons.brush_rounded, size: 14),
              label: const Text('Highlighter'),
              selected: _isHighlighter,
              selectedColor: AppColors.secondary,
              backgroundColor: const Color(0xFF1F2937),
              labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
              onSelected: (val) => setState(() {
                _isHighlighter = true;
                _selectedColor = const Color(0xFFFACC15); // Yellow default
              }),
            ),
            const Spacer(),
            // Stroke width indicator
            Text(
              '${_strokeWidth.round()}px',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            SizedBox(
              width: 100,
              child: Slider(
                value: _strokeWidth,
                min: 1.5,
                max: 10.0,
                divisions: 8,
                onChanged: (v) => setState(() => _strokeWidth = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Color Palette Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Color(0xFFEF4444), // Red
            const Color(0xFF3B82F6), // Blue
            const Color(0xFF10B981), // Green
            const Color(0xFFFACC15), // Yellow
            const Color(0xFF8B5CF6), // Purple
            Colors.black,
            Colors.white,
          ].map((c) {
            final isSel = _selectedColor == c;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = c),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSel ? Colors.white : Colors.grey.withOpacity(0.3),
                    width: isSel ? 3 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final List<MarkupStroke> strokes;
  final List<Offset>? currentStroke;
  final List<RedactBox> redactions;
  final Rect? currentRedact;
  final bool currentRedactIsBlack;

  _AnnotationPainter({
    required this.strokes,
    this.currentStroke,
    required this.redactions,
    this.currentRedact,
    this.currentRedactIsBlack = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw saved redactions
    for (final box in redactions) {
      final paint = Paint()
        ..color = box.isBlack ? Colors.black : Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRect(box.rect, paint);
    }

    // 2. Draw current active redaction
    if (currentRedact != null) {
      final paint = Paint()
        ..color = (currentRedactIsBlack ? Colors.black : Colors.white).withOpacity(0.85)
        ..style = PaintingStyle.fill;
      canvas.drawRect(currentRedact!, paint);
    }

    // 3. Draw saved strokes
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(stroke.points[0].dx, stroke.points[0].dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // 4. Draw current stroke
    if (currentStroke != null && currentStroke!.isNotEmpty) {
      final paint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(currentStroke![0].dx, currentStroke![0].dy);
      for (int i = 1; i < currentStroke!.length; i++) {
        path.lineTo(currentStroke![i].dx, currentStroke![i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) => true;
}
