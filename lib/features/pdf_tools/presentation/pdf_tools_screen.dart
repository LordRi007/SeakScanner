import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/glass_card.dart';
import '../../documents/presentation/document_editor_screen.dart';
import '../../ocr/presentation/ocr_result_screen.dart';
import '../../scanner/presentation/camera_screen.dart';
import '../../scanner/presentation/multi_page_preview_screen.dart';
import 'pdf_compress_screen.dart';
import 'pdf_merge_screen.dart';
import 'pdf_signature_screen.dart';

class PdfToolsScreen extends ConsumerWidget {
  const PdfToolsScreen({super.key});

  Future<void> _pickImagesToPdf(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty && context.mounted) {
      final paths = picked.map((x) => x.path).toList();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => MultiPagePreviewScreen(pagePaths: paths),
        ),
      );
    }
  }

  Future<void> _openToolWithDocumentSelector(
    BuildContext context,
    WidgetRef ref, {
    AnnotationMode? annotationMode,
    bool isSign = false,
    bool isOcr = false,
    required String toolTitle,
    required IconData toolIcon,
  }) async {
    final docs = ref.read(recentDocumentsProvider).asData?.value ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(toolIcon, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    toolTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a document or import an image to edit:',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Option 1: Gallery
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: const Text('Import from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Pick any photo to edit or sign'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
                  if (picked != null && context.mounted) {
                    _launchTool(context, ref, picked.path, null, annotationMode, isSign, isOcr, 'Imported Image');
                  }
                },
              ),

              // Option 2: Camera
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.secondary),
                ),
                title: const Text('Scan with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Snap a new document'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
                },
              ),

              if (docs.isNotEmpty) ...[
                const Divider(height: 24),
                const Text(
                  'Recent Documents',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: docs.length > 5 ? 5 : docs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (c, idx) {
                      final d = docs[idx];
                      return GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          final pages = await DatabaseHelper.instance.getPagesForDocument(d.id);
                          final imgPath = pages.isNotEmpty
                              ? pages.first.enhancedImagePath
                              : d.thumbnailPath;
                          if (imgPath != null && context.mounted) {
                            _launchTool(context, ref, imgPath, d.id, annotationMode, isSign, isOcr, d.title);
                          }
                        },
                        child: Container(
                          width: 80,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDark : AppColors.cardSubtleLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: d.thumbnailPath != null && File(d.thumbnailPath!).existsSync()
                                      ? Image.file(File(d.thumbnailPath!), fit: BoxFit.cover, width: double.infinity)
                                      : Container(color: Colors.grey.withOpacity(0.2), child: const Icon(Icons.description_rounded, size: 28)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                d.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _launchTool(
    BuildContext context,
    WidgetRef ref,
    String imagePath,
    String? docId,
    AnnotationMode? annotationMode,
    bool isSign,
    bool isOcr,
    String title,
  ) {
    if (annotationMode != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentEditorScreen(
            imagePath: imagePath,
            documentId: docId,
            initialMode: annotationMode,
          ),
        ),
      ).then((_) {
        ref.invalidate(recentDocumentsProvider);
      });
    } else if (isSign) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfSignatureScreen(
            pageImagePath: imagePath,
            documentId: docId,
          ),
        ),
      ).then((_) {
        ref.invalidate(recentDocumentsProvider);
      });
    } else if (isOcr) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OcrResultScreen(
            imagePath: imagePath,
            documentId: docId,
            documentTitle: title,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tools = [
      _ToolItem(
        title: l10n.t('toolScan'),
        icon: Icons.crop_free_rounded,
        color: AppColors.primary,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen())),
      ),
      _ToolItem(
        title: l10n.t('toolAddText'),
        icon: Icons.text_fields_rounded,
        color: const Color(0xFF6366F1),
        onTap: () => _openToolWithDocumentSelector(
          context,
          ref,
          annotationMode: AnnotationMode.addText,
          toolTitle: l10n.t('toolAddText'),
          toolIcon: Icons.text_fields_rounded,
        ),
      ),
      _ToolItem(
        title: l10n.t('toolOCR'),
        icon: Icons.document_scanner_rounded,
        color: AppColors.secondary,
        onTap: () => _openToolWithDocumentSelector(
          context,
          ref,
          isOcr: true,
          toolTitle: l10n.t('toolOCR'),
          toolIcon: Icons.document_scanner_rounded,
        ),
      ),
      _ToolItem(
        title: l10n.t('toolMarkUp'),
        icon: Icons.edit_outlined,
        color: const Color(0xFF3B82F6),
        onTap: () => _openToolWithDocumentSelector(
          context,
          ref,
          annotationMode: AnnotationMode.markup,
          toolTitle: l10n.t('toolMarkUp'),
          toolIcon: Icons.edit_outlined,
        ),
      ),
      _ToolItem(
        title: l10n.t('toolHide'),
        icon: Icons.auto_fix_normal_rounded,
        color: const Color(0xFF64748B),
        onTap: () => _openToolWithDocumentSelector(
          context,
          ref,
          annotationMode: AnnotationMode.redact,
          toolTitle: l10n.t('toolHide'),
          toolIcon: Icons.auto_fix_normal_rounded,
        ),
      ),
      _ToolItem(
        title: l10n.t('tooleSign'),
        icon: Icons.gesture_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: () => _openToolWithDocumentSelector(
          context,
          ref,
          isSign: true,
          toolTitle: l10n.t('tooleSign'),
          toolIcon: Icons.gesture_rounded,
        ),
      ),
      _ToolItem(
        title: l10n.t('toolImages'),
        icon: Icons.photo_library_outlined,
        color: const Color(0xFF06B6D4),
        onTap: () => _pickImagesToPdf(context),
      ),
      _ToolItem(
        title: l10n.t('toolMerge'),
        icon: Icons.all_inclusive_rounded,
        color: const Color(0xFF10B981),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfMergeScreen())),
      ),
      _ToolItem(
        title: l10n.t('toolCompress'),
        icon: Icons.compress_rounded,
        color: const Color(0xFFF59E0B),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfCompressScreen())),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('quickTools')),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.95,
        ),
        itemCount: tools.length,
        itemBuilder: (context, index) {
          final tool = tools[index];
          return GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            onTap: tool.onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tool.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(tool.icon, color: tool.color, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  tool.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ToolItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ToolItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
