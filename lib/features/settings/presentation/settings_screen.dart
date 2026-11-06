import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/services/storage_service.dart';
import 'about_screen.dart';
import 'security_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(languageProvider);
    final scannerSettings = ref.watch(scannerSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('settingsTitle')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Appearance & Theme
          _buildSectionHeader(context, l10n.t('prefTheme')),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: Text(l10n.t('themeLight')),
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (val) {
                    if (val != null) ref.read(themeModeProvider.notifier).setTheme(val);
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: Text(l10n.t('themeDark')),
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (val) {
                    if (val != null) ref.read(themeModeProvider.notifier).setTheme(val);
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: Text(l10n.t('themeSystem')),
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (val) {
                    if (val != null) ref.read(themeModeProvider.notifier).setTheme(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Language Selection (English & Khmer)
          _buildSectionHeader(context, l10n.t('prefLanguage')),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('English (US)'),
                  value: 'en',
                  groupValue: locale.languageCode,
                  onChanged: (val) {
                    if (val != null) ref.read(languageProvider.notifier).setLanguage(val);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('ភាសាខ្មែរ (Khmer)'),
                  value: 'km',
                  groupValue: locale.languageCode,
                  onChanged: (val) {
                    if (val != null) ref.read(languageProvider.notifier).setLanguage(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Scanner & PDF Defaults
          _buildSectionHeader(context, 'Scanner Preferences'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.t('autoCapture')),
                  value: scannerSettings.autoCapture,
                  onChanged: (val) => ref.read(scannerSettingsProvider.notifier).toggleAutoCapture(),
                ),
                ListTile(
                  title: Text(l10n.t('ocrLanguage')),
                  trailing: DropdownButton<OcrLanguage>(
                    value: scannerSettings.ocrLanguage,
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem(value: OcrLanguage.english, child: Text(l10n.t('ocrLangEnglish'))),
                      DropdownMenuItem(value: OcrLanguage.khmer, child: Text(l10n.t('ocrLangKhmer'))),
                      DropdownMenuItem(value: OcrLanguage.mixed, child: Text(l10n.t('ocrLangMixed'))),
                    ],
                    onChanged: (val) {
                      if (val != null) ref.read(scannerSettingsProvider.notifier).setOcrLanguage(val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Security & Storage
          _buildSectionHeader(context, 'Security & Maintenance'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                  title: Text(l10n.t('securityTitle')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded, color: Colors.orangeAccent),
                  title: Text(l10n.t('clearCache')),
                  onTap: () async {
                    await StorageService.instance.clearCache();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.t('cacheCleared'))),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: AppColors.secondary),
                  title: Text(l10n.t('aboutApp')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
