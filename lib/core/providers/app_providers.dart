import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../database/models/document_model.dart';
import '../database/models/folder_model.dart';
import '../services/ocr_service.dart';
import '../services/pdf_service.dart';

// -----------------------------------------------------------------------------
// Settings Providers
// -----------------------------------------------------------------------------

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('theme_mode') ?? 'light';
    switch (mode) {
      case 'dark':
        state = ThemeMode.dark;
        break;
      case 'system':
        state = ThemeMode.system;
        break;
      case 'light':
      default:
        state = ThemeMode.light;
        break;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    String modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    if (mode == ThemeMode.system) modeStr = 'system';
    await prefs.setString('theme_mode', modeStr);
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, Locale>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<Locale> {
  LanguageNotifier() : super(const Locale('en')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('app_language') ?? 'en';
    state = Locale(lang);
  }

  Future<void> setLanguage(String code) async {
    state = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
  }
}

// -----------------------------------------------------------------------------
// Scanner Settings Providers
// -----------------------------------------------------------------------------

class ScannerSettings {
  final bool autoCapture;
  final bool gridEnabled;
  final String flashMode; // 'off', 'auto', 'torch'
  final PdfPageFormatType defaultPageSize;
  final OcrLanguage ocrLanguage;

  const ScannerSettings({
    this.autoCapture = true,
    this.gridEnabled = false,
    this.flashMode = 'off',
    this.defaultPageSize = PdfPageFormatType.a4,
    this.ocrLanguage = OcrLanguage.mixed,
  });

  ScannerSettings copyWith({
    bool? autoCapture,
    bool? gridEnabled,
    String? flashMode,
    PdfPageFormatType? defaultPageSize,
    OcrLanguage? ocrLanguage,
  }) {
    return ScannerSettings(
      autoCapture: autoCapture ?? this.autoCapture,
      gridEnabled: gridEnabled ?? this.gridEnabled,
      flashMode: flashMode ?? this.flashMode,
      defaultPageSize: defaultPageSize ?? this.defaultPageSize,
      ocrLanguage: ocrLanguage ?? this.ocrLanguage,
    );
  }
}

final scannerSettingsProvider =
    StateNotifierProvider<ScannerSettingsNotifier, ScannerSettings>((ref) {
  return ScannerSettingsNotifier();
});

class ScannerSettingsNotifier extends StateNotifier<ScannerSettings> {
  ScannerSettingsNotifier() : super(const ScannerSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ScannerSettings(
      autoCapture: prefs.getBool('auto_capture') ?? true,
      gridEnabled: prefs.getBool('grid_enabled') ?? false,
      flashMode: prefs.getString('flash_mode') ?? 'off',
    );
  }

  void toggleAutoCapture() async {
    state = state.copyWith(autoCapture: !state.autoCapture);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_capture', state.autoCapture);
  }

  void toggleGrid() async {
    state = state.copyWith(gridEnabled: !state.gridEnabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('grid_enabled', state.gridEnabled);
  }

  void setFlashMode(String mode) async {
    state = state.copyWith(flashMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flash_mode', mode);
  }

  void setOcrLanguage(OcrLanguage lang) {
    state = state.copyWith(ocrLanguage: lang);
  }
}

// -----------------------------------------------------------------------------
// Database Notifiers & Providers
// -----------------------------------------------------------------------------

final recentDocumentsProvider =
    StateNotifierProvider<RecentDocumentsNotifier, AsyncValue<List<DocumentModel>>>(
        (ref) => RecentDocumentsNotifier());

class RecentDocumentsNotifier extends StateNotifier<AsyncValue<List<DocumentModel>>> {
  RecentDocumentsNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final list = await DatabaseHelper.instance.getRecentDocuments(limit: 10);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final allDocumentsProvider =
    StateNotifierProvider<AllDocumentsNotifier, AsyncValue<List<DocumentModel>>>(
        (ref) => AllDocumentsNotifier());

class AllDocumentsNotifier extends StateNotifier<AsyncValue<List<DocumentModel>>> {
  String? _folderId;
  bool _favoritesOnly = false;
  String? _searchQuery;
  String _sortBy = 'date_desc';

  AllDocumentsNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({
    String? folderId,
    bool? favoritesOnly,
    String? searchQuery,
    String? sortBy,
  }) async {
    if (folderId != null) _folderId = folderId;
    if (favoritesOnly != null) _favoritesOnly = favoritesOnly;
    if (searchQuery != null) _searchQuery = searchQuery;
    if (sortBy != null) _sortBy = sortBy;

    try {
      final list = await DatabaseHelper.instance.getAllDocuments(
        folderId: _folderId,
        favoritesOnly: _favoritesOnly,
        searchQuery: _searchQuery,
        sortBy: _sortBy,
      );
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void resetFilter() {
    _folderId = null;
    _favoritesOnly = false;
    _searchQuery = null;
    _sortBy = 'date_desc';
    load();
  }
}

final foldersProvider =
    StateNotifierProvider<FoldersNotifier, AsyncValue<List<FolderModel>>>((ref) {
  return FoldersNotifier();
});

class FoldersNotifier extends StateNotifier<AsyncValue<List<FolderModel>>> {
  FoldersNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final list = await DatabaseHelper.instance.getFolders();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createFolder(String name, int colorValue) async {
    final folder = FolderModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      colorValue: colorValue,
      createdAt: DateTime.now(),
    );
    await DatabaseHelper.instance.insertFolder(folder);
    await load();
  }
}

final trashDocumentsProvider =
    StateNotifierProvider<TrashDocumentsNotifier, AsyncValue<List<DocumentModel>>>(
        (ref) => TrashDocumentsNotifier());

class TrashDocumentsNotifier extends StateNotifier<AsyncValue<List<DocumentModel>>> {
  TrashDocumentsNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final list = await DatabaseHelper.instance.getTrashDocuments();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final totalScannedProvider = FutureProvider<int>((ref) async {
  return await DatabaseHelper.instance.getTotalScannedCount();
});

