import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/export_download_service.dart';
import '../../../core/services/ocr_service.dart';

class OcrResultScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final String? existingOcrText;
  final String documentTitle;
  final String? documentId;

  const OcrResultScreen({
    super.key,
    required this.imagePath,
    this.existingOcrText,
    required this.documentTitle,
    this.documentId,
  });

  @override
  ConsumerState<OcrResultScreen> createState() => _OcrResultScreenState();
}

class _OcrResultScreenState extends ConsumerState<OcrResultScreen> {
  late TextEditingController _textController;
  late TextEditingController _searchController;
  bool _isLoading = false;
  OcrLanguage _selectedLanguage = OcrLanguage.mixed;
  String _searchQuery = '';
  int _matchCount = 0;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.existingOcrText ?? '');
    _searchController = TextEditingController();

    if (widget.existingOcrText == null || widget.existingOcrText!.isEmpty) {
      if (widget.imagePath.isNotEmpty) {
        _runOcr();
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runOcr() async {
    setState(() => _isLoading = true);
    try {
      final res = await OcrService.instance.recognizeText(
        imagePath: widget.imagePath,
        language: _selectedLanguage,
      );

      if (mounted) {
        setState(() {
          _textController.text = res.fullText;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('OCR Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val.trim();
      if (_searchQuery.isEmpty) {
        _matchCount = 0;
      } else {
        final matches = RegExp(RegExp.escape(_searchQuery), caseSensitive: false)
            .allMatches(_textController.text);
        _matchCount = matches.length;
      }
    });
  }

  Future<void> _saveOcrToDocument() async {
    if (widget.documentId == null) return;
    try {
      final doc = await DatabaseHelper.instance.getDocumentById(widget.documentId!);
      if (doc != null) {
        await DatabaseHelper.instance.updateDocument(
          doc.copyWith(ocrFullText: _textController.text),
        );
        ref.invalidate(recentDocumentsProvider);
        ref.invalidate(allDocumentsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OCR text saved to document'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving OCR: $e');
    }
  }

  Future<void> _copyToClipboard() async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: _textController.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.t('copiedToClipboard')),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('ocrTitle')),
        actions: [
          if (widget.documentId != null)
            IconButton(
              tooltip: l10n.t('save'),
              icon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.secondary),
              onPressed: _saveOcrToDocument,
            ),
          if (widget.imagePath.isNotEmpty)
            IconButton(
              tooltip: l10n.t('downloadImage'),
              icon: const Icon(Icons.image_outlined),
              onPressed: () {
                ExportDownloadService.instance.downloadPageImage(
                  imagePath: widget.imagePath,
                  documentTitle: widget.documentTitle,
                ).then((saved) {
                  if (context.mounted) {
                    ExportDownloadService.instance.showSuccessFeedback(context, saved, l10n.t('imageSavedSuccess'));
                  }
                });
              },
            ),
          IconButton(
            tooltip: l10n.t('copyText'),
            icon: const Icon(Icons.copy_rounded),
            onPressed: _copyToClipboard,
          ),
          IconButton(
            tooltip: l10n.t('download'),
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () {
              ExportDownloadService.instance.showExportTextBottomSheet(
                context,
                text: _textController.text,
                title: widget.documentTitle,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Language selector bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? AppColors.cardDark : AppColors.cardSubtleLight,
            child: Row(
              children: [
                const Icon(Icons.language_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  l10n.t('ocrLanguage'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const Spacer(),
                DropdownButton<OcrLanguage>(
                  value: _selectedLanguage,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(16),
                  items: [
                    DropdownMenuItem(
                      value: OcrLanguage.english,
                      child: Text(l10n.t('ocrLangEnglish')),
                    ),
                    DropdownMenuItem(
                      value: OcrLanguage.khmer,
                      child: Text(l10n.t('ocrLangKhmer')),
                    ),
                    DropdownMenuItem(
                      value: OcrLanguage.mixed,
                      child: Text(l10n.t('ocrLangMixed')),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedLanguage = val);
                      _runOcr();
                    }
                  },
                ),
              ],
            ),
          ),

          // 2. Search inside OCR bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: l10n.t('searchInText'),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixText: _searchQuery.isNotEmpty ? '$_matchCount matches' : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),

          // 3. Extracted Text Area
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 16),
                        Text(
                          l10n.t('ocrExtracting'),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        expands: true,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          fontFamily: _selectedLanguage == OcrLanguage.khmer ? 'Battambang' : null,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: l10n.t('noTextFound'),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
