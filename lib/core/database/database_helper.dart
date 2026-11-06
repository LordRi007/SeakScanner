import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'models/document_model.dart';
import 'models/folder_model.dart';
import 'models/page_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;
  static const _uuid = Uuid();

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    if (kIsWeb) {
      dbPath = 'seak_scanner.db';
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(docDir.path, 'seak_scanner.db');
    }

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Folders table
    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        icon_name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Documents table
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        folder_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        page_count INTEGER NOT NULL DEFAULT 1,
        pdf_path TEXT,
        thumbnail_path TEXT,
        file_size_bytes INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        ocr_full_text TEXT,
        FOREIGN KEY (folder_id) REFERENCES folders (id) ON DELETE SET NULL
      )
    ''');

    // Pages table
    await db.execute('''
      CREATE TABLE pages (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        page_index INTEGER NOT NULL,
        original_image_path TEXT NOT NULL,
        enhanced_image_path TEXT NOT NULL,
        thumbnail_path TEXT NOT NULL,
        ocr_text TEXT,
        filter_type TEXT NOT NULL DEFAULT 'magic',
        rotation_angle INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
      )
    ''');

    // Indexes for fast queries
    await db.execute('CREATE INDEX idx_docs_deleted ON documents(is_deleted)');
    await db.execute('CREATE INDEX idx_docs_favorite ON documents(is_favorite)');
    await db.execute('CREATE INDEX idx_docs_folder ON documents(folder_id)');
    await db.execute('CREATE INDEX idx_docs_updated ON documents(updated_at DESC)');
    await db.execute('CREATE INDEX idx_pages_doc ON pages(document_id, page_index)');

    // Seed default starter folders matching the reference mockup
    final now = DateTime.now().toIso8601String();
    await db.insert('folders', {
      'id': _uuid.v4(),
      'name': 'My Folders',
      'color_value': 0xFF2563EB, // Primary blue
      'icon_name': 'folder',
      'created_at': now,
    });
    await db.insert('folders', {
      'id': _uuid.v4(),
      'name': 'Applications',
      'color_value': 0xFF06B6D4, // Cyan
      'icon_name': 'description',
      'created_at': now,
    });
    await db.insert('folders', {
      'id': _uuid.v4(),
      'name': 'Work & Contracts',
      'color_value': 0xFF6366F1, // Indigo
      'icon_name': 'work',
      'created_at': now,
    });
    await db.insert('folders', {
      'id': _uuid.v4(),
      'name': 'Receipts & Bills',
      'color_value': 0xFF10B981, // Emerald
      'icon_name': 'receipt',
      'created_at': now,
    });
  }

  // ---------------------------------------------------------------------------
  // Document Queries
  // ---------------------------------------------------------------------------

  Future<List<DocumentModel>> getRecentDocuments({int limit = 20}) async {
    final db = await database;
    final maps = await db.query(
      'documents',
      where: 'is_deleted = 0',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return maps.map(DocumentModel.fromMap).toList();
  }

  Future<List<DocumentModel>> getAllDocuments({
    String? folderId,
    bool favoritesOnly = false,
    String? searchQuery,
    String sortBy = 'date_desc',
  }) async {
    final db = await database;
    final whereClauses = <String>['is_deleted = 0'];
    final whereArgs = <dynamic>[];

    if (folderId != null) {
      whereClauses.add('folder_id = ?');
      whereArgs.add(folderId);
    }
    if (favoritesOnly) {
      whereClauses.add('is_favorite = 1');
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(title LIKE ? OR ocr_full_text LIKE ?)');
      final term = '%${searchQuery.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
    }

    String orderBy;
    switch (sortBy) {
      case 'date_asc':
        orderBy = 'updated_at ASC';
        break;
      case 'name_asc':
        orderBy = 'title ASC';
        break;
      case 'name_desc':
        orderBy = 'title DESC';
        break;
      case 'size_desc':
        orderBy = 'file_size_bytes DESC';
        break;
      case 'date_desc':
      default:
        orderBy = 'updated_at DESC';
        break;
    }

    final maps = await db.query(
      'documents',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy,
    );
    return maps.map(DocumentModel.fromMap).toList();
  }

  Future<List<DocumentModel>> getTrashDocuments() async {
    final db = await database;
    final maps = await db.query(
      'documents',
      where: 'is_deleted = 1',
      orderBy: 'deleted_at DESC',
    );
    return maps.map(DocumentModel.fromMap).toList();
  }

  Future<DocumentModel?> getDocumentById(String id) async {
    final db = await database;
    final maps = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DocumentModel.fromMap(maps.first);
  }

  Future<int> getTotalScannedCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM documents WHERE is_deleted = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> insertDocument(DocumentModel doc) async {
    final db = await database;
    await db.insert(
      'documents',
      doc.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateDocument(DocumentModel doc) async {
    final db = await database;
    await db.update(
      'documents',
      doc.toMap(),
      where: 'id = ?',
      whereArgs: [doc.id],
    );
  }

  Future<void> toggleFavorite(String id, bool isFavorite) async {
    final db = await database;
    await db.update(
      'documents',
      {'is_favorite': isFavorite ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> moveToTrash(String id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'documents',
      {'is_deleted': 1, 'deleted_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreFromTrash(String id) async {
    final db = await database;
    await db.update(
      'documents',
      {'is_deleted': 0, 'deleted_at': null, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDocumentPermanently(String id) async {
    final db = await database;
    // Delete pages and files
    final pages = await getPagesForDocument(id);
    for (final page in pages) {
      _deleteFileSilently(page.originalImagePath);
      _deleteFileSilently(page.enhancedImagePath);
      _deleteFileSilently(page.thumbnailPath);
    }
    final doc = await getDocumentById(id);
    if (doc?.pdfPath != null) {
      _deleteFileSilently(doc!.pdfPath!);
    }
    await db.delete('pages', where: 'document_id = ?', whereArgs: [id]);
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> emptyTrash() async {
    final trashDocs = await getTrashDocuments();
    for (final doc in trashDocs) {
      await deleteDocumentPermanently(doc.id);
    }
  }

  void _deleteFileSilently(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Page Queries
  // ---------------------------------------------------------------------------

  Future<List<PageModel>> getPagesForDocument(String documentId) async {
    final db = await database;
    final maps = await db.query(
      'pages',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'page_index ASC',
    );
    return maps.map(PageModel.fromMap).toList();
  }

  Future<void> insertPage(PageModel page) async {
    final db = await database;
    await db.insert('pages', page.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updatePage(PageModel page) async {
    final db = await database;
    await db.update(
      'pages',
      page.toMap(),
      where: 'id = ?',
      whereArgs: [page.id],
    );
  }

  Future<void> deletePage(String pageId, String documentId) async {
    final db = await database;
    await db.delete('pages', where: 'id = ?', whereArgs: [pageId]);
    // Re-index remaining pages
    final remaining = await getPagesForDocument(documentId);
    for (int i = 0; i < remaining.length; i++) {
      if (remaining[i].pageIndex != i) {
        await db.update(
          'pages',
          {'page_index': i},
          where: 'id = ?',
          whereArgs: [remaining[i].id],
        );
      }
    }
    // Update doc page_count
    await db.update(
      'documents',
      {'page_count': remaining.length, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  Future<void> updatePagesOrder(String documentId, List<String> pageIdsInOrder) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < pageIdsInOrder.length; i++) {
      batch.update(
        'pages',
        {'page_index': i},
        where: 'id = ? AND document_id = ?',
        whereArgs: [pageIdsInOrder[i], documentId],
      );
    }
    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------------
  // Folder Queries
  // ---------------------------------------------------------------------------

  Future<List<FolderModel>> getFolders() async {
    final db = await database;
    final maps = await db.query('folders', orderBy: 'name ASC');
    final folders = <FolderModel>[];

    for (final map in maps) {
      final folderId = map['id'] as String;
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM documents WHERE folder_id = ? AND is_deleted = 0',
        [folderId],
      );
      final count = Sqflite.firstIntValue(countResult) ?? 0;
      folders.add(FolderModel.fromMap(map, documentCount: count));
    }
    return folders;
  }

  Future<void> insertFolder(FolderModel folder) async {
    final db = await database;
    await db.insert('folders', folder.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateFolder(FolderModel folder) async {
    final db = await database;
    await db.update('folders', folder.toMap(), where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<void> deleteFolder(String folderId) async {
    final db = await database;
    // Set docs in this folder to null (unfiled)
    await db.update(
      'documents',
      {'folder_id': null},
      where: 'folder_id = ?',
      whereArgs: [folderId],
    );
    await db.delete('folders', where: 'id = ?', whereArgs: [folderId]);
  }

  Future<void> moveDocumentToFolder(String documentId, String? folderId) async {
    final db = await database;
    await db.update(
      'documents',
      {'folder_id': folderId, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }
}

