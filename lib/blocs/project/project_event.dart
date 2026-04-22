import 'package:equatable/equatable.dart';
import '../../models/project.dart';

abstract class ProjectEvent extends Equatable {
  const ProjectEvent();

  @override
  List<Object?> get props => [];
}

class LoadProjects extends ProjectEvent {}

class AddProject extends ProjectEvent {
  final String name;
  final String? description;
  final int color;
  final String? parentId;

  const AddProject(this.name, this.description, this.color, {this.parentId});

  @override
  List<Object?> get props => [name, description, color, parentId];
}

class UpdateProject extends ProjectEvent {
  final Project project;

  const UpdateProject(this.project);

  @override
  List<Object?> get props => [project];
}

class DeleteProject extends ProjectEvent {
  final String id;

  const DeleteProject(this.id);

  @override
  List<Object?> get props => [id];
}

class SelectProject extends ProjectEvent {
  final String? id;
  final String? targetSecretId;

  const SelectProject(this.id, {this.targetSecretId});

  @override
  List<Object?> get props => [id, targetSecretId];
}

class ClearTargetSecret extends ProjectEvent {}

class ReorderProjects extends ProjectEvent {
  final int oldIndex;
  final int newIndex;

  const ReorderProjects(this.oldIndex, this.newIndex);

  @override
  List<Object?> get props => [oldIndex, newIndex];
}
