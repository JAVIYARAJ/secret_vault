import 'package:equatable/equatable.dart';
import '../../models/project.dart';

abstract class ProjectState extends Equatable {
  const ProjectState();
  
  @override
  List<Object?> get props => [];
}

class ProjectInitial extends ProjectState {}

class ProjectLoading extends ProjectState {}

class ProjectLoaded extends ProjectState {
  final List<Project> projects;
  final String? selectedProjectId;
  final String? targetSecretId; // Optional secret to expand after loading project

  const ProjectLoaded(this.projects, this.selectedProjectId, {this.targetSecretId});

  @override
  List<Object?> get props => [projects, selectedProjectId, targetSecretId];
}

class ProjectError extends ProjectState {
  final String message;

  const ProjectError(this.message);

  @override
  List<Object?> get props => [message];
}
