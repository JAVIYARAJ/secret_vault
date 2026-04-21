import 'package:equatable/equatable.dart';
import '../../models/audit_entry.dart';

abstract class AuditState extends Equatable {
  const AuditState();
  @override List<Object?> get props => [];
}

class AuditInitial extends AuditState {}
class AuditLoading extends AuditState {}

class AuditLoaded extends AuditState {
  final List<AuditEntry> entries;
  const AuditLoaded(this.entries);
  @override List<Object?> get props => [entries];
}

class AuditError extends AuditState {
  final String message;
  const AuditError(this.message);
  @override List<Object?> get props => [message];
}
