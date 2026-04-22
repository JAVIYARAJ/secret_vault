import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/project.dart';
import '../blocs/project/project_bloc.dart';
import '../blocs/project/project_event.dart';
import '../blocs/secret/secret_bloc.dart';
import '../blocs/secret/secret_event.dart';
import 'project_tile.dart';
import 'app_toast.dart';

class ProjectTree extends StatefulWidget {
  final List<Project> projects;
  final String? parentId;
  final String? selectedProjectId;
  final Function(Project) onEdit;
  final Function(Project) onDelete;
  final int depth;

  const ProjectTree({
    super.key,
    required this.projects,
    this.parentId,
    this.selectedProjectId,
    required this.onEdit,
    required this.onDelete,
    this.depth = 0,
  });

  @override
  State<ProjectTree> createState() => _ProjectTreeState();
}

class _ProjectTreeState extends State<ProjectTree> {
  // Store expanded state in a static map to persist across widget rebuilds
  // but reset on app restart.
  static final Map<String, bool> _expandedStates = {};

  bool _isExpanded(String id) => _expandedStates[id] ?? true;

  void _toggleExpanded(String id) {
    setState(() {
      _expandedStates[id] = !(_expandedStates[id] ?? true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredProjects = widget.projects.where((p) => p.parentId == widget.parentId).toList();
    
    // Sort by sortOrder
    filteredProjects.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (filteredProjects.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: filteredProjects.map((p) {
        final hasChildren = widget.projects.any((child) => child.parentId == p.id);
        final expanded = _isExpanded(p.id);

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.only(left: widget.depth * 12.0),
              child: Stack(
                children: [
                  // Vertical guide line for depth
                  if (widget.depth > 0)
                    Positioned(
                      left: -6,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1.5,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                  
                  DragTarget<String>(
                    onAcceptWithDetails: (details) {
                      context.read<SecretBloc>().add(MoveSecretToProject(
                        secretId: details.data,
                        fromProjectId: '', // Handled by Bloc
                        toProjectId: p.id,
                      ));
                      AppToast.show(
                        context,
                        message: 'Secret moved to ${p.name}',
                        type: ToastType.success,
                      );
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isHovered = candidateData.isNotEmpty;
                      return ProjectTile(
                        key: ValueKey(p.id),
                        project: p,
                        isSelected: p.id == widget.selectedProjectId,
                        isDragHovered: isHovered,
                        hasChildren: hasChildren,
                        isExpanded: expanded,
                        onToggleExpand: () => _toggleExpanded(p.id),
                        onTap: () {
                          context.read<ProjectBloc>().add(SelectProject(p.id));
                          if (hasChildren) {
                            _toggleExpanded(p.id);
                          }
                        },
                        onEdit: () => widget.onEdit(p),
                        onDelete: () => widget.onDelete(p),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Recursive children
            if (hasChildren && expanded)
              ProjectTree(
                projects: widget.projects,
                parentId: p.id,
                selectedProjectId: widget.selectedProjectId,
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
                depth: widget.depth + 1,
              ),
          ],
        );
      }).toList(),
    );
  }
}
