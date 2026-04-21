import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import '../models/project.dart';
import '../models/secret.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/project/project_bloc.dart';
import '../blocs/project/project_event.dart';
import '../blocs/project/project_state.dart';
import '../blocs/secret/secret_bloc.dart';
import '../blocs/secret/secret_event.dart';
import '../blocs/secret/secret_state.dart';
import '../theme/app_theme.dart';
import '../widgets/project_tile.dart';
import '../widgets/pinned_secrets_section.dart';
import '../widgets/secret_card.dart';
import '../widgets/add_project_dialog.dart';
import '../widgets/add_secret_dialog.dart';
import '../widgets/move_secret_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/custom_confirm_dialog.dart';
import 'settings_screen.dart';
import 'lock_screen.dart';
import '../widgets/spotlight_search.dart';
import '../services/clipboard_service.dart';
import '../widgets/clipboard_countdown_overlay.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _rootFocus = FocusNode();
  bool _showSpotlight = false;
  late ClipboardService _clipboardService;
  int? _remainingSeconds;

  @override
  void initState() {
    super.initState();
    context.read<ProjectBloc>().add(LoadProjects());
    
    _clipboardService = RepositoryProvider.of<ClipboardService>(context);
    _clipboardService.onCountdown = (remaining) {
      if (mounted) {
        setState(() => _remainingSeconds = remaining > 0 ? remaining : null);
      }
    };
    
    _clipboardService.onCleared = () {
      if (mounted) {
        setState(() => _remainingSeconds = null);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.onPrimary, size: 16),
                const SizedBox(width: 12),
                const Text('Sensitive data securely wiped'),
              ],
            ),
            backgroundColor: Colors.black87,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            width: 320,
          ),
        );
      }
    };
  }

  @override
  void dispose() {
    _clipboardService.onCountdown = null;
    _clipboardService.onCleared = null;
    _searchController.dispose();
    _rootFocus.dispose();
    super.dispose();
  }

  void _closeSpotlight() {
    setState(() => _showSpotlight = false);
    _rootFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          setState(() => _showSpotlight = true);
        },
      },
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthLocked) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const LockScreen(),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
              ),
            );
          }
        },
        child: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: colors.background,
                body: Row(
                  children: [
                    _Sidebar(
                      colors: colors,
                      isDark: isDark,
                      searchController: _searchController,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TopBar(
                            colors: colors,
                            isDark: isDark,
                            searchController: _searchController,
                          ),
                          Expanded(
                            child: MediaQuery.removePadding(
                              context: context,
                              removeTop: true,
                              child: _SecretList(colors: colors),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                floatingActionButton: _SmartFAB(colors: colors),
              ),
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: BlocBuilder<SettingsBloc, SettingsState>(
                    builder: (context, settingsState) {
                      final total = (settingsState is SettingsLoaded)
                          ? settingsState.clipboardClearSeconds
                          : 30;
                      
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.5),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCirc,
                            )),
                            child: child,
                          ),
                        ),
                        child: _remainingSeconds != null
                            ? ClipboardCountdownOverlay(
                                seconds: _remainingSeconds!,
                                totalSeconds: total > 0 ? total : 30,
                              )
                            : const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
              ),
              if (_showSpotlight)
                SpotlightSearch(
                  onClose: _closeSpotlight,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Sidebar
// ──────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final AppColors colors;
  final bool isDark;
  final TextEditingController searchController;

  const _Sidebar({
    required this.colors,
    required this.isDark,
    required this.searchController,
  });

  void _confirmDeleteProject(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (ctx) => CustomConfirmDialog(
        title: 'Delete Project?',
        message: 'This will permanently delete "${project.name}" and all its secrets. This action cannot be undone.',
        confirmLabel: 'Delete Permanently',
        confirmColor: Colors.red.shade600,
        icon: Icons.delete_sweep_rounded,
        onConfirm: () {
          context.read<ProjectBloc>().add(DeleteProject(project.id));
          AppToast.show(
            context,
            message: 'Project "${project.name}" deleted',
            type: ToastType.info,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: isDark ? colors.surface : Colors.white,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App logo / header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [colors.accent, const Color(0xFF00D8FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Secret Vault',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      'v2.0',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Projects heading + New button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 14, 8),
            child: Row(
              children: [
                Text(
                  'PROJECTS/FOLDERS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
                ),
                const Spacer(),
                _SidebarAction(
                  icon: Icons.add_rounded,
                  tooltip: 'New Project',
                  onTap: () async {
                    final result = await showDialog(
                      context: context,
                      builder: (_) => const AddProjectDialog(),
                    );
                    if (result != null && context.mounted) {
                      context.read<ProjectBloc>().add(AddProject(
                            result['name'],
                            result['description'],
                            result['color'],
                          ));
                    }
                  },
                  colors: colors,
                ),
              ],
            ),
          ),

          Expanded(
            child: BlocConsumer<ProjectBloc, ProjectState>(
              listener: (context, state) {
                if (state is ProjectLoaded && state.selectedProjectId != null) {
                  // Only dispatch LoadSecrets if project changed OR we have a specific expansion target
                  final secretBloc = context.read<SecretBloc>();
                  final bool projectChanged = (secretBloc.state is! SecretLoaded) || 
                      (secretBloc.state as SecretLoaded).secrets.isEmpty || 
                      (state.selectedProjectId != (secretBloc.state as SecretLoaded).secrets.firstOrNull?.projectId);

                  if (projectChanged || state.targetSecretId != null) {
                    secretBloc.add(LoadSecrets(
                      state.selectedProjectId!,
                      initialExpandedId: state.targetSecretId,
                    ));
                    
                    if (state.targetSecretId != null) {
                      context.read<ProjectBloc>().add(ClearTargetSecret());
                    }
                  }
                } else if (state is ProjectLoaded && state.selectedProjectId == null) {
                  context.read<SecretBloc>().add(ClearSecrets());
                }
              },
              builder: (context, state) {
                if (state is ProjectLoading) {
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2));
                }
                if (state is ProjectLoaded) {
                  if (state.projects.isEmpty) {
                    return _EmptySidebarState(colors: colors);
                  }
                  return ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: state.projects.length,
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      context.read<ProjectBloc>().add(ReorderProjects(oldIndex, newIndex));
                    },
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, _) {
                          final double animValue = Curves.easeInOut.transform(animation.value);
                          final double elevation = lerpDouble(0, 8, animValue)!;
                          return Material(
                            elevation: elevation,
                            color: Colors.transparent,
                            child: child,
                          );
                        },
                      );
                    },
                    itemBuilder: (ctx, i) {
                      final p = state.projects[i];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(p.id),
                        index: i,
                        child: DragTarget<String>(
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
                              isSelected: p.id == state.selectedProjectId,
                              isDragHovered: isHovered,
                              onTap: () {
                                context
                                    .read<ProjectBloc>()
                                    .add(SelectProject(p.id));
                              },
                              onDelete: () => _confirmDeleteProject(context, p),
                            );
                          },
                        ),
                      );
                    },
                  );
                }
                return const SizedBox();
              },
            ),
          ),

          // Bottom actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Divider(color: colors.border),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _SidebarBottomBtn(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ),
                      colors: colors,
                    ),
                    const SizedBox(width: 8),
                    _SidebarBottomBtn(
                      icon: Icons.lock_outline_rounded,
                      label: 'Lock',
                      onTap: () =>
                          context.read<AuthBloc>().add(LockVault()),
                      colors: colors,
                      isDestructive: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarAction extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final AppColors colors;

  const _SidebarAction(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      required this.colors});

  @override
  State<_SidebarAction> createState() => _SidebarActionState();
}

class _SidebarActionState extends State<_SidebarAction> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hov = true),
        onExit: (_) => setState(() => _hov = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _hov
                  ? widget.colors.accent.withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: Icon(widget.icon,
                size: 18,
                color: _hov ? widget.colors.accent : null),
          ),
        ),
      ),
    );
  }
}

class _SidebarBottomBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppColors colors;
  final bool isDestructive;

  const _SidebarBottomBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade400 : null;
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label,
            style:
                TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          side: BorderSide(
              color: isDestructive
                  ? Colors.red.withValues(alpha: 0.3)
                  : colors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class _EmptySidebarState extends StatelessWidget {
  final AppColors colors;
  const _EmptySidebarState({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded,
              size: 44, color: colors.accent.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'No projects yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to create one',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Top bar
// ──────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final AppColors colors;
  final bool isDark;
  final TextEditingController searchController;

  const _TopBar(
      {required this.colors,
      required this.isDark,
      required this.searchController});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectBloc, ProjectState>(
      builder: (context, projectState) {
        final selectedId = projectState is ProjectLoaded
            ? projectState.selectedProjectId
            : null;
        final project = (projectState is ProjectLoaded && selectedId != null)
            ? projectState.projects
                .where((p) => p.id == selectedId)
                .firstOrNull
            : null;

        return Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? colors.surface : Colors.white,
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              if (project != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(project.color),
                    boxShadow: [
                      BoxShadow(
                        color: Color(project.color).withValues(alpha: 0.5),
                        blurRadius: 8,
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  project.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18),
                ),
                if (project.description != null &&
                    project.description!.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Text(
                    project.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ] else
                Text(
                  'Select a project',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
                ),
              const Spacer(),
              // Search bar
              if (selectedId != null)
                Row(
                  children: [
                    SizedBox(
                      width: 240,
                      height: 36,
                      child: TextField(
                        controller: searchController,
                        onChanged: (val) => context.read<SecretBloc>().add(SearchSecrets(val)),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search secrets...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                          ),
                          prefixIcon: Icon(Icons.search_rounded, size: 16, color: colors.accent.withValues(alpha: 0.6)),
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.accent, width: 1.5),
                          ),
                          fillColor: isDark ? colors.card : colors.background,
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _FilterDropdown(colors: colors),
                    // const SizedBox(width: 12),
                    // IconButton(
                    //   icon: Icon(Icons.history_rounded, size: 20, color: colors.accent.withValues(alpha: 0.6)),
                    //   tooltip: 'View Audit Log',
                    //   onPressed: () {
                    //     Navigator.push(
                    //       context,
                    //       MaterialPageRoute(
                    //         builder: (_) => AuditLogScreen(
                    //           projectId: selectedId,
                    //           projectName: project?.name,
                    //         ),
                    //       ),
                    //     );
                    //   },
                    // ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final AppColors colors;
  const _FilterDropdown({required this.colors});

  String _labelForType(SecretType type) {
    switch (type) {
      case SecretType.login: return 'Logins';
      case SecretType.apiKey: return 'API Keys';
      case SecretType.database: return 'Databases';
      case SecretType.sshKey: return 'SSH Keys';
      case SecretType.creditCard: return 'Cards';
      case SecretType.wifi: return 'WiFi';
      case SecretType.note: return 'Notes';
      case SecretType.custom: return 'Custom';
    }
  }

  IconData _iconForType(SecretType type) {
    switch (type) {
      case SecretType.login: return Icons.login_rounded;
      case SecretType.apiKey: return Icons.vpn_key_rounded;
      case SecretType.database: return Icons.storage_rounded;
      case SecretType.sshKey: return Icons.terminal_rounded;
      case SecretType.creditCard: return Icons.credit_card_rounded;
      case SecretType.wifi: return Icons.wifi_rounded;
      case SecretType.note: return Icons.description_rounded;
      case SecretType.custom: return Icons.extension_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SecretBloc, SecretState>(
      builder: (context, state) {
        if (state is! SecretLoaded) return const SizedBox();

        final hasFilter = state.filterType != null;

        return Row(
          children: [
            if (hasFilter)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () => context.read<SecretBloc>().add(const FilterByType(null)),
                  icon: const Icon(Icons.filter_list_off_rounded, size: 18),
                  tooltip: 'Clear filter',
                  style: IconButton.styleFrom(
                    foregroundColor: colors.accent,
                    backgroundColor: colors.accent.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            Container(
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
                color: hasFilter ? colors.accent.withValues(alpha: 0.05) : Colors.transparent,
              ),
              child: PopupMenuButton<SecretType?>(
                tooltip: 'Filter by type',
                onSelected: (type) => context.read<SecretBloc>().add(FilterByType(type)),
                offset: const Offset(0, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        hasFilter ? _iconForType(state.filterType!) : Icons.filter_list_rounded,
                        size: 16,
                        color: hasFilter ? colors.accent : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasFilter ? _labelForType(state.filterType!) : 'Filter',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: hasFilter ? FontWeight.w600 : FontWeight.w500,
                          color: hasFilter ? colors.accent : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: hasFilter ? colors.accent : Colors.grey),
                    ],
                  ),
                ),
                itemBuilder: (context) {
                  return [
                    PopupMenuItem<SecretType?>(
                      value: null,
                      child: Row(
                        children: [
                          const Icon(Icons.grid_view_rounded, size: 18),
                          const SizedBox(width: 12),
                          const Text('All Types', style: TextStyle(fontSize: 13)),
                          const Spacer(),
                          Text(
                            state.typeCounts.values.fold(0, (sum, count) => sum + count).toString(),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    ...SecretType.values.map((type) {
                      final count = state.typeCounts[type] ?? 0;
                      return PopupMenuItem<SecretType?>(
                        value: type,
                        enabled: count > 0 || state.filterType == type,
                        child: Row(
                          children: [
                            Icon(_iconForType(type), size: 18, color: state.filterType == type ? colors.accent : null),
                            const SizedBox(width: 12),
                            Text(
                              _labelForType(type),
                              style: TextStyle(
                                fontSize: 13,
                                color: state.filterType == type ? colors.accent : null,
                                fontWeight: state.filterType == type ? FontWeight.w600 : null,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: state.filterType == type 
                                  ? colors.accent.withValues(alpha: 0.1) 
                                  : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                count.toString(),
                                style: TextStyle(
                                  fontSize: 10, 
                                  color: state.filterType == type ? colors.accent : Colors.grey,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ];
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────
// Secret list
// ──────────────────────────────────────────────────────────
class _SecretList extends StatefulWidget {
  final AppColors colors;
  const _SecretList({required this.colors});

  @override
  State<_SecretList> createState() => _SecretListState();
}

class _SecretListState extends State<_SecretList> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (index < 0) return;
    // Base jump so the item is definitely built by the ListView.builder
    final offset = index * 90.0; 
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _confirmDelete(BuildContext context, String secretId) {
    showDialog(
      context: context,
      builder: (ctx) => CustomConfirmDialog(
        title: 'Delete Secret?',
        message: 'This will permanently remove this secret from your vault.',
        confirmLabel: 'Delete',
        confirmColor: Colors.red.shade600,
        icon: Icons.delete_outline_rounded,
        onConfirm: () {
          context.read<SecretBloc>().add(DeleteSecret(secretId));
        },
      ),
    );
  }

  void _onMoveSecret(BuildContext context, Secret secret) async {
    final projectState = context.read<ProjectBloc>().state;
    if (projectState is! ProjectLoaded) return;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => MoveSecretDialog(
        projects: projectState.projects,
        currentProjectId: secret.projectId,
        secretTitle: secret.title,
      ),
    );

    if (result != null && context.mounted) {
      context.read<SecretBloc>().add(MoveSecretToProject(
        secretId: secret.id,
        fromProjectId: secret.projectId,
        toProjectId: result,
      ));
      
      final targetProject = projectState.projects.firstWhere((p) => p.id == result);
      AppToast.show(
        context, 
        message: 'Secret moved to ${targetProject.name}',
        type: ToastType.success,
      );
    }
  }

  void _onEditSecret(BuildContext context, Secret secret) async {
    final result = await showDialog(
      context: context,
      builder: (_) => AddSecretDialog(secretToEdit: secret),
    );
    if (result != null && context.mounted) {
      final updated = secret.copyWith(
        title: result['title'],
        fields: result['fields'],
        note: result['note'],
        tags: result['tags'],
      );
      context.read<SecretBloc>().add(UpdateSecret(updated));
      AppToast.show(
        context,
        message: 'Secret updated successfully',
        type: ToastType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SecretBloc, SecretState>(
      listener: (context, state) {
        if (state is SecretLoaded && state.expandedId != null) {
          final index = state.secrets.indexWhere((s) => s.id == state.expandedId);
          if (index != -1) {
            _scrollToIndex(index);
          }
        }
      },
      child: BlocBuilder<SecretBloc, SecretState>(
        builder: (context, state) {
          if (state is SecretLoading) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }

          // No project selected
          final projectState = context.read<ProjectBloc>().state;
          final selectedId = projectState is ProjectLoaded
              ? projectState.selectedProjectId
              : null;
          if (selectedId == null) {
            return _EmptyContent(
              icon: Icons.lock_open_rounded,
              title: 'Select a project',
              subtitle: 'Choose a project from the sidebar to view its secrets',
              colors: widget.colors,
            );
          }

          if (state is SecretLoaded && state.secrets.isEmpty) {
            return _EmptyContent(
              icon: Icons.add_circle_outline_rounded,
              title: state.searchQuery.isEmpty
                  ? 'No secrets yet'
                  : 'No results for "${state.searchQuery}"',
              subtitle: state.searchQuery.isEmpty
                  ? 'Tap the + button to add your first secret'
                  : 'Try a different search term',
              colors: widget.colors,
            );
          }

          if (state is SecretLoaded) {
            final unpinned = state.unpinned;
            
            return ReorderableListView.builder(
              scrollController: _scrollController,
              padding: const EdgeInsets.only(top: 24, bottom: 100),
              header: state.pinned.isNotEmpty 
                ? PinnedSecretsSection(
                  onEdit: (s) => _onEditSecret(context, s),
                  onDelete: (id) => _confirmDelete(context, id),
                  onMove: (s) => _onMoveSecret(context, s),
                )
                : null,
              itemCount: unpinned.length,
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                context.read<SecretBloc>().add(ReorderSecrets(selectedId, oldIndex, newIndex));
              },
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    final double animValue = Curves.easeInOut.transform(animation.value);
                    final double elevation = lerpDouble(0, 8, animValue)!;
                    return Material(
                      elevation: elevation,
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      shadowColor: Colors.black.withValues(alpha: 0.2),
                      child: child,
                    );
                  },
                );
              },
              itemBuilder: (context, i) {
                final secret = unpinned[i];
                final isLast = i == unpinned.length - 1;
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(secret.id),
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SecretCard(
                      key: ValueKey(secret.id),
                      secret: secret,
                      revealedFieldIds: state.revealedIds,
                      expandedId: state.expandedId,
                      expansionNonce: state.expansionNonce,
                      onEdit: () => _onEditSecret(context, secret),
                      onDelete: () => _confirmDelete(context, secret.id),
                      onMove: () => _onMoveSecret(context, secret),
                    ),
                  ),
                );
              },
            );
          }

          return const SizedBox();
        },
      ),
    );
  }
}

class _EmptyContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final AppColors colors;

  const _EmptyContent({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: colors.accent.withValues(alpha: 0.08),
              border: Border.all(
                  color: colors.accent.withValues(alpha: 0.15)),
            ),
            child: Icon(icon,
                size: 36, color: colors.accent.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// FAB
// ──────────────────────────────────────────────────────────
class _SmartFAB extends StatelessWidget {
  final AppColors colors;
  const _SmartFAB({required this.colors});

  @override
  Widget build(BuildContext context) {
    final projectId = context.select((ProjectBloc b) {
      final s = b.state;
      return s is ProjectLoaded ? s.selectedProjectId : null;
    });

    if (projectId == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [colors.accent, const Color(0xFF9C27B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.accentGlow,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        elevation: 0,
        backgroundColor: Colors.transparent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Secret',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
        onPressed: () async {
          final result = await showDialog(
            context: context,
            builder: (_) => const AddSecretDialog(),
          );
          if (result != null && context.mounted) {
            context.read<SecretBloc>().add(AddSecret(
                  projectId,
                  result['title'],
                  result['type'],
                  result['fields'],
                  result['note'],
                  result['tags'],
                ));
            AppToast.show(
              context,
              message: 'Secret saved securely',
              type: ToastType.success,
            );
          }
        },
      ),
    );
  }
}
