import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/models/document_model.dart';
import '../../../core/database/models/page_model.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/image_processing_service.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/services/storage_service.dart';
import '../../documents/presentation/document_detail_screen.dart';

class EnhancementScreen extends ConsumerStatefulWidget {
  final String croppedImagePath;
  final String? targetDocumentId;
  final int batchIndex;
  final int totalBatch;
  final VoidCallback? onFinishBatch;

  const EnhancementScreen({
    super.key,
    required this.croppedImagePath,
    this.targetDocumentId,
    this.batchIndex = 1,
    this.totalBatch = 1,
    this.onFinishBatch,
  });

  @override
  ConsumerState<EnhancementScreen> createState() => _EnhancementScreenState();
}

class _EnhancementScreenState extends ConsumerState<EnhancementScreen> {
  EnhancementFilter _selectedFilter = EnhancementFilter.magic;
  double _brightness = 0.0;
  double _contrast = 0.0;
  bool _isProcessing = false;
  bool _isSaving = false;
  Uint8List? _previewBytes;
  Uint8List? _baseBytes;

  @override
  void initState() {
    super.initState();
    _loadBaseImage();
  }

  Future<void> _loadBaseImage() async {
    try {
      final bytes = await File(widget.croppedImagePath).readAsBytes();
      setState(() => _baseBytes = bytes);
      _applyFilter();
    } catch (e) {
      debugPrint('Error reading cropped image: $e');
    }
  }

  Future<void> _applyFilter() async {
    if (_baseBytes == null) return;
    setState(() => _isProcessing = true);

    try {
      final processed = await ImageProcessingService.instance.processImageBytes(
        bytes: _baseBytes!,
        filter: _selectedFilter,
        brightness: _brightness,
        contrast: _contrast,
      );

      if (mounted) {
        setState(() {
          _previewBytes = processed;
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Filter apply error: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveAndContinue() async {
    if (_previewBytes == null || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      // 1. Save enhanced image file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final enhancedPath = await StorageService.instance.saveImageBytes(
        _previewBytes!,
        sub: 'pages',
        filename: 'enhanced_$timestamp.jpg',
      );

      // 2. Generate and save thumbnail
      final thumbBytes = await ImageProcessingService.instance.createThumbnail(_previewBytes!);
      final thumbPath = await StorageService.instance.saveImageBytes(
        thumbBytes,
        sub: 'thumbnails',
        filename: 'thumb_$timestamp.jpg',
      );

      // 3. Optional OCR extraction in background for searchability
      final ocrRes = await OcrService.instance.recognizeText(
        imagePath: enhancedPath,
        language: ref.read(scannerSettingsProvider).ocrLanguage,
      );

      // 4. Create or append to document
      final uuid = const Uuid();
      String documentId = widget.targetDocumentId ?? uuid.v4();
      final now = DateTime.now();

      final page = PageModel(
        id: uuid.v4(),
        documentId: documentId,
        pageIndex: widget.batchIndex - 1,
        originalImagePath: widget.croppedImagePath,
        enhancedImagePath: enhancedPath,
        thumbnailPath: thumbPath,
        ocrText: ocrRes.fullText,
        filterType: _selectedFilter.name,
        createdAt: now,
      );

      await DatabaseHelper.instance.insertPage(page);

      // 5. Generate / update PDF
      final allPages = await DatabaseHelper.instance.getPagesForDocument(documentId);
      final pageImagePaths = allPages.map((p) => p.enhancedImagePath).toList();

      final defaultTitle = 'Scan_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      
      final pdfPath = await PdfService.instance.generatePdfFromImages(
        imagePaths: pageImagePaths,
        title: defaultTitle,
        formatType: ref.read(scannerSettingsProvider).defaultPageSize,
        ocrText: ocrRes.fullText,
      );

      final pdfFile = File(pdfPath);
      final pdfSize = await pdfFile.length();

      final doc = DocumentModel(
        id: documentId,
        title: defaultTitle,
        createdAt: now,
        updatedAt: now,
        pageCount: allPages.length,
        pdfPath: pdfPath,
        thumbnailPath: thumbPath,
        fileSizeBytes: pdfSize,
        ocrFullText: ocrRes.fullText,
      );

      await DatabaseHelper.instance.insertDocument(doc);

      // Refresh providers
      ref.read(recentDocumentsProvider.notifier).load();
      ref.read(allDocumentsProvider.notifier).load();

      if (!mounted) return;

      // Pop back to root or open document detail
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => DocumentDetailScreen(documentId: documentId),
        ),
      );
    } catch (e) {
      debugPrint('Error saving enhanced document: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.t('filterPreview'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAndContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(l10n.t('save')),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Interactive Document Image Preview
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_previewBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _previewBytes!,
                          fit: BoxFit.contain,
                        ),
                      )
                    else
                      const CircularProgressIndicator(color: AppColors.primary),
                    if (_isProcessing)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const CircularProgressIndicator(color: AppColors.secondary),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Adjustments Panel: Brightness & Contrast
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wb_sunny_outlined, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      l10n.t('brightness'),
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Expanded(
                      child: Slider(
                        value: _brightness,
                        min: -50.0,
                        max: 50.0,
                        activeColor: AppColors.primaryLight,
                        onChanged: (val) {
                          setState(() => _brightness = val);
                        },
                        onChangeEnd: (_) => _applyFilter(),
                      ),
                    ),
                    Text(
                      '${_brightness.round()}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.contrast_rounded, color: AppColors.secondary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      l10n.t('contrast'),
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Expanded(
                      child: Slider(
                        value: _contrast,
                        min: -50.0,
                        max: 50.0,
                        activeColor: AppColors.secondary,
                        onChanged: (val) {
                          setState(() => _contrast = val);
                        },
                        onChangeEnd: (_) => _applyFilter(),
                      ),
                    ),
                    Text(
                      '${_contrast.round()}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Enhancement Filters Horizontal List
          Container(
            height: 95,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: const Color(0xFF0F172A),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterItem(EnhancementFilter.original, l10n.t('filterOriginal'), Icons.image_outlined),
                _buildFilterItem(EnhancementFilter.magic, l10n.t('filterMagic'), Icons.auto_fix_high_rounded),
                _buildFilterItem(EnhancementFilter.auto, l10n.t('filterAuto'), Icons.wb_incandescent_outlined),
                _buildFilterItem(EnhancementFilter.bw, l10n.t('filterBW'), Icons.contrast_rounded),
                _buildFilterItem(EnhancementFilter.grayscale, l10n.t('filterGrayscale'), Icons.monochrome_photos_rounded),
                _buildFilterItem(EnhancementFilter.highContrast, l10n.t('filterHighContrast'), Icons.tonality_rounded),
                _buildFilterItem(EnhancementFilter.sharpen, l10n.t('filterSharpen'), Icons.details_rounded),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildFilterItem(EnhancementFilter filter, String label, IconData icon) {
    final isSelected = _selectedFilter == filter;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = filter);
        _applyFilter();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.secondary : Colors.white12,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

