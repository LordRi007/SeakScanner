import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/theme.dart';
import 'core/database/database_helper.dart';
import 'core/localization/app_localizations.dart';
import 'core/providers/app_providers.dart';
import 'features/onboarding/presentation/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Pre-initialize local database
  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    debugPrint('Database initialization notice: $e');
  }

  runApp(
    const ProviderScope(
      child: SeakScannerApp(),
    ),
  );
}

class SeakScannerApp extends ConsumerWidget {
  const SeakScannerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(languageProvider);

    return MaterialApp(
      title: 'SeakScanner',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(locale.languageCode),
      darkTheme: AppTheme.dark(locale.languageCode),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}
