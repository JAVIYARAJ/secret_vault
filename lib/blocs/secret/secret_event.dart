import 'package:equatable/equatable.dart';
import '../../models/secret.dart';

abstract class SecretEvent extends Equatable {
  const SecretEvent();

  @override
  List<Object?> get props => [];
}

class LoadSecrets extends SecretEvent {
  final String? projectId;
  final String? initialExpandedId;

  const LoadSecrets(this.projectId, {this.initialExpandedId});

  @override
  List<Object?> get props => [projectId, initialExpandedId];
}

class AddSecret extends SecretEvent {
  final String projectId;
  final String title;
  final SecretType type;
  final List<SecretField> fields;
  final String? note;
  final List<String>? tags;

  const AddSecret(this.projectId, this.title, this.type, this.fields, this.note, this.tags);

  @override
  List<Object?> get props => [projectId, title, type, fields, note, tags];
}

class UpdateSecret extends SecretEvent {
  final Secret secret;

  const UpdateSecret(this.secret);

  @override
  List<Object?> get props => [secret];
}

class DeleteSecret extends SecretEvent {
  final String id;

  const DeleteSecret(this.id);

  @override
  List<Object?> get props => [id];
}

class ToggleRevealField extends SecretEvent {
  final String secretId;
  final String fieldId;

  const ToggleRevealField(this.secretId, this.fieldId);

  @override
  List<Object?> get props => [secretId, fieldId];
}

class CopyField extends SecretEvent {
  final String secretId;
  final String fieldId;

  const CopyField(this.secretId, this.fieldId);

  @override
  List<Object?> get props => [secretId, fieldId];
}

class AddCustomField extends SecretEvent {
  final String secretId;

  const AddCustomField(this.secretId);

  @override
  List<Object?> get props => [secretId];
}

class RemoveCustomField extends SecretEvent {
  final String secretId;
  final String fieldId;

  const RemoveCustomField(this.secretId, this.fieldId);

  @override
  List<Object?> get props => [secretId, fieldId];
}

class SearchSecrets extends SecretEvent {
  final String query;

  const SearchSecrets(this.query);

  @override
  List<Object?> get props => [query];
}

class FilterByType extends SecretEvent {
  final SecretType? type;

  const FilterByType(this.type);

  @override
  List<Object?> get props => [type];
}

class SetExpandedSecret extends SecretEvent {
  final String? secretId;
  const SetExpandedSecret(this.secretId);

  @override
  List<Object?> get props => [secretId];
}

class ClearSecretExpansion extends SecretEvent {}

class ReorderSecrets extends SecretEvent {
  final String projectId;
  final int oldIndex;
  final int newIndex;

  const ReorderSecrets(this.projectId, this.oldIndex, this.newIndex);

  @override
  List<Object?> get props => [projectId, oldIndex, newIndex];
}

class MoveSecretToProject extends SecretEvent {
  final String secretId;
  final String fromProjectId;
  final String toProjectId;

  const MoveSecretToProject({
    required this.secretId,
    required this.fromProjectId,
    required this.toProjectId,
  });

  @override
  List<Object?> get props => [secretId, fromProjectId, toProjectId];
}

class ToggleFavourite extends SecretEvent {
  final String secretId;

  const ToggleFavourite(this.secretId);

  @override
  List<Object?> get props => [secretId];
}

class ClearSecrets extends SecretEvent {}
