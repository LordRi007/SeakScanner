import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  Directory? _baseDir;

  Future<Directory> get baseDirectory async {
    if (_baseDir != null) return _baseDir!;
    if (kIsWeb) {
      _baseDir = Directory.current;
      return _baseDir!;
    }
    _baseDir = await getApplicationDocumentsDirectory();
    return _baseDir!;
  }

  Future<Directory> getSubdirectory(String sub) async {
    final base = await baseDirectory;
    final dir = Directory(p.join(base.path, 'seak_scanner', sub));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> saveImageBytes(Uint8List bytes, {required String sub, required String filename}) async {
    final dir = await getSubdirectory(sub);
    final filePath = p.join(dir.path, filename);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return filePath;
  }

  Future<String> getUniquePdfPath(String title) async {
    final dir = await getSubdirectory('documents');
    final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, '${safeTitle}_$timestamp.pdf');
  }

  Future<int> getTotalAppStorageBytes() async {
    try {
      final base = await baseDirectory;
      final rootDir = Directory(p.join(base.path, 'seak_scanner'));
      if (!await rootDir.exists()) return 0;

      int total = 0;
      await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearCache() async {
    try {
      final cacheDir = await getSubdirectory('cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// Resolves the public device Downloads directory across Android, iOS, Windows, macOS, Linux
  Future<Directory> getDownloadsDirectoryPath() async {
    if (kIsWeb) {
      return Directory.current;
    }

    if (Platform.isAndroid) {
      // 1. Primary Android public Download directory
      final publicDownload = Directory('/storage/emulated/0/Download');
      try {
        if (await publicDownload.exists()) {
          return publicDownload;
        }
      } catch (_) {}

      // 2. Fallback to external storage Downloads
      try {
        final extList = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (extList != null && extList.isNotEmpty && await extList.first.exists()) {
          return extList.first;
        }
      } catch (_) {}

      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final downDir = Directory(p.join(ext.path, 'Download'));
          if (!await downDir.exists()) {
            await downDir.create(recursive: true);
          }
          return downDir;
        }
      } catch (_) {}
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      try {
        final dir = await getDownloadsDirectory();
        if (dir != null && await dir.exists()) {
          return dir;
        }
      } catch (_) {}
    }

    // Default iOS and general fallback to App Documents
    return await getApplicationDocumentsDirectory();
  }

  /// Saves raw bytes to a file in the device Downloads directory with collision avoidance
  Future<String> saveFileToDownloads(List<int> bytes, String fileName) async {
    final downloadsDir = await getDownloadsDirectoryPath();
    final sanitized = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    String targetPath = p.join(downloadsDir.path, sanitized);
    if (await File(targetPath).exists()) {
      final baseName = p.basenameWithoutExtension(sanitized);
      final ext = p.extension(sanitized);
      int counter = 1;
      while (await File(targetPath).exists()) {
        targetPath = p.join(downloadsDir.path, '${baseName}_$counter$ext');
        counter++;
      }
    }

    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile.path;
  }

  /// Copies an existing file (e.g. enhanced page image or PDF) into the device Downloads directory
  Future<String> copyFileToDownloads(String sourceFilePath, {String? targetFileName}) async {
    final sourceFile = File(sourceFilePath);
    if (!await sourceFile.exists()) {
      throw Exception('Source file does not exist at: $sourceFilePath');
    }
    final bytes = await sourceFile.readAsBytes();
    final name = targetFileName ?? p.basename(sourceFilePath);
    return await saveFileToDownloads(bytes, name);
  }
}

