import 'package:hive/hive.dart';

part 'project.g.dart';

@HiveType(typeId: 0)
class Project extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final int color;

  @HiveField(5)
  int sortOrder;

  @HiveField(6)
  final String? parentId;

  Project({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.color,
    this.sortOrder = 0,
    this.parentId,
  });

  Project copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    int? color,
    int? sortOrder,
    String? parentId,
  }) {
    final newProject = Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      parentId: parentId ?? this.parentId,
    );
    return newProject;
  }
}
