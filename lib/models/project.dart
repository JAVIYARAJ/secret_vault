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

  Project({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.color,
    this.sortOrder = 0,
  });
}
