import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/models/document_model.dart';
import '../../../core/database/models/folder_model.dart';
import '../../../core/database/models/page_model.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/export_download_service.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/services/storage_service.dart';
import '../../ocr/presentation/ocr_result_screen.dart';
import '../../pdf_tools/presentation/pdf_signature_screen.dart';
import '../../pdf_tools/presentation/pdf_viewer_screen.dart';
import '../../scanner/presentation/enhancement_screen.dart';
import 'document_editor_screen.dart';

class DocumentDetailScreen extends ConsumerStatefulWidget {
  final String documentId;
  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  ConsumerState<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  DocumentModel? _document;
  List<PageModel> _pages = [];
  List<FolderModel> _folders = [];
  bool _isLoading = true;
  int _activePageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() => _isLoading = true);
    try {
      final doc = await DatabaseHelper.instance.getDocumentById(widget.documentId);
      final pages = await DatabaseHelper.instance.getPagesForDocument(widget.documentId);
      final folders = await DatabaseHelper.instance.getFolders();

      if (mounted) {
        setState(() {
          _document = doc;
          _pages = pages;
          _folders = folders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading document detail: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _renameDocument() async {
    if (_document == null) return;
    final l10n = AppLocalizations.of(context);
    final textController = TextEditingController(text: _document!.title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('rename')),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.t('documentName')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.t('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, textController.text.trim()),
            child: Text(l10n.t('save')),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != _document!.title) {
      final updated = _document!.copyWith(title: newTitle, updatedAt: DateTime.now());
      await DatabaseHelper.instance.updateDocument(updated);
      ref.read(recentDocumentsProvider.notifier).load();
      ref.read(allDocumentsProvider.notifier).load();
      setState(() => _document = updated);
    }
  }

  Future<void> _moveToFolder() async {
    if (_document == null) return;
    final l10n = AppLocalizations.of(context);

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.t('moveToFolder'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: Text(l10n.t('unfiled')),
                trailing: _document!.folderId == null ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () async {
                  await DatabaseHelper.instance.moveDocumentToFolder(_document!.id, null);
                  Navigator.pop(ctx);
                  _loadDocument();
                },
              ),
              ..._folders.map((f) => ListTile(
                    leading: Icon(Icons.folder_rounded, color: Color(f.colorValue)),
                    title: Text(f.name),
                    trailing: _document!.folderId == f.id ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () async {
                      await DatabaseHelper.instance.moveDocumentToFolder(_document!.id, f.id);
                      Navigator.pop(ctx);
                      _loadDocument();
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    if (_document == null) return;
    final newFav = !_document!.isFavorite;
    await DatabaseHelper.instance.toggleFavorite(_document!.id, newFav);
    setState(() {
      _document = _document!.copyWith(isFavorite: newFav);
    });
    ref.read(recentDocumentsProvider.notifier).load();
    ref.read(allDocumentsProvider.notifier).load();
  }

  Future<void> _deleteDocument() async {
    if (_document == null) return;
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('moveToTrash')),
        content: Text(l10n.t('trashNote')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.t('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.t('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.moveToTrash(_document!.id);
      ref.read(recentDocumentsProvider.notifier).load();
      ref.read(allDocumentsProvider.notifier).load();
      ref.read(trashDocumentsProvider.notifier).load();
      if (mounted) Navigator.pop(context);
    }
  }

  void _showDownloadOptions() {
    if (_document == null) return;
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.file_download_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('exportFormatTitle'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          _document!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.image_rounded, color: AppColors.primary, size: 22),
                ),
                title: Text(l10n.t('downloadImage'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: const Text('Download page image (JPG) to Downloads folder', style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () {
                  Navigator.pop(ctx);
                  ExportDownloadService.instance.showDownloadImageBottomSheet(
                    context,
                    pages: _pages,
                    activeIndex: _activePageIndex,
                    documentTitle: _document!.title,
                  );
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 22),
                ),
                title: Text(l10n.t('exportAsPdf'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: const Text('Save PDF file to Downloads folder', style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (_document!.pdfPath != null) {
                    try {
                      final saved = await StorageService.instance.copyFileToDownloads(
                        _document!.pdfPath!,
                        targetFileName: '${_document!.title}.pdf',
                      );
                      if (mounted) {
                        ExportDownloadService.instance.showSuccessFeedback(context, saved, l10n.t('fileSavedSuccess'));
                      }
                    } catch (e) {
                      debugPrint('PDF download error: $e');
                    }
                  }
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.article_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                title: Text(l10n.t('exportAsDocx'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: const Text('Export document to Microsoft Word (.docx)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ocr = _document!.ocrFullText ?? '';
                  final text = ocr.isNotEmpty
                      ? ocr
                      : 'Document: ${_document!.title}\nPages: ${_pages.length}\nCreated: ${DateFormat('yyyy-MM-dd HH:mm').format(_document!.createdAt)}';
                  try {
                    final saved = await ExportDownloadService.instance.exportTextContent(
                      text: text,
                      title: _document!.title,
                      format: ExportFormat.docx,
                    );
                    if (mounted) {
                      ExportDownloadService.instance.showSuccessFeedback(context, saved, l10n.t('fileSavedSuccess'));
                    }
                  } catch (e) {
                    debugPrint('DOCX export error: $e');
                  }
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.table_chart_rounded, color: Color(0xFF10B981), size: 22),
                ),
                title: Text(l10n.t('exportAsExcel'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: const Text('Export content & metadata to Excel (.xlsx)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ocr = _document!.ocrFullText ?? '';
                  final text = ocr.isNotEmpty
                      ? ocr
                      : 'Document: ${_document!.title}\nPages: ${_pages.length}\nCreated: ${DateFormat('yyyy-MM-dd HH:mm').format(_document!.createdAt)}';
                  try {
                    final saved = await ExportDownloadService.instance.exportTextContent(
                      text: text,
                      title: _document!.title,
                      format: ExportFormat.excel,
                    );
                    if (mounted) {
                      ExportDownloadService.instance.showSuccessFeedback(context, saved, l10n.t('fileSavedSuccess'));
                    }
                  } catch (e) {
                    debugPrint('Excel export error: $e');
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_document == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.t('error'))),
      );
    }

    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(_document!.updatedAt);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _renameDocument,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _document!.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: l10n.t('download'),
            onPressed: _showDownloadOptions,
          ),
          IconButton(
            icon: Icon(
              _document!.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _document!.isFavorite ? Colors.amber : null,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.folder_open_rounded),
            onPressed: _moveToFolder,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _deleteDocument,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Interactive Page Viewer / Carousel
          Expanded(
            child: _pages.isEmpty
                ? Center(child: Text(l10n.t('noTextFound')))
                : PageView.builder(
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _activePageIndex = i),
                    itemBuilder: (ctx, idx) {
                      final p = _pages[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            color: isDark ? AppColors.cardDark : AppColors.cardLight,
                            child: Image.file(
                              File(p.enhancedImagePath),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 2. Page Indicator & Metadata
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_pages.isNotEmpty ? _activePageIndex + 1 : 0} / ${_pages.length} ${l10n.t('pages')}',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_document!.formattedSize} • $dateStr',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        if (_pages.isNotEmpty) {
                          ExportDownloadService.instance.showDownloadImageBottomSheet(
                            context,
                            pages: _pages,
                            activeIndex: _activePageIndex,
                            documentTitle: _document!.title,
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.download_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              l10n.t('downloadImage'),
                              style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Quick Action Tools Bar (Download, PDF View, OCR, eSign, Share, Print)
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 14,
              bottom: MediaQuery.of(context).padding.bottom + 14,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              border: Border(
                top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildToolButton(
                    icon: Icons.edit_note_rounded,
                    label: l10n.t('toolMarkUp'),
                    color: const Color(0xFF6366F1),
                    onTap: () {
                      if (_pages.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => DocumentEditorScreen(
                              imagePath: _pages[_activePageIndex].enhancedImagePath,
                              documentId: _document!.id,
                              pageIndex: _activePageIndex,
                              initialMode: AnnotationMode.markup,
                            ),
                          ),
                        ).then((updated) {
                          if (updated == true) _loadDocument();
                        });
                      }
                    },
                  ),
                  _buildToolButton(
                    icon: Icons.tune_rounded,
                    label: 'Filters',
                    color: const Color(0xFFEC4899),
                    onTap: () {
                      if (_pages.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => EnhancementScreen(
                              croppedImagePath: _pages[_activePageIndex].enhancedImagePath,
                              targetDocumentId: _document!.id,
                              batchIndex: _activePageIndex + 1,
                              totalBatch: _pages.length,
                              onFinishBatch: () => _loadDocument(),
                            ),
                          ),
                        ).then((_) => _loadDocument());
                      }
                    },
                  ),
                  _buildToolButton(
                    icon: Icons.text_snippet_rounded,
                    label: l10n.t('toolOCR'),
                    color: AppColors.secondary,
                    onTap: () {
                      final currentImagePath = _pages.isNotEmpty
                          ? _pages[_activePageIndex].enhancedImagePath
                          : '';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => OcrResultScreen(
                            imagePath: currentImagePath,
                            existingOcrText: _document!.ocrFullText,
                            documentTitle: _document!.title,
                            documentId: _document!.id,
                          ),
                        ),
                      ).then((_) => _loadDocument());
                    },
                  ),
                  _buildToolButton(
                    icon: Icons.draw_rounded,
                    label: l10n.t('tooleSign'),
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      if (_pages.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => PdfSignatureScreen(
                              pageImagePath: _pages[_activePageIndex].enhancedImagePath,
                              documentId: _document!.id,
                            ),
                          ),
                        ).then((_) => _loadDocument());
                      }
                    },
                  ),
                  _buildToolButton(
                    icon: Icons.file_download_rounded,
                    label: l10n.t('download'),
                    color: const Color(0xFF0284C7),
                    onTap: _showDownloadOptions,
                  ),
                  _buildToolButton(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'PDF',
                    color: AppColors.primary,
                    onTap: () {
                      if (_document!.pdfPath != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => PdfViewerScreen(
                              pdfPath: _document!.pdfPath!,
                              title: _document!.title,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  _buildToolButton(
                    icon: Icons.share_rounded,
                    label: l10n.t('share'),
                    color: const Color(0xFF10B981),
                    onTap: () {
                      if (_document!.pdfPath != null) {
                        PdfService.instance.shareFile(_document!.pdfPath!, text: _document!.title);
                      }
                    },
                  ),
                  _buildToolButton(
                    icon: Icons.print_rounded,
                    label: l10n.t('printPdf'),
                    color: const Color(0xFFF59E0B),
                    onTap: () {
                      if (_document!.pdfPath != null) {
                        PdfService.instance.printPdf(_document!.pdfPath!, title: _document!.title);
                      }
                    },
                  ),
                ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

