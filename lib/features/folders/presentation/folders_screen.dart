import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/glass_card.dart';
import '../../documents/presentation/documents_screen.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  void _showNewFolderDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textCtrl = TextEditingController();
    int selectedColor = 0xFF2563EB;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.t('newFolder')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                autofocus: true,
                decoration: InputDecoration(hintText: l10n.t('folderName')),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [0xFF2563EB, 0xFF06B6D4, 0xFF6366F1, 0xFF10B981, 0xFFF59E0B].map((c) {
                  final isSel = selectedColor == c;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = textCtrl.text.trim();
                if (name.isNotEmpty) {
                  await ref.read(foldersProvider.notifier).createFolder(name, selectedColor);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: Text(l10n.t('create')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final foldersAsync = ref.watch(foldersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('myFolders')),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _showNewFolderDialog(context, ref),
          ),
        ],
      ),
      body: foldersAsync.when(
        data: (folders) {
          if (folders.isEmpty) {
            return Center(child: Text(l10n.t('noRecentDocs')));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.25,
            ),
            itemCount: folders.length,
            itemBuilder: (ctx, index) {
              final folder = folders[index];
              return GlassCard(
                borderRadius: 20,
                color: Color(folder.colorValue).withOpacity(0.1),
                border: Border.all(color: Color(folder.colorValue).withOpacity(0.3)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => DocumentsScreen(
                        folderId: folder.id,
                        folderTitle: folder.name,
                      ),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(folder.colorValue),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.folder_rounded, color: Colors.white, size: 24),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folder.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${folder.documentCount} Files',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }
}
