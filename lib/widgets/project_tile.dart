import 'package:flutter/material.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';

class ProjectTile extends StatefulWidget {
  final Project project;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool isDragHovered;

  const ProjectTile({
    super.key,
    required this.project,
    required this.isSelected,
    required this.onTap,
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
            if (widget.onDelete != null) {
              _showContextMenu(context, details.globalPosition);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: widget.isSelected || widget.isDragHovered 
                    ? projectColor.withValues(alpha: isDark ? 0.2 : 0.1) 
                    : (_isHovered ? colors.accent.withValues(alpha: 0.08) : Colors.transparent),
                border: Border.all(
                  color: widget.isDragHovered 
                      ? colors.accent 
                      : (widget.isSelected ? projectColor.withValues(alpha: 0.4) : (_isHovered ? colors.border : Colors.transparent)),
                  width: widget.isDragHovered ? 2 : 1,
                ),
                boxShadow: [
                  if (widget.isSelected)
                    BoxShadow(
                      color: projectColor.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(12),
                    hoverColor: projectColor.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: projectColor,
                              boxShadow: widget.isSelected
                                  ? [
                                      BoxShadow(
                                        color: projectColor.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.project.name,
                                  style: TextStyle(
                                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                                    fontSize: 14,
                                    color: widget.isSelected ? projectColor : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (widget.project.description != null && widget.project.description!.isNotEmpty)
                                  Text(
                                    widget.project.description!,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                              ],
                            ),
                          ),
                          if (widget.isSelected) Icon(Icons.chevron_right_rounded, color: projectColor.withValues(alpha: 0.7), size: 18),
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
      items: [
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
      if (value == 'delete' && widget.onDelete != null) {
        widget.onDelete!();
      }
    });
  }
}
