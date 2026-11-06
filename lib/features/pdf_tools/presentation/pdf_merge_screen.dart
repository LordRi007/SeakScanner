import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/models/document_model.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/pdf_service.dart';
import 'pdf_viewer_screen.dart';

class PdfMergeScreen extends ConsumerStatefulWidget {
  const PdfMergeScreen({super.key});

  @override
  ConsumerState<PdfMergeScreen> createState() => _PdfMergeScreenState();
}

class _PdfMergeScreenState extends ConsumerState<PdfMergeScreen> {
  final List<DocumentModel> _selectedDocs = [];
  bool _isMerging = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final docsAsync = ref.watch(allDocumentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('mergePdfTitle')),
        actions: [
          ElevatedButton(
            onPressed: _selectedDocs.length < 2 || _isMerging ? null : _mergePdfs,
            child: _isMerging
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(l10n.t('apply')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.t('selectPdfsToMerge'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          Expanded(
            child: docsAsync.when(
              data: (docs) {
                final pdfDocs = docs.where((d) => d.pdfPath != null).toList();
                if (pdfDocs.isEmpty) {
                  return Center(child: Text(l10n.t('noRecentDocs')));
                }

                return ListView.builder(
                  itemCount: pdfDocs.length,
                  itemBuilder: (ctx, index) {
                    final doc = pdfDocs[index];
                    final isSelected = _selectedDocs.contains(doc);

                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${doc.pageCount} ${l10n.t('pages')} • ${doc.formattedSize}'),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
                      ),
                      onChanged: (bool? val) {
                        setState(() {
                          if (val == true) {
                            _selectedDocs.add(doc);
                          } else {
                            _selectedDocs.remove(doc);
                          }
                        });
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mergePdfs() async {
    setState(() => _isMerging = true);
    try {
      final paths = _selectedDocs.map((d) => d.pdfPath!).toList();
      final title = 'Merged_${DateTime.now().millisecondsSinceEpoch}';
      final outPath = await PdfService.instance.mergePdfs(
        pdfPaths: paths,
        outputTitle: title,
      );

      // Create new document in database
      final newDoc = DocumentModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pageCount: _selectedDocs.fold(0, (sum, d) => sum + d.pageCount),
        pdfPath: outPath,
        thumbnailPath: _selectedDocs.first.thumbnailPath,
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
      debugPrint('Merge error: $e');
    } finally {
      if (mounted) setState(() => _isMerging = false);
    }
  }
}

