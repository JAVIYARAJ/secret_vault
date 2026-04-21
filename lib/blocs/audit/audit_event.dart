import 'package:equatable/equatable.dart';
import '../../models/audit_entry.dart';

abstract class AuditEvent extends Equatable {
  const AuditEvent();
  @override List<Object?> get props => [];
}

class LogAuditEntry extends AuditEvent {
  final String projectId;
  final String projectName;
  final String secretId;
  final String secretTitle;
  final AuditAction action;
  final String? fieldLabel;
  final String? metadata;

  const LogAuditEntry({
    required this.projectId,
    required this.projectName,
    required this.secretId,
    required this.secretTitle,
    required this.action,
    this.fieldLabel,
    this.metadata,
  });

  @override
  List<Object?> get props => [secretId, action, fieldLabel, metadata];
}

class LoadAuditLog extends AuditEvent {
  final String? projectId; // null = all projects
  const LoadAuditLog({this.projectId});
  @override List<Object?> get props => [projectId];
}

class ClearAuditLog extends AuditEvent {
  final String? projectId;
  const ClearAuditLog({this.projectId});
  @override List<Object?> get props => [projectId];
}

class ExportAuditLog extends AuditEvent {
  final String? projectId;
  const ExportAuditLog({this.projectId});
  @override List<Object?> get props => [projectId];
}
