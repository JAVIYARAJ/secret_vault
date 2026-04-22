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
import '../widgets/secret_card.dart';
import '../widgets/add_project_dialog.dart';
import '../widgets/add_secret_dialog.dart';
import '../widgets/move_secret_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/custom_confirm_dialog.dart';
import 'settings_screen.dart';
import 'lock_screen.dart';
import '../widgets/spotlight_search.dart';
import '../widgets/project_tree.dart';
import '../services/clipboard_service.dart';
import 'audit_log_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _rootFocus = FocusNode();
  bool _showSpotlight = false;
  late ClipboardService _clipboardService;
  bool _isSidebarExpanded = true;
  late AnimationController _sidebarController;

  @override
  void initState() {
    super.initState();
    _sidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..value = 1.0;

    context.read<ProjectBloc>().add(LoadProjects());

    _clipboardService = RepositoryProvider.of<ClipboardService>(context);

    _clipboardService.onCleared = () {
      if (mounted) {
        AppToast.show(context, message: 'Sensitive data securely wiped', type: ToastType.info);
      }
    };
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    _searchController.dispose();
    _rootFocus.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarExpanded = !_isSidebarExpanded;
      if (_isSidebarExpanded) {
        _sidebarController.forward();
      } else {
        _sidebarController.reverse();
      }
    });
  }

  void _openSpotlight() => setState(() => _showSpotlight = true);

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
      child: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(
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
          ),
          BlocListener<ProjectBloc, ProjectState>(
            listenWhen: (prev, curr) {
              if (curr is! ProjectLoaded) return false;
              if (prev is! ProjectLoaded) return true;
              // Trigger if project changed OR if a new target secret is requested
              return prev.selectedProjectId != curr.selectedProjectId || 
                     (curr.targetSecretId != null && prev.targetSecretId != curr.targetSecretId);
            },
            listener: (context, state) {
              if (state is ProjectLoaded) {
                context.read<SecretBloc>().add(LoadSecrets(
                      state.selectedProjectId,
                      initialExpandedId: state.targetSecretId,
                    ));
                
                if (state.targetSecretId != null) {
                  // Clear the messenger ID from ProjectBloc so it doesn't re-trigger
                  context.read<ProjectBloc>().add(ClearTargetSecret());
                }
              }
            },
          ),
        ],
        child: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: colors.background,
                body: Stack(
                  children: [
                    // Dynamic background elements
                    _MeshBackground(colors: colors, isDark: isDark),
                    
                    Row(
                      children: [
                        // Floating Sidebar
                        AnimatedBuilder(
                          animation: _sidebarController,
                          builder: (context, child) {
                            final width = 280 * _sidebarController.value;
                            return Container(
                              width: width,
                              margin: EdgeInsets.only(
                                left: 16 * _sidebarController.value,
                                top: 16,
                                bottom: 16,
                              ),
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                color: (isDark ? colors.surface : Colors.white).withValues(alpha: isDark ? 0.6 : 0.8),
                                border: Border.all(color: colors.border.withValues(alpha: 0.3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Opacity(
                                  opacity: _sidebarController.value,
                                  child: _Sidebar(colors: colors, isDark: isDark),
                                ),
                              ),
                            );
                          },
                        ),
                        
                        // Main Content
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _ModernTopBar(
                                  colors: colors,
                                  isDark: isDark,
                                  isSidebarExpanded: _isSidebarExpanded,
                                  onToggleSidebar: _toggleSidebar,
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: _MainView(colors: colors, isDark: isDark),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                floatingActionButton: _ModernFAB(colors: colors),
              ),
              if (_showSpotlight)
                SpotlightSearch(onClose: _closeSpotlight),
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

  const _Sidebar({required this.colors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // App Header
        Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: colors.accent.withValues(alpha: 0.3), blurRadius: 15, spreadRadius: -2)
                    ],
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const SizedBox(
                  width: 180,
                  child: Text(
                    'Secret Vault', 
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Navigation
        const _SidebarCategory(title: 'NAVIGATION'),
        BlocBuilder<ProjectBloc, ProjectState>(
          builder: (context, state) {
            final isAllActive = state is ProjectLoaded && state.selectedProjectId == null;
            return _SidebarItem(
              icon: Icons.grid_view_rounded, 
              label: 'All Secrets', 
              isActive: isAllActive, 
              colors: colors,
              onTap: () {
                 context.read<ProjectBloc>().add(const SelectProject(null));
              },
            );
          },
        ),
        _SidebarItem(icon: Icons.history_rounded, label: 'Audit Logs', onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuditLogScreen()));
        }, colors: colors),

        const SizedBox(height: 20),
        
        // Projects
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: 232, // 280 - (24 * 2)
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('PROJECTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: Colors.grey)),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    onPressed: () async {
                      final result = await showDialog(context: context, builder: (_) => const AddProjectDialog());
                      if (result != null && context.mounted) {
                        context.read<ProjectBloc>().add(AddProject(result['name'], result['description'], result['color'], parentId: result['parentId']));
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        Expanded(
          child: BlocBuilder<ProjectBloc, ProjectState>(
            builder: (context, state) {
              if (state is ProjectLoaded) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ProjectTree(
                    projects: state.projects,
                    selectedProjectId: state.selectedProjectId,
                    onEdit: (p) => _editProject(context, p),
                    onDelete: (p) => _confirmDeleteProject(context, p),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.border.withValues(alpha: 0.3))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: 240, // 280 - (20 * 2)
              child: Row(
                children: [
                  _FooterAction(icon: Icons.settings_rounded, label: 'Settings', onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  }),
                  const Spacer(),
                  _FooterAction(icon: Icons.lock_rounded, label: 'Lock', isDestructive: true, onTap: () {
                    context.read<AuthBloc>().add(LockVault());
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _editProject(BuildContext context, Project project) async {
    final result = await showDialog(context: context, builder: (_) => AddProjectDialog(projectToEdit: project));
    if (result != null && context.mounted) {
      final updated = project.copyWith(name: result['name'], description: result['description'], color: result['color'], parentId: result['parentId']);
      context.read<ProjectBloc>().add(UpdateProject(updated));
    }
  }

  void _confirmDeleteProject(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (ctx) => CustomConfirmDialog(
        title: 'Delete Project?',
        message: 'This will delete "${project.name}" and all its contents.',
        confirmLabel: 'Delete',
        onConfirm: () => context.read<ProjectBloc>().add(DeleteProject(project.id)),
      ),
    );
  }
}

class _SidebarCategory extends StatelessWidget {
  final String title;
  const _SidebarCategory({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.grey)),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  final AppColors colors;

  const _SidebarItem({required this.icon, required this.label, this.isActive = false, this.onTap, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isActive ? colors.accent.withValues(alpha: 0.1) : Colors.transparent,
          ),
          child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isActive ? colors.accent : Colors.grey),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: Text(
                  label, 
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, 
                    color: isActive ? colors.accent : Colors.grey.shade600
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _FooterAction({required this.icon, required this.label, required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade400 : Colors.grey;
    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onTap,
      ),
    );
  }
}

class _ModernTopBar extends StatelessWidget {
  final AppColors colors;
  final bool isDark;
  final bool isSidebarExpanded;
  final VoidCallback onToggleSidebar;

  const _ModernTopBar({
    required this.colors,
    required this.isDark,
    required this.isSidebarExpanded,
    required this.onToggleSidebar,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.3 : 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.border.withValues(alpha: isDark ? 0.2 : 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _TopBarAction(
                icon: isSidebarExpanded ? Icons.chevron_left_rounded : Icons.menu_rounded,
                onTap: onToggleSidebar,
                colors: colors,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SearchBar(colors: colors, isDark: isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  final AppColors colors;
  final bool isDark;
  const _SearchBar({required this.colors, required this.isDark});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          context.findAncestorStateOfType<_HomeScreenState>()?._openSpotlight();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          decoration: BoxDecoration(
            color: widget.isDark 
                ? (_isHovered ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.2))
                : (_isHovered ? Colors.grey.shade100 : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered 
                  ? widget.colors.accent.withValues(alpha: 0.4) 
                  : widget.colors.border.withValues(alpha: widget.isDark ? 0.1 : 0.2),
              width: 1.5,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: widget.colors.accent.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                )
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showShortcut = constraints.maxWidth > 180;
              final showText = constraints.maxWidth > 100;

              return Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search_rounded, 
                      size: 20, 
                      color: _isHovered ? widget.colors.accent : Colors.grey),
                  if (showText) ...[
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Search everything...', 
                        style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ] else 
                    const Spacer(),
                  
                  if (showShortcut) ...[
                    const SizedBox(width: 8),
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.keyboard_command_key_rounded, size: 12, color: Colors.grey),
                          SizedBox(width: 4),
                          Text('K', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ] else 
                    const SizedBox(width: 12),
                ],
              );
            }
          ),
        ),
      ),
    );
  }
}

class _TopBarAction extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final AppColors colors;

  const _TopBarAction({required this.icon, required this.onTap, required this.colors});

  @override
  State<_TopBarAction> createState() => _TopBarActionState();
}

class _TopBarActionState extends State<_TopBarAction> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _isHovered ? widget.colors.accent.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(widget.icon, 
              size: 22, 
              color: _isHovered ? widget.colors.accent : Colors.grey.shade600),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final AppColors colors;
  const _UserAvatar({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [colors.accent, const Color(0xFF00D8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Center(
          child: Text(
            'RJ', 
            style: TextStyle(
              color: colors.accent, 
              fontWeight: FontWeight.w900, 
              fontSize: 12,
              letterSpacing: -0.5,
            )
          ),
        ),
      ),
    );
  }
}

class _MainView extends StatelessWidget {
  final AppColors colors;
  final bool isDark;

  const _MainView({required this.colors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SecretBloc, SecretState>(
      builder: (context, state) {
        if (state is SecretLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is SecretLoaded) {
          final projectState = context.watch<ProjectBloc>().state;
          String title = 'All Secrets';
          String? desc;
          Color accent = colors.accent;

          if (projectState is ProjectLoaded && projectState.selectedProjectId != null) {
            try {
              final p = projectState.projects.firstWhere((p) => p.id == projectState.selectedProjectId);
              title = p.name;
              desc = p.description;
              accent = Color(p.color);
            } catch (_) {}
          }

          if (state.secrets.isEmpty) {
             return _EmptyContent(
               icon: Icons.folder_open_rounded,
               title: 'Empty Folder',
               subtitle: 'No secrets found in this project. Tap + to add one.',
               colors: colors,
             );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title, 
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    if (desc != null && desc.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(desc, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      ),
                  ],
                ),
              ),
              
              // Stats / Quick Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    _StatChip(label: 'Total', value: '${state.secrets.length}', colors: colors),
                    ...state.typeCounts.entries.where((e) => e.value > 0).map((e) => 
                      _StatChip(label: _labelForType(e.key), value: '${e.value}', colors: colors)
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: state.secrets.map((secret) {
                      return SecretCard(
                        key: ValueKey(secret.id),
                        secret: secret,
                        revealedFieldIds: state.revealedIds,
                        onEdit: () => _onEditSecret(context, secret),
                        onDelete: () => _confirmDeleteSecret(context, secret),
                        onMove: () => _onMoveSecret(context, secret),
                        expandedId: state.expandedId,
                        expansionNonce: state.expansionNonce,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        }
        return _EmptyContent(
          icon: Icons.dashboard_customize_rounded,
          title: 'Welcome Back',
          subtitle: 'Select a project from the sidebar to view your secrets.',
          colors: colors,
        );
      },
    );
  }

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

  void _onEditSecret(BuildContext context, Secret secret) async {
    final result = await showDialog(context: context, builder: (_) => AddSecretDialog(secretToEdit: secret));
    if (result != null && context.mounted) {
      final updated = Secret(
        id: secret.id,
        projectId: secret.projectId,
        title: result['title'],
        typeIndex: secret.typeIndex,
        fields: result['fields'],
        note: result['note'],
        tags: (result['tags'] as List<String>).isEmpty ? null : result['tags'],
        createdAt: secret.createdAt,
        updatedAt: DateTime.now(),
        sortOrder: secret.sortOrder,
        isFavourite: secret.isFavourite,
      );
      context.read<SecretBloc>().add(UpdateSecret(updated));
    }
  }

  void _confirmDeleteSecret(BuildContext context, Secret secret) {
    showDialog(
      context: context,
      builder: (ctx) => CustomConfirmDialog(
        title: 'Delete Secret?',
        message: 'Are you sure you want to delete "${secret.title}"?',
        confirmLabel: 'Delete',
        onConfirm: () => context.read<SecretBloc>().add(DeleteSecret(secret.id)),
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
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final AppColors colors;

  const _StatChip({required this.label, required this.value, required this.colors});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: colors.accent)),
        ],
      ),
    );
  }
}

class _ModernFAB extends StatelessWidget {
  final AppColors colors;
  const _ModernFAB({required this.colors});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () async {
        final projectState = context.read<ProjectBloc>().state;
        if (projectState is! ProjectLoaded || projectState.selectedProjectId == null) {
          AppToast.show(context, message: 'Please select a project first', type: ToastType.error);
          return;
        }
        
        final result = await showDialog(context: context, builder: (_) => const AddSecretDialog());
        if (result != null && context.mounted) {
          context.read<SecretBloc>().add(AddSecret(
            projectState.selectedProjectId!,
            result['title'],
            result['type'],
            result['fields'],
            result['note'],
            result['tags'],
          ));
        }
      },
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: const Text('Add Secret', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: colors.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _EmptyContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final AppColors colors;

  const _EmptyContent({required this.icon, required this.title, required this.subtitle, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: colors.accent.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeshBackground extends StatelessWidget {
  final AppColors colors;
  final bool isDark;
  const _MeshBackground({required this.colors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: colors.background),
        Positioned(
          top: -100,
          right: -100,
          child: _GlowCircle(color: colors.accent.withValues(alpha: 0.1), size: 500),
        ),
        Positioned(
          bottom: -200,
          left: -100,
          child: _GlowCircle(color: const Color(0xFF9C27B0).withValues(alpha: 0.08), size: 600),
        ),
        Positioned(
          top: 200,
          left: 100,
          child: _GlowCircle(color: const Color(0xFF00D8FF).withValues(alpha: 0.05), size: 400),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
