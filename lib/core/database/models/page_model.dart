class PageModel {
  final String id;
  final String documentId;
  final int pageIndex;
  final String originalImagePath;
  final String enhancedImagePath;
  final String thumbnailPath;
  final String? ocrText;
  final String filterType;
  final int rotationAngle;
  final DateTime createdAt;

  const PageModel({
    required this.id,
    required this.documentId,
    required this.pageIndex,
    required this.originalImagePath,
    required this.enhancedImagePath,
    required this.thumbnailPath,
    this.ocrText,
    this.filterType = 'magic',
    this.rotationAngle = 0,
    required this.createdAt,
  });

  PageModel copyWith({
    String? id,
    String? documentId,
    int? pageIndex,
    String? originalImagePath,
    String? enhancedImagePath,
    String? thumbnailPath,
    String? ocrText,
    String? filterType,
    int? rotationAngle,
    DateTime? createdAt,
  }) {
    return PageModel(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      pageIndex: pageIndex ?? this.pageIndex,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      enhancedImagePath: enhancedImagePath ?? this.enhancedImagePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      ocrText: ocrText ?? this.ocrText,
      filterType: filterType ?? this.filterType,
      rotationAngle: rotationAngle ?? this.rotationAngle,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'page_index': pageIndex,
      'original_image_path': originalImagePath,
      'enhanced_image_path': enhancedImagePath,
      'thumbnail_path': thumbnailPath,
      'ocr_text': ocrText,
      'filter_type': filterType,
      'rotation_angle': rotationAngle,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PageModel.fromMap(Map<String, dynamic> map) {
    return PageModel(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      pageIndex: (map['page_index'] as num?)?.toInt() ?? 0,
      originalImagePath: map['original_image_path'] as String,
      enhancedImagePath: map['enhanced_image_path'] as String,
      thumbnailPath: map['thumbnail_path'] as String,
      ocrText: map['ocr_text'] as String?,
      filterType: (map['filter_type'] as String?) ?? 'magic',
      rotationAngle: (map['rotation_angle'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

