import 'package:hive/hive.dart';

part 'audit_entry.g.dart';

@HiveType(typeId: 3)
enum AuditAction {
  @HiveField(0) accessed,
  @HiveField(1) copied,
  @HiveField(2) revealed,
  @HiveField(3) edited,
  @HiveField(4) deleted,
  @HiveField(5) created
}

@HiveType(typeId: 4)
class AuditEntry extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late String projectId;
  @HiveField(2) late String projectName;
  @HiveField(3) late String secretId;
  @HiveField(4) late String secretTitle;
  @HiveField(5) late int actionIndex; // AuditAction.index
  @HiveField(6) late DateTime timestamp;
  @HiveField(7) String? fieldLabel; // which field was copied/revealed
  @HiveField(8) String? metadata; // detailed change description (e.g. "Title changed: A -> B")

  AuditAction get action => AuditAction.values[actionIndex];
}
