class DocumentModel {
  final String id;
  final String title;
  final String? folderId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int pageCount;
  final String? pdfPath;
  final String? thumbnailPath;
  final int fileSizeBytes;
  final bool isFavorite;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? ocrFullText;

  const DocumentModel({
    required this.id,
    required this.title,
    this.folderId,
    required this.createdAt,
    required this.updatedAt,
    this.pageCount = 1,
    this.pdfPath,
    this.thumbnailPath,
    this.fileSizeBytes = 0,
    this.isFavorite = false,
    this.isDeleted = false,
    this.deletedAt,
    this.ocrFullText,
  });

  DocumentModel copyWith({
    String? id,
    String? title,
    String? folderId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? pageCount,
    String? pdfPath,
    String? thumbnailPath,
    int? fileSizeBytes,
    bool? isFavorite,
    bool? isDeleted,
    DateTime? deletedAt,
    String? ocrFullText,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      folderId: folderId ?? this.folderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pageCount: pageCount ?? this.pageCount,
      pdfPath: pdfPath ?? this.pdfPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      isFavorite: isFavorite ?? this.isFavorite,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      ocrFullText: ocrFullText ?? this.ocrFullText,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'folder_id': folderId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'page_count': pageCount,
      'pdf_path': pdfPath,
      'thumbnail_path': thumbnailPath,
      'file_size_bytes': fileSizeBytes,
      'is_favorite': isFavorite ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'deleted_at': deletedAt?.toIso8601String(),
      'ocr_full_text': ocrFullText,
    };
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    return DocumentModel(
      id: map['id'] as String,
      title: map['title'] as String,
      folderId: map['folder_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      pageCount: (map['page_count'] as num?)?.toInt() ?? 1,
      pdfPath: map['pdf_path'] as String?,
      thumbnailPath: map['thumbnail_path'] as String?,
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      deletedAt: map['deleted_at'] != null
          ? DateTime.tryParse(map['deleted_at'] as String)
          : null,
      ocrFullText: map['ocr_full_text'] as String?,
    );
  }

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

