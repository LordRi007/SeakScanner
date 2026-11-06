import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../app/theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/export_download_service.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/services/storage_service.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfPath;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.pdfPath,
    required this.title,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  List<Uint8List> _rasterPages = [];
  bool _isLoading = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadPdfPages();
  }

  Future<void> _loadPdfPages() async {
    try {
      final file = File(widget.pdfPath);
      if (!await file.exists()) {
        setState(() => _isLoading = false);
        return;
      }

      final bytes = await file.readAsBytes();
      final pages = <Uint8List>[];

      await for (final page in Printing.raster(bytes, dpi: 150)) {
        final png = await page.toPng();
        pages.add(png);
      }

      if (mounted) {
        setState(() {
          _rasterPages = pages;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading PDF pages: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_rasterPages.isNotEmpty)
            IconButton(
              tooltip: l10n.t('downloadImage'),
              icon: const Icon(Icons.file_download_outlined),
              onPressed: () async {
                try {
                  final pagePngBytes = _rasterPages[_currentPage];
                  final saved = await StorageService.instance.saveFileToDownloads(
                    pagePngBytes,
                    'Seak_${widget.title}_page_${_currentPage + 1}.png',
                  );
                  if (mounted) {
                    ExportDownloadService.instance.showSuccessFeedback(
                      context,
                      saved,
                      l10n.t('imageSavedSuccess'),
                    );
                  }
                } catch (e) {
                  debugPrint('Download error: $e');
                }
              },
            ),
          IconButton(
            tooltip: l10n.t('printPdf'),
            icon: const Icon(Icons.print_rounded),
            onPressed: () => PdfService.instance.printPdf(widget.pdfPath, title: widget.title),
          ),
          IconButton(
            tooltip: l10n.t('sharePdf'),
            icon: const Icon(Icons.share_rounded),
            onPressed: () => PdfService.instance.shareFile(widget.pdfPath, text: widget.title),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _rasterPages.isEmpty
              ? Center(child: Text(l10n.t('error')))
              : Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        itemCount: _rasterPages.length,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemBuilder: (ctx, idx) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.memory(
                                  _rasterPages[idx],
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        border: Border(
                          top: BorderSide(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${l10n.t('page')} ${_currentPage + 1} of ${_rasterPages.length}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

