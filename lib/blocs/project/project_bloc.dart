import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../models/project.dart';
import '../../services/storage_service.dart';
import 'project_event.dart';
import 'project_state.dart';

class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  final StorageService _storageService;
  final _uuid = const Uuid();

  ProjectBloc(this._storageService) : super(ProjectInitial()) {
    on<LoadProjects>(_onLoadProjects);
    on<AddProject>(_onAddProject);
    on<UpdateProject>(_onUpdateProject);
    on<DeleteProject>(_onDeleteProject);
    on<SelectProject>(_onSelectProject);
    on<ClearTargetSecret>(_onClearTargetSecret);
    on<ReorderProjects>(_onReorderProjects);
  }

  Future<void> _onReorderProjects(ReorderProjects event, Emitter<ProjectState> emit) async {
    final currentState = state;
    if (currentState is ProjectLoaded) {
      final projects = List<Project>.from(currentState.projects);
      if (event.oldIndex < 0 || event.oldIndex >= projects.length) return;
      
      final project = projects.removeAt(event.oldIndex);
      projects.insert(event.newIndex, project);

      // Persist new ordering only for changed items
      for (int i = 0; i < projects.length; i++) {
        if (projects[i].sortOrder != i) {
          projects[i] = projects[i].copyWith(sortOrder: i);
          await _storageService.saveProject(projects[i]);
        }
      }

      emit(ProjectLoaded(
        projects,
        currentState.selectedProjectId,
        targetSecretId: currentState.targetSecretId,
      ));
    }
  }

  void _onClearTargetSecret(ClearTargetSecret event, Emitter<ProjectState> emit) {
    final currentState = state;
    if (currentState is ProjectLoaded) {
      emit(ProjectLoaded(
        currentState.projects,
        currentState.selectedProjectId,
        targetSecretId: null,
      ));
    }
  }

  void _onLoadProjects(LoadProjects event, Emitter<ProjectState> emit) {
    emit(ProjectLoading());
    try {
      final projects = _storageService.getProjects();
      final String? selectedId = projects.isNotEmpty ? projects.first.id : null;
      emit(ProjectLoaded(projects, selectedId));
    } catch (e) {
      emit(ProjectError('Failed to load projects: ${e.toString()}'));
    }
  }

  void _onAddProject(AddProject event, Emitter<ProjectState> emit) async {
    final currentState = state;
    try {
      final newProject = Project(
        id: _uuid.v4(),
        name: event.name,
        description: event.description,
        createdAt: DateTime.now(),
        color: event.color,
        parentId: event.parentId,
      );
      await _storageService.saveProject(newProject);
      
      final projects = _storageService.getProjects();
      emit(ProjectLoaded(projects, newProject.id));
    } catch (e) {
      emit(ProjectError('Failed to add project: ${e.toString()}'));
      // Reload previous state
      if (currentState is ProjectLoaded) emit(currentState);
    }
  }

  void _onUpdateProject(UpdateProject event, Emitter<ProjectState> emit) async {
    final currentState = state;
    try {
      await _storageService.saveProject(event.project);
      final projects = _storageService.getProjects();
      if (currentState is ProjectLoaded) {
         emit(ProjectLoaded(projects, currentState.selectedProjectId));
      } else {
         emit(ProjectLoaded(projects, event.project.id));
      }
    } catch (e) {
      emit(ProjectError('Failed to update project: ${e.toString()}'));
    }
  }

  void _onDeleteProject(DeleteProject event, Emitter<ProjectState> emit) async {
    final currentState = state;
    if (currentState is ProjectLoaded) {
      try {
        await _deleteProjectRecursive(event.id, currentState.projects);
        final projects = _storageService.getProjects();
        String? selectedId = currentState.selectedProjectId == event.id 
            ? (projects.isNotEmpty ? projects.first.id : null) 
            : currentState.selectedProjectId;
            
        emit(ProjectLoaded(projects, selectedId));
      } catch (e) {
        emit(ProjectError('Failed to delete project: ${e.toString()}'));
      }
    }
  }

  Future<void> _deleteProjectRecursive(String projectId, List<Project> allProjects) async {
    // Find sub-projects
    final subProjects = allProjects.where((p) => p.parentId == projectId).toList();
    for (final sub in subProjects) {
      await _deleteProjectRecursive(sub.id, allProjects);
    }
    // Delete the project itself
    await _storageService.deleteProject(projectId);
  }

  void _onSelectProject(SelectProject event, Emitter<ProjectState> emit) {
    final currentState = state;
    if (currentState is ProjectLoaded) {
      emit(ProjectLoaded(
        currentState.projects,
        event.id,
        targetSecretId: event.targetSecretId,
      ));
    }
  }
}
