import 'package:flutter/material.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';

class ProjectTile extends StatefulWidget {
  final Project project;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isDragHovered;

  const ProjectTile({
    super.key,
    required this.project,
    required this.isSelected,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.isDragHovered = false,
  });

  @override
  State<ProjectTile> createState() => _ProjectTileState();
}

class _ProjectTileState extends State<ProjectTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final projectColor = Color(widget.project.color);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onSecondaryTapDown: (details) {
            if (widget.onDelete != null || widget.onEdit != null) {
              _showContextMenu(context, details.globalPosition);
            }
          },
          onLongPressStart: (details) {
            if (widget.onDelete != null || widget.onEdit != null) {
              _showContextMenu(context, details.globalPosition);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutQuart,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: widget.isSelected 
                    ? projectColor.withValues(alpha: isDark ? 0.2 : 0.1) 
                    : (_isHovered ? colors.accent.withValues(alpha: 0.05) : Colors.transparent),
                border: Border.all(
                  color: widget.isSelected 
                      ? projectColor.withValues(alpha: 0.4) 
                      : (_isHovered ? colors.border.withValues(alpha: 0.4) : Colors.transparent),
                  width: 1.5,
                ),
                boxShadow: [
                  if (widget.isSelected)
                    BoxShadow(
                      color: projectColor.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(18),
                    hoverColor: Colors.transparent,
                    splashColor: projectColor.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: widget.isSelected ? 14 : 10,
                            height: widget.isSelected ? 14 : 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: projectColor,
                              boxShadow: [
                                BoxShadow(
                                  color: projectColor.withValues(alpha: 0.8),
                                  blurRadius: widget.isSelected ? 16 : 0,
                                  spreadRadius: widget.isSelected ? 2 : 0,
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.project.name,
                                  style: TextStyle(
                                    fontWeight: widget.isSelected ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 15,
                                    letterSpacing: -0.3,
                                    color: widget.isSelected 
                                        ? (isDark ? Colors.white : projectColor)
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (widget.project.description != null && widget.project.description!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      widget.project.description!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.isSelected) 
                            Icon(Icons.arrow_forward_ios_rounded, 
                                color: (isDark ? Colors.white : projectColor).withValues(alpha: 0.4), 
                                size: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final colors = Theme.of(context).extension<AppColors>()!;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colors.card,
      elevation: 8,
      items: <PopupMenuEntry<String>>[
        if (widget.onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 12),
                Text('Edit Project'),
              ],
            ),
          ),
        if (widget.onEdit != null)
          const PopupMenuDivider(),
        if (widget.onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                SizedBox(width: 12),
                Text('Delete Project', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value == 'edit' && widget.onEdit != null) {
        widget.onEdit!();
      } else if (value == 'delete' && widget.onDelete != null) {
        widget.onDelete!();
      }
    });
  }
}
