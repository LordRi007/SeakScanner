import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/models/document_model.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/export_download_service.dart';
import '../../../core/widgets/glass_card.dart';
import 'document_detail_screen.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  final String? folderId;
  final String? folderTitle;
  final bool favoritesOnly;

  const DocumentsScreen({
    super.key,
    this.folderId,
    this.folderTitle,
    this.favoritesOnly = false,
  });

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  bool _isGridView = true;
  String _searchQuery = '';
  String _sortBy = 'date_desc';
  bool _isBatchMode = false;
  final Set<String> _selectedIds = {};

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(allDocumentsProvider.notifier).load(
            folderId: widget.folderId,
            favoritesOnly: widget.favoritesOnly,
            sortBy: _sortBy,
          );
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    setState(() => _searchQuery = q);
    ref.read(allDocumentsProvider.notifier).load(
          folderId: widget.folderId,
          favoritesOnly: widget.favoritesOnly,
          searchQuery: q,
          sortBy: _sortBy,
        );
  }

  Future<void> _batchDelete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('moveToTrash')),
        content: Text('Move ${_selectedIds.length} ${l10n.t('itemsSelected')} to trash?'),
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
      for (final id in _selectedIds) {
        await DatabaseHelper.instance.moveToTrash(id);
      }
      setState(() {
        _selectedIds.clear();
        _isBatchMode = false;
      });
      ref.read(recentDocumentsProvider.notifier).load();
      ref.read(allDocumentsProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final docsAsync = ref.watch(allDocumentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = widget.folderTitle ??
        (widget.favoritesOnly ? l10n.t('favorites') : l10n.t('allDocuments'));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isBatchMode ? '${_selectedIds.length} ${l10n.t('itemsSelected')}' : title),
        actions: [
          if (_isBatchMode) ...[
            IconButton(
              icon: const Icon(Icons.file_download_outlined, color: AppColors.primary),
              tooltip: l10n.t('downloadSelected'),
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () {
                      final docs = docsAsync.asData?.value ?? [];
                      final selectedDocs = docs.where((d) => _selectedIds.contains(d.id)).toList();
                      if (selectedDocs.isNotEmpty) {
                        ExportDownloadService.instance.showExportListBottomSheet(
                          context,
                          docs: selectedDocs,
                          customTitle: 'Selected Documents (${selectedDocs.length})',
                        );
                      }
                    },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: _selectedIds.isEmpty ? null : _batchDelete,
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _isBatchMode = false;
                _selectedIds.clear();
              }),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: l10n.t('downloadList'),
              onPressed: () {
                final docs = docsAsync.asData?.value ?? [];
                if (docs.isNotEmpty) {
                  ExportDownloadService.instance.showExportListBottomSheet(
                    context,
                    docs: docs,
                    customTitle: title,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No documents to download.')),
                  );
                }
              },
            ),
            IconButton(
              icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort_rounded),
              onSelected: (val) {
                setState(() => _sortBy = val);
                ref.read(allDocumentsProvider.notifier).load(sortBy: val);
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'date_desc', child: Text(l10n.t('sortDateNewest'))),
                PopupMenuItem(value: 'date_asc', child: Text(l10n.t('sortDateOldest'))),
                PopupMenuItem(value: 'name_asc', child: Text(l10n.t('sortNameAZ'))),
                PopupMenuItem(value: 'name_desc', child: Text(l10n.t('sortNameZA'))),
                PopupMenuItem(value: 'size_desc', child: Text(l10n.t('sortSize'))),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: l10n.t('searchHint'),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Documents List / Grid
          Expanded(
            child: docsAsync.when(
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined, size: 56, color: Colors.grey.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text(
                          l10n.t('noRecentDocs'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.t('noRecentDocsSubtitle'),
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (_isGridView) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (ctx, index) {
                      final doc = docs[index];
                      final isSelected = _selectedIds.contains(doc.id);
                      return _buildDocumentCard(doc, isSelected, isDark, l10n);
                    },
                  );
                } else {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: docs.length,
                    itemBuilder: (ctx, index) {
                      final doc = docs[index];
                      final isSelected = _selectedIds.contains(doc.id);
                      return _buildDocumentListTile(doc, isSelected, l10n);
                    },
                  );
                }
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(child: Text(e.toString())),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(DocumentModel doc, bool isSelected, bool isDark, AppLocalizations l10n) {
    final dateStr = DateFormat('HH:mm:ss dd-M-yy').format(doc.updatedAt);

    return GestureDetector(
      onLongPress: () {
        setState(() {
          _isBatchMode = true;
          _selectedIds.add(doc.id);
        });
      },
      onTap: () {
        if (_isBatchMode) {
          setState(() {
            if (isSelected) {
              _selectedIds.remove(doc.id);
            } else {
              _selectedIds.add(doc.id);
            }
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => DocumentDetailScreen(documentId: doc.id),
            ),
          );
        }
      },
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(12),
        border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail preview
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
                      : Center(
                          child: Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 40,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Title & Options
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
                if (doc.isFavorite)
                  const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
              ],
            ),
            const SizedBox(height: 4),

            // Metadata: date & pages
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

  Widget _buildDocumentListTile(DocumentModel doc, bool isSelected, AppLocalizations l10n) {
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(doc.updatedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected ? const BorderSide(color: AppColors.primary, width: 2) : BorderSide.none,
      ),
      child: ListTile(
        onLongPress: () => setState(() {
          _isBatchMode = true;
          _selectedIds.add(doc.id);
        }),
        onTap: () {
          if (_isBatchMode) {
            setState(() {
              if (isSelected) {
                _selectedIds.remove(doc.id);
              } else {
                _selectedIds.add(doc.id);
              }
            });
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => DocumentDetailScreen(documentId: doc.id)),
            );
          }
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 44,
            height: 56,
            child: doc.thumbnailPath != null && File(doc.thumbnailPath!).existsSync()
                ? Image.file(File(doc.thumbnailPath!), fit: BoxFit.cover)
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
        ),
        title: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('$dateStr • ${doc.pageCount} ${l10n.t('pages')} • ${doc.formattedSize}'),
        trailing: doc.isFavorite ? const Icon(Icons.star_rounded, color: Colors.amber) : null,
      ),
    );
  }
}

