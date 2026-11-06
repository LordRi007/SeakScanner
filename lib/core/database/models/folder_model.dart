class FolderModel {
  final String id;
  final String name;
  final int colorValue;
  final String iconName;
  final DateTime createdAt;
  final int documentCount;

  const FolderModel({
    required this.id,
    required this.name,
    this.colorValue = 0xFF2563EB,
    this.iconName = 'folder',
    required this.createdAt,
    this.documentCount = 0,
  });

  FolderModel copyWith({
    String? id,
    String? name,
    int? colorValue,
    String? iconName,
    DateTime? createdAt,
    int? documentCount,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
      createdAt: createdAt ?? this.createdAt,
      documentCount: documentCount ?? this.documentCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color_value': colorValue,
      'icon_name': iconName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory FolderModel.fromMap(Map<String, dynamic> map, {int documentCount = 0}) {
    return FolderModel(
      id: map['id'] as String,
      name: map['name'] as String,
      colorValue: (map['color_value'] as num?)?.toInt() ?? 0xFF2563EB,
      iconName: (map['icon_name'] as String?) ?? 'folder',
      createdAt: DateTime.parse(map['created_at'] as String),
      documentCount: documentCount,
    );
  }
}

