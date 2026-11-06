import 'dart:io';
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

class MultiPagePreviewScreen extends ConsumerStatefulWidget {
  final List<String> pagePaths;
  final String? targetDocumentId;

  const MultiPagePreviewScreen({
    super.key,
    required this.pagePaths,
    this.targetDocumentId,
  });

  @override
  ConsumerState<MultiPagePreviewScreen> createState() => _MultiPagePreviewScreenState();
}

class _MultiPagePreviewScreenState extends ConsumerState<MultiPagePreviewScreen> {
  late List<String> _paths;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _paths = List.from(widget.pagePaths);
  }

  void _removePage(int index) {
    setState(() {
      _paths.removeAt(index);
    });
    if (_paths.isEmpty) {
      Navigator.pop(context);
    }
  }

  Future<void> _saveAllPages() async {
    if (_paths.isEmpty || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final uuid = const Uuid();
      final documentId = widget.targetDocumentId ?? uuid.v4();
      final now = DateTime.now();

      final enhancedPaths = <String>[];
      final fullOcrTexts = <String>[];
      String? firstThumb;

      for (int i = 0; i < _paths.length; i++) {
        final path = _paths[i];
        final bytes = await File(path).readAsBytes();

        // 1. Apply default magic filter
        final enhancedBytes = await ImageProcessingService.instance.processImageBytes(
          bytes: bytes,
          filter: EnhancementFilter.magic,
        );

        final enhancedPath = await StorageService.instance.saveImageBytes(
          enhancedBytes,
          sub: 'pages',
          filename: 'page_${documentId}_$i.jpg',
        );
        enhancedPaths.add(enhancedPath);

        // 2. Thumbnail
        final thumbBytes = await ImageProcessingService.instance.createThumbnail(enhancedBytes);
        final thumbPath = await StorageService.instance.saveImageBytes(
          thumbBytes,
          sub: 'thumbnails',
          filename: 'thumb_${documentId}_$i.jpg',
        );
        firstThumb ??= thumbPath;

        // 3. OCR extraction
        final ocr = await OcrService.instance.recognizeText(
          imagePath: enhancedPath,
          language: ref.read(scannerSettingsProvider).ocrLanguage,
        );
        if (ocr.fullText.isNotEmpty) {
          fullOcrTexts.add(ocr.fullText);
        }

        // 4. Save PageModel
        final pageModel = PageModel(
          id: uuid.v4(),
          documentId: documentId,
          pageIndex: i,
          originalImagePath: path,
          enhancedImagePath: enhancedPath,
          thumbnailPath: thumbPath,
          ocrText: ocr.fullText,
          createdAt: now,
        );
        await DatabaseHelper.instance.insertPage(pageModel);
      }

      // 5. Generate Multi-page PDF
      final defaultTitle = 'Scan_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final joinedOcr = fullOcrTexts.join('\n\n--- Next Page ---\n\n');

      final pdfPath = await PdfService.instance.generatePdfFromImages(
        imagePaths: enhancedPaths,
        title: defaultTitle,
        formatType: ref.read(scannerSettingsProvider).defaultPageSize,
        ocrText: joinedOcr,
      );

      final pdfFile = File(pdfPath);
      final pdfSize = await pdfFile.length();

      // 6. Save DocumentModel
      final doc = DocumentModel(
        id: documentId,
        title: defaultTitle,
        createdAt: now,
        updatedAt: now,
        pageCount: _paths.length,
        pdfPath: pdfPath,
        thumbnailPath: firstThumb,
        fileSizeBytes: pdfSize,
        ocrFullText: joinedOcr,
      );
      await DatabaseHelper.instance.insertDocument(doc);

      // Refresh providers
      ref.read(recentDocumentsProvider.notifier).load();
      ref.read(allDocumentsProvider.notifier).load();

      if (!mounted) return;

      Navigator.of(context).popUntil((r) => r.isFirst);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => DocumentDetailScreen(documentId: documentId),
        ),
      );
    } catch (e) {
      debugPrint('Error saving multi-page: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.t('multiPageTitle')} (${_paths.length})'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveAllPages,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    l10n.t('generatePdf'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _paths.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = _paths.removeAt(oldIndex);
            _paths.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final path = _paths[index];
          return Card(
            key: ValueKey(path),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Page index badge
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Image preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 55,
                      height: 70,
                      child: Image.file(
                        File(path),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l10n.t('page')} ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ready for PDF export',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  // Delete page
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => _removePage(index),
                  ),

                  // Drag reorder handle
                  const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveAllPages,
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: Text(l10n.t('generatePdf')),
        ),
      ),
    );
  }
}

