import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/models/document_model.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/export_download_service.dart';
import '../../../core/widgets/glass_card.dart';
import '../../documents/presentation/document_detail_screen.dart';
import '../../documents/presentation/document_editor_screen.dart';
import '../../documents/presentation/documents_screen.dart';
import '../../documents/presentation/trash_screen.dart';
import '../../folders/presentation/folders_screen.dart';
import '../../ocr/presentation/ocr_result_screen.dart';
import '../../pdf_tools/presentation/pdf_compress_screen.dart';
import '../../pdf_tools/presentation/pdf_merge_screen.dart';
import '../../pdf_tools/presentation/pdf_signature_screen.dart';
import '../../pdf_tools/presentation/pdf_tools_screen.dart';
import '../../scanner/presentation/camera_screen.dart';
import '../../scanner/presentation/crop_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentNavIndex = 0;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (picked != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => CropScreen(rawImagePath: picked.path),
        ),
      );
    }
  }

  Future<void> _openToolWithDocumentSelector(
    BuildContext context, {
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
                'Choose a document or import an image:',
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
                  if (picked != null && mounted) {
                    _launchTool(picked.path, null, annotationMode, isSign, isOcr, 'Imported Image');
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
                          if (imgPath != null && mounted) {
                            _launchTool(imgPath, d.id, annotationMode, isSign, isOcr, d.title);
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pages = [
      _buildHomeDashboard(context, l10n, isDark),
      const DocumentsScreen(),
      const SizedBox(), // Placeholder for central scan button
      const PdfToolsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentNavIndex == 2 ? 0 : _currentNavIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomNav(context, isDark),
    );
  }

  Widget _buildBottomNav(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined),
              _buildNavItem(1, Icons.folder_rounded, Icons.folder_outlined),

              // Central Floating Glowing Scanner Action
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CameraScreen()),
                  );
                },
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.document_scanner_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),

              _buildNavItem(3, Icons.grid_view_rounded, Icons.grid_view_outlined),
              _buildNavItem(4, Icons.settings_rounded, Icons.settings_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon) {
    final isSelected = _currentNavIndex == index;
    return IconButton(
      icon: Icon(
        isSelected ? activeIcon : inactiveIcon,
        color: isSelected ? AppColors.primary : Colors.grey,
        size: 26,
      ),
      onPressed: () => setState(() => _currentNavIndex = index),
    );
  }

  Widget _buildHomeDashboard(BuildContext context, AppLocalizations l10n, bool isDark) {
    final foldersAsync = ref.watch(foldersProvider);
    final recentDocsAsync = ref.watch(recentDocumentsProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.read(foldersProvider.notifier).load();
          ref.read(recentDocumentsProvider.notifier).load();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // 1. Header with App Logo & Settings Icon (matches screenshot)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.description_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'SeakScanner',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: l10n.t('trashTitle'),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrashScreen())),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => setState(() => _currentNavIndex = 4),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. Search Bar
            TextField(
              controller: _searchCtrl,
              onSubmitted: (q) {
                if (q.trim().isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DocumentsScreen(folderTitle: 'Search: $q'),
                    ),
                  );
                }
              },
              decoration: InputDecoration(
                hintText: l10n.t('searchHint'),
                prefixIcon: const Icon(Icons.search_rounded, size: 22),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Folders Section (Matching Right Screenshot Carousel)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.t('myFolders'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoldersScreen())),
                  child: Text(l10n.t('viewAll')),
                ),
              ],
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 110,
              child: foldersAsync.when(
                data: (folders) {
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: folders.length,
                    itemBuilder: (ctx, index) {
                      final f = folders[index];
                      final isFirst = index == 0;

                      return Container(
                        width: 130,
                        margin: const EdgeInsets.only(right: 12),
                        child: GlassCard(
                          borderRadius: 20,
                          color: isFirst ? AppColors.primary : null,
                          border: isFirst ? Border.all(color: Colors.transparent) : null,
                          padding: const EdgeInsets.all(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DocumentsScreen(folderId: f.id, folderTitle: f.name),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                Icons.folder_rounded,
                                color: isFirst ? Colors.white : Color(f.colorValue),
                                size: 28,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    f.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isFirst ? Colors.white : null,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${f.documentCount} Files',
                                    style: TextStyle(
                                      color: isFirst ? Colors.white70 : Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
              ),
            ),
            const SizedBox(height: 20),

            // 4. Quick Tools Grid (Matching Left Screenshot 3x3 rounded cards)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.t('quickTools'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentNavIndex = 3),
                  child: Text(l10n.t('viewAll')),
                ),
              ],
            ),
            const SizedBox(height: 8),

            _buildQuickToolsGrid(context, l10n, isDark),
            const SizedBox(height: 24),

            // 5. Recent Files Grid (Matching Right Screenshot 2x2 cards)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.t('recentFiles'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.file_download_outlined, size: 20, color: AppColors.primary),
                      tooltip: l10n.t('downloadList'),
                      onPressed: () {
                        final docs = recentDocsAsync.asData?.value ?? [];
                        if (docs.isNotEmpty) {
                          ExportDownloadService.instance.showExportListBottomSheet(
                            context,
                            docs: docs,
                            customTitle: 'Recent Documents',
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No recent documents to download.')),
                          );
                        }
                      },
                    ),
                    TextButton(
                      onPressed: () => setState(() => _currentNavIndex = 1),
                      child: Text(l10n.t('viewAll')),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            recentDocsAsync.when(
              data: (docs) {
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.withOpacity(0.4)),
                          const SizedBox(height: 8),
                          Text(l10n.t('noRecentDocs'), style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(l10n.t('noRecentDocsSubtitle'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: docs.length > 4 ? 4 : docs.length,
                  itemBuilder: (ctx, index) {
                    final doc = docs[index];
                    return _buildRecentCard(context, doc, isDark, l10n);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickToolsGrid(BuildContext context, AppLocalizations l10n, bool isDark) {
    final tools = [
      _ToolTile(
        title: l10n.t('toolScan'),
        icon: Icons.crop_free_rounded,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen())),
      ),
      _ToolTile(
        title: l10n.t('toolAddText'),
        icon: Icons.text_fields_rounded,
        onTap: () => _openToolWithDocumentSelector(
          context,
          annotationMode: AnnotationMode.addText,
          toolTitle: l10n.t('toolAddText'),
          toolIcon: Icons.text_fields_rounded,
        ),
      ),
      _ToolTile(
        title: l10n.t('toolOCR'),
        icon: Icons.document_scanner_rounded,
        onTap: () => _openToolWithDocumentSelector(
          context,
          isOcr: true,
          toolTitle: l10n.t('toolOCR'),
          toolIcon: Icons.document_scanner_rounded,
        ),
      ),
      _ToolTile(
        title: l10n.t('toolMarkUp'),
        icon: Icons.edit_outlined,
        onTap: () => _openToolWithDocumentSelector(
          context,
          annotationMode: AnnotationMode.markup,
          toolTitle: l10n.t('toolMarkUp'),
          toolIcon: Icons.edit_outlined,
        ),
      ),
      _ToolTile(
        title: l10n.t('toolHide'),
        icon: Icons.auto_fix_normal_rounded,
        onTap: () => _openToolWithDocumentSelector(
          context,
          annotationMode: AnnotationMode.redact,
          toolTitle: l10n.t('toolHide'),
          toolIcon: Icons.auto_fix_normal_rounded,
        ),
      ),
      _ToolTile(
        title: l10n.t('tooleSign'),
        icon: Icons.gesture_rounded,
        onTap: () => _openToolWithDocumentSelector(
          context,
          isSign: true,
          toolTitle: l10n.t('tooleSign'),
          toolIcon: Icons.gesture_rounded,
        ),
      ),
      _ToolTile(
        title: l10n.t('toolImages'),
        icon: Icons.photo_library_outlined,
        onTap: _pickFromGallery,
      ),
      _ToolTile(
        title: l10n.t('toolMerge'),
        icon: Icons.all_inclusive_rounded,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfMergeScreen())),
      ),
      _ToolTile(
        title: l10n.t('toolSplit'),
        icon: Icons.view_column_rounded,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfCompressScreen())),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: 9,
      itemBuilder: (ctx, idx) {
        final t = tools[idx];
        return GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.all(10),
          onTap: t.onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(t.icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 8),
              Text(
                t.title,
                textAlign: TextAlign.center,
                maxLines: 1,
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
    );
  }

  Widget _buildRecentCard(BuildContext context, DocumentModel doc, bool isDark, AppLocalizations l10n) {
    final dateStr = DateFormat('HH:mm:ss dd-M-yy').format(doc.updatedAt);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentDetailScreen(documentId: doc.id),
          ),
        );
      },
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  color: isDark ? AppColors.cardSubtleDark : AppColors.cardSubtleLight,
                  child: doc.thumbnailPath != null && File(doc.thumbnailPath!).existsSync()
                      ? Image.file(
                          File(doc.thumbnailPath!),
                          fit: BoxFit.cover,
                        )
                      : const Center(
                          child: Icon(Icons.picture_as_pdf_outlined, color: Colors.grey, size: 36),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
                  onSelected: (val) async {
                    if (val == 'delete') {
                      await DatabaseHelper.instance.moveToTrash(doc.id);
                      ref.read(recentDocumentsProvider.notifier).load();
                      ref.read(allDocumentsProvider.notifier).load();
                    } else if (val == 'favorite') {
                      await DatabaseHelper.instance.toggleFavorite(doc.id, !doc.isFavorite);
                      ref.read(recentDocumentsProvider.notifier).load();
                    }
                  },
                  itemBuilder: (c) => [
                    PopupMenuItem(
                      value: 'favorite',
                      child: Text(doc.isFavorite ? 'Unfavorite' : 'Favorite'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.t('delete')),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              dateStr,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              '${doc.pageCount} ${l10n.t('pages')}',
              style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolTile {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  _ToolTile({required this.title, required this.icon, required this.onTap});
}

