import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/database/models/document_model.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/pdf_service.dart';
import 'pdf_viewer_screen.dart';

class PdfCompressScreen extends ConsumerStatefulWidget {
  const PdfCompressScreen({super.key});

  @override
  ConsumerState<PdfCompressScreen> createState() => _PdfCompressScreenState();
}

class _PdfCompressScreenState extends ConsumerState<PdfCompressScreen> {
  DocumentModel? _selectedDoc;
  PdfCompressionLevel _level = PdfCompressionLevel.medium;
  bool _isCompressing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final docsAsync = ref.watch(allDocumentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('compressPdfTitle')),
      ),
      body: docsAsync.when(
        data: (docs) {
          final pdfDocs = docs.where((d) => d.pdfPath != null).toList();
          if (pdfDocs.isEmpty) {
            return Center(child: Text(l10n.t('noRecentDocs')));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select a PDF to compress:',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: pdfDocs.length,
                  itemBuilder: (ctx, index) {
                    final doc = pdfDocs[index];

                    return RadioListTile<DocumentModel>(
                      value: doc,
                      groupValue: _selectedDoc,
                      title: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${doc.formattedSize} • ${doc.pageCount} ${l10n.t('pages')}'),
                      onChanged: (val) => setState(() => _selectedDoc = val),
                    );
                  },
                ),
              ),
              if (_selectedDoc != null)
                Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<PdfCompressionLevel>(
                        value: _level,
                        decoration: InputDecoration(
                          labelText: 'Compression Level',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: PdfCompressionLevel.low,
                            child: Text(l10n.t('compressionLow')),
                          ),
                          DropdownMenuItem(
                            value: PdfCompressionLevel.medium,
                            child: Text(l10n.t('compressionMedium')),
                          ),
                          DropdownMenuItem(
                            value: PdfCompressionLevel.high,
                            child: Text(l10n.t('compressionHigh')),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _level = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isCompressing ? null : _runCompression,
                          icon: _isCompressing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.compress_rounded),
                          label: Text(l10n.t('toolCompress')),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }

  Future<void> _runCompression() async {
    if (_selectedDoc == null || _selectedDoc!.pdfPath == null || _isCompressing) return;

    setState(() => _isCompressing = true);
    try {
      final title = '${_selectedDoc!.title}_compressed';
      final outPath = await PdfService.instance.compressPdf(
        sourcePdfPath: _selectedDoc!.pdfPath!,
        level: _level,
        outputTitle: title,
      );

      final newSize = await File(outPath).length();
      final newDoc = DocumentModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pageCount: _selectedDoc!.pageCount,
        pdfPath: outPath,
        thumbnailPath: _selectedDoc!.thumbnailPath,
        fileSizeBytes: newSize,
      );

      await DatabaseHelper.instance.insertDocument(newDoc);
      ref.read(recentDocumentsProvider.notifier).load();
      ref.read(allDocumentsProvider.notifier).load();

      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => PdfViewerScreen(pdfPath: outPath, title: title),
          ),
        );
      }
    } catch (e) {
      debugPrint('Compression error: $e');
    } finally {
      if (mounted) setState(() => _isCompressing = false);
    }
  }
}
