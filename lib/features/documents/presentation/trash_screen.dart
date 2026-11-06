import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/app_providers.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final trashAsync = ref.watch(trashDocumentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('trashTitle')),
        actions: [
          IconButton(
            tooltip: 'Empty Trash',
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.t('deletePermanently')),
                  content: Text(l10n.t('trashNote')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.t('cancel'))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l10n.t('deletePermanently')),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await DatabaseHelper.instance.emptyTrash();
                ref.read(trashDocumentsProvider.notifier).load();
                ref.read(recentDocumentsProvider.notifier).load();
                ref.read(allDocumentsProvider.notifier).load();
              }
            },
          ),
        ],
      ),
      body: trashAsync.when(
        data: (docs) {
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delete_outline_rounded, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(l10n.t('trashEmpty'), style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (ctx, index) {
              final doc = docs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(doc.title),
                  subtitle: Text('${doc.pageCount} ${l10n.t('pages')} • ${doc.formattedSize}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore_rounded, color: AppColors.primary),
                        tooltip: l10n.t('restore'),
                        onPressed: () async {
                          await DatabaseHelper.instance.restoreFromTrash(doc.id);
                          ref.read(trashDocumentsProvider.notifier).load();
                          ref.read(recentDocumentsProvider.notifier).load();
                          ref.read(allDocumentsProvider.notifier).load();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                        tooltip: l10n.t('deletePermanently'),
                        onPressed: () async {
                          await DatabaseHelper.instance.deleteDocumentPermanently(doc.id);
                          ref.read(trashDocumentsProvider.notifier).load();
                        },
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
    );
  }
}

