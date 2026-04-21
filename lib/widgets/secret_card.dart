import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/secret.dart';
import '../services/encryption_service.dart';
import '../blocs/secret/secret_bloc.dart';
import '../blocs/secret/secret_event.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';

class SecretCard extends StatefulWidget {
  final Secret secret;
  final Set<String> revealedFieldIds;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMove;
  final String? expandedId;
  final int expansionNonce;
  final bool isDragging;

  const SecretCard({
    super.key,
    required this.secret,
    required this.revealedFieldIds,
    required this.onEdit,
    required this.onDelete,
    this.onMove,
    this.expandedId,
    this.expansionNonce = 0,
    this.isDragging = false,
  });

  @override
  State<SecretCard> createState() => _SecretCardState();
}

class _SecretCardState extends State<SecretCard> {
  bool _isHovered = false;
  bool _isExpanded = false;
  final _expansionController = ExpansionTileController();

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.expandedId == widget.secret.id;
    if (_isExpanded) {
      _scrollToMe();
      _forceExpand();
    }
  }

  @override
  void didUpdateWidget(SecretCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isTarget = widget.expandedId == widget.secret.id;
    
    if (isTarget && (widget.expandedId != oldWidget.expandedId || widget.expansionNonce != oldWidget.expansionNonce)) {
      setState(() => _isExpanded = true);
      _scrollToMe();
      _forceExpand();
    }
  }

  void _forceExpand() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _expansionController.expand();
      }
    });
  }

  void _scrollToMe() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  IconData _iconForType(SecretType type) {
    switch (type) {
      case SecretType.login:
        return Icons.login_rounded;
      case SecretType.apiKey:
        return Icons.vpn_key_rounded;
      case SecretType.database:
        return Icons.storage_rounded;
      case SecretType.sshKey:
        return Icons.terminal_rounded;
      case SecretType.creditCard:
        return Icons.credit_card_rounded;
      case SecretType.wifi:
        return Icons.wifi_rounded;
      case SecretType.note:
        return Icons.notes_rounded;
      case SecretType.custom:
        return Icons.tune_rounded;
    }
  }

  Color _colorForType(SecretType type) {
    switch (type) {
      case SecretType.login:
        return const Color(0xFF4CAF50);
      case SecretType.apiKey:
        return const Color(0xFFFF9800);
      case SecretType.database:
        return const Color(0xFF2196F3);
      case SecretType.sshKey:
        return const Color(0xFF9C27B0);
      case SecretType.creditCard:
        return const Color(0xFFE91E63);
      case SecretType.wifi:
        return const Color(0xFF00BCD4);
      case SecretType.note:
        return const Color(0xFF8BC34A);
      case SecretType.custom:
        return const Color(0xFF607D8B);
    }
  }

  String _labelForType(SecretType type) {
    switch (type) {
      case SecretType.login:
        return 'Login';
      case SecretType.apiKey:
        return 'API Key';
      case SecretType.database:
        return 'Database';
      case SecretType.sshKey:
        return 'SSH Key';
      case SecretType.creditCard:
        return 'Credit Card';
      case SecretType.wifi:
        return 'WiFi';
      case SecretType.note:
        return 'Note';
      case SecretType.custom:
        return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    final enc = context.read<EncryptionService>();
    final colors = Theme.of(context).extension<AppColors>()!;
    final typeColor = _colorForType(widget.secret.type);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? colors.card : Colors.white,
          border: Border.all(
            color: _isHovered ? colors.accent.withValues(alpha: 0.3) : colors.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered ? colors.accent.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.02),
              blurRadius: _isHovered ? 24 : 8,
              offset: _isHovered ? const Offset(0, 10) : const Offset(0, 4),
            ),
            if (_isHovered)
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.04),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Sidebar Type Accent
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 16,
                child: Draggable<String>(
                  data: widget.secret.id,
                  feedback: Material(
                    elevation: 12,
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width - 48,
                      child: SecretCard(
                        secret: widget.secret,
                        revealedFieldIds: const {},
                        onEdit: () {},
                        onDelete: () {},
                        isDragging: true,
                      ),
                    ),
                  ),
                  childWhenDragging: Container(color: typeColor.withValues(alpha: 0.1)),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Tooltip(
                      message: 'Drag handle to move to other project',
                      preferBelow: false,
                      child: Container(
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          border: Border(right: BorderSide(color: typeColor.withValues(alpha: 0.2))),
                        ),
                        child: Center(
                          child: Icon(Icons.drag_indicator_rounded, 
                            size: 14, 
                            color: typeColor.withValues(alpha: _isHovered ? 0.8 : 0.4)
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: typeColor.withValues(alpha: 0.05),
                  highlightColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  key: ValueKey(widget.secret.id),
                  controller: _expansionController,
                  initiallyExpanded: widget.expandedId == widget.secret.id,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onExpansionChanged: (v) {
                    setState(() => _isExpanded = v);
                    if (v) {
                      context.read<SecretBloc>().add(LogSecretAccess(widget.secret.id));
                    }
                  },
                  iconColor: colors.accent,
                  collapsedIconColor: colors.accent.withValues(alpha: 0.4),
                  tilePadding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
                  childrenPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          typeColor.withValues(alpha: 0.2),
                          typeColor.withValues(alpha: 0.05),
                        ],
                      ),
                      border: Border.all(color: typeColor.withValues(alpha: 0.15)),
                    ),
                    child: Icon(_iconForType(widget.secret.type), color: typeColor, size: 22),
                  ),
                  title: Text(
                    widget.secret.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: typeColor.withValues(alpha: 0.1),
                          ),
                          child: Text(
                            _labelForType(widget.secret.type),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: typeColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (widget.secret.fields.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${widget.secret.fields.length} item${widget.secret.fields.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _isHovered || widget.secret.isFavourite ? 1.0 : 0.0,
                        child: IconButton(
                          icon: Icon(
                            widget.secret.isFavourite ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 20,
                            color: widget.secret.isFavourite ? Colors.amber : colors.accent.withValues(alpha: 0.4),
                          ),
                          onPressed: () => context.read<SecretBloc>().add(ToggleFavourite(widget.secret.id)),
                          tooltip: widget.secret.isFavourite ? 'Unpin' : 'Pin to top',
                          splashRadius: 20,
                        ),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _isHovered ? 1.0 : 0.0,
                        child: PopupMenuButton<String>(
                          icon: Icon(Icons.more_horiz_rounded, size: 20, color: colors.accent.withValues(alpha: 0.6)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          offset: const Offset(0, 40),
                          elevation: 8,
                          onSelected: (v) {
                            if (v == 'edit') widget.onEdit();
                            if (v == 'delete') widget.onDelete();
                            if (v == 'move' && widget.onMove != null) widget.onMove!();
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_rounded, size: 18, color: colors.accent),
                                const SizedBox(width: 12),
                                const Text('Edit Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              ]),
                            ),
                            if (widget.onMove != null)
                              PopupMenuItem(
                                value: 'move',
                                child: Row(children: [
                                  Icon(Icons.drive_file_move_rounded, size: 18, color: colors.accent),
                                  const SizedBox(width: 12),
                                  const Text('Move to Project', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ]),
                              ),
                            const PopupMenuDivider(height: 1),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_forever_rounded, size: 18, color: Colors.redAccent.shade200),
                                const SizedBox(width: 12),
                                Text('Delete Secret', style: TextStyle(color: Colors.redAccent.shade200, fontSize: 13, fontWeight: FontWeight.w500)),
                              ]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                         turns: _isExpanded ? 0.5 : 0,
                         duration: const Duration(milliseconds: 200),
                         child: const Icon(Icons.expand_more_rounded, size: 20),
                      ),
                    ],
                  ),
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      height: 1,
                      color: colors.border.withValues(alpha: 0.5),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...widget.secret.fields.map((field) {
                            final revealed = !field.isSecret || widget.revealedFieldIds.contains(field.id);
                            String decrypted = '';
                            try {
                              decrypted = enc.decryptValue(field.encryptedValue);
                            decrypted = decrypted.isEmpty ? 'Empty' : decrypted;
                            } catch (_) {
                              decrypted = 'Decryption error';
                            }

                            return _FieldRow(
                              field: field,
                              isRevealed: revealed,
                              decryptedValue: decrypted,
                              onToggle: () => context.read<SecretBloc>().add(ToggleRevealField(widget.secret.id, field.id)),
                              onCopy: () {
                                context.read<SecretBloc>().add(CopyField(widget.secret.id, field.id));
                                AppToast.show(
                                  context,
                                  message: '${field.label} copied',
                                  type: ToastType.success,
                                );
                              },
                            );
                          }),
                          if (widget.secret.note != null && widget.secret.note!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colors.border.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colors.border.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Icon(Icons.notes_rounded, size: 14, color: colors.accent.withValues(alpha: 0.6)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Note',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: colors.accent.withValues(alpha: 0.7),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.secret.note!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (widget.secret.tags != null && widget.secret.tags!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: widget.secret.tags!
                                  .map((tag) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          color: Colors.black.withValues(alpha: 0.03),
                                          border: Border.all(color: colors.border),
                                        ),
                                        child: Text(
                                          '#$tag',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ));
  }
}

class _FieldRow extends StatelessWidget {
  final SecretField field;
  final bool isRevealed;
  final String decryptedValue;
  final VoidCallback onToggle;
  final VoidCallback onCopy;

  const _FieldRow({
    required this.field,
    required this.isRevealed,
    required this.decryptedValue,
    required this.onToggle,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              field.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : colors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: SelectableText(
                      isRevealed ? decryptedValue : '•' * 24,
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 14,
                        fontWeight: isRevealed ? FontWeight.w500 : FontWeight.w900,
                        color: isRevealed 
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9) 
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                        letterSpacing: isRevealed ? 0 : 2,
                        height: 1.4,
                      ),
                      maxLines: field.isMultiline && isRevealed ? null : 1,
                    ),
                  ),
                ),
                if (field.isSecret)
                  _ActionIconButton(
                    icon: isRevealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    onTap: onToggle,
                    tooltip: isRevealed ? 'Hide' : 'Reveal',
                    colors: colors,
                    active: isRevealed,
                  ),
                _ActionIconButton(
                  icon: Icons.copy_all_rounded,
                  onTap: onCopy,
                  tooltip: 'Copy',
                  colors: colors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final AppColors colors;
  final bool active;

  const _ActionIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    required this.colors,
    this.active = false,
  });

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _hovering 
                ? widget.colors.accent.withValues(alpha: 0.1) 
                : (widget.active ? widget.colors.accent.withValues(alpha: 0.05) : Colors.transparent),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: _hovering || widget.active 
                ? widget.colors.accent 
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
