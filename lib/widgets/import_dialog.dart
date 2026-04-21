import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/import/import_bloc.dart';
import '../blocs/import/import_event.dart';
import '../blocs/import/import_state.dart';
import '../blocs/project/project_bloc.dart';
import '../blocs/project/project_event.dart';
import '../blocs/project/project_state.dart';
import '../blocs/secret/secret_bloc.dart';
import '../blocs/secret/secret_event.dart';
import '../models/project.dart';
import '../services/import_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import 'add_project_dialog.dart';
import 'import_preview_table.dart';

class ImportDialog extends StatefulWidget {
  const ImportDialog({super.key});

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  bool _groupByFolder = true;
  String? _selectedTargetProjectId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<ImportBloc, ImportState>(
      listener: (context, state) {
        if (state is ImportSuccess) {
          Navigator.pop(context);
          AppToast.show(
            context,
            message: 'Imported ${state.secretsImported} secrets'
              '${state.projectsCreated > 0 ? " across ${state.projectsCreated} new projects" : ""}.',
            type: ToastType.success,
          );
          context.read<ImportBloc>().add(ResetImport());

          // Refresh the application state
          context.read<ProjectBloc>().add(LoadProjects());
          final projectState = context.read<ProjectBloc>().state;
          if (projectState is ProjectLoaded && projectState.selectedProjectId != null) {
            context.read<SecretBloc>().add(LoadSecrets(projectState.selectedProjectId!));
          }
        }
        if (state is ImportFailure) {
          AppToast.show(
            context,
            message: state.message,
            type: ToastType.error,
          );
          context.read<ImportBloc>().add(ResetImport());
        }
      },
      builder: (context, state) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: 760,
                constraints: const BoxConstraints(maxHeight: 700),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? colors.card.withValues(alpha: 0.95) : const Color(0xFFFFFFFF).withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : colors.border, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.08),
                      blurRadius: 40,
                      spreadRadius: 8,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context, state, colors, isDark),
                      Flexible(child: _buildBody(context, state, colors, isDark)),
                      _buildFooter(context, state, colors, isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, ImportState state, AppColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 24, 24),
      decoration: BoxDecoration(
        color: isDark ? colors.surface.withValues(alpha: 0.5) : Colors.white,
        border: Border(bottom: BorderSide(color: colors.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.accent, colors.accent.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: colors.accent.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))
              ],
            ),
            child: const Icon(Icons.cloud_download_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Import Passwords',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                if (state is ImportPreviewing)
                  Text(
                    '${state.items.length} records found · ${state.selectedCount} selected for import',
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  )
                else
                  Text(
                    'Migrate secrets from popular external managers',
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () {
                context.read<ImportBloc>().add(ResetImport());
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, ImportState state, AppColors colors, bool isDark) {
    if (state is ImportIdle || state is ImportPicking) {
      return _buildSourcePicker(context, state, colors, isDark);
    }
    if (state is ImportPreviewing) {
      return _buildPreview(context, state, colors, isDark);
    }
    if (state is ImportCommitting) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Encrypting and saving secrets...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('This may take a moment. Please wait.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildSourcePicker(BuildContext context, ImportState state, AppColors colors, bool isDark) {
    final isLoading = state is ImportPicking;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
               Icon(Icons.dashboard_customize_rounded, size: 20, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
               const SizedBox(width: 8),
               Text('SUPPORTED PROVIDERS',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = (constraints.maxWidth - 32) / 3;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _SourceCard(
                    name: 'LastPass',
                    subtitle: 'Export > Export as CSV',
                    icon: Icons.lock_person_rounded,
                    color: Colors.red.shade600,
                    width: cardWidth,
                    onTap: isLoading
                        ? null
                        : () => context.read<ImportBloc>().add(const PickAndParseImport(ImportSource.lastPass)),
                    colors: colors,
                    isDark: isDark,
                  ),
                  _SourceCard(
                    name: 'Bitwarden',
                    subtitle: 'Export > File Format: .csv',
                    icon: Icons.shield_rounded,
                    color: Colors.blue.shade600,
                    width: cardWidth,
                    onTap: isLoading
                        ? null
                        : () => context.read<ImportBloc>().add(const PickAndParseImport(ImportSource.bitwarden)),
                    colors: colors,
                    isDark: isDark,
                  ),
                  _SourceCard(
                    name: '1Password',
                    subtitle: 'File > Export > All Items',
                    icon: Icons.vpn_key_rounded,
                    color: Colors.teal.shade600,
                    width: cardWidth,
                    onTap: isLoading
                        ? null
                        : () => context.read<ImportBloc>().add(const PickAndParseImport(ImportSource.onePassword)),
                    colors: colors,
                    isDark: isDark,
                  ),
                ],
              );
            }
          ),
          const SizedBox(height: 32),
          _HowToExportGuide(colors: colors, isDark: isDark),
          if (isLoading) ...[
            const SizedBox(height: 32),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                backgroundColor: colors.accent.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
            const Center(child: Text('Parsing CSV securely...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context, ImportPreviewing state, AppColors colors, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Options bar
        Container(
          color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF8FAFC),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Select all checkbox
              Checkbox(
                tristate: true,
                activeColor: colors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                value: state.selectedCount == 0
                    ? false
                    : state.selectedCount == state.items.length
                        ? true
                        : null,
                onChanged: (v) => context
                    .read<ImportBloc>()
                    .add(ToggleSelectAll(v ?? false)),
              ),
              const Text('Select All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              
              // Group by folder toggle
              Row(
                children: [
                  const Text('Map to existing folders', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Switch(
                    value: _groupByFolder,
                    activeColor: colors.accent,
                    onChanged: (v) => setState(() => _groupByFolder = v),
                  ),
                ],
              ),
              
              // Fallback project targeted selection
              if (!_groupByFolder) ...[
                const SizedBox(width: 16),
                Container(
                  height: 24, width: 1, 
                  color: colors.border,
                  margin: const EdgeInsets.only(right: 16),
                ),
                BlocBuilder<ProjectBloc, ProjectState>(
                  builder: (context, projectState) {
                    final projects = projectState is ProjectLoaded ? projectState.projects : <Project>[];

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.transparent : Colors.white,
                            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : colors.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _selectedTargetProjectId,
                              icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                              padding: EdgeInsets.zero,
                              items: [
                                const DropdownMenuItem(
                                  value: 'create_new',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_rounded, size: 16),
                                      SizedBox(width: 6),
                                      Text('New Project', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                ...projects.map((p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(
                                    p.name.length > 20 ? '${p.name.substring(0, 20)}...' : p.name,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                )),
                              ],
                              onChanged: (val) async {
                                if (val == 'create_new') {
                                  final result = await showDialog<Map<String, dynamic>>(
                                    context: context,
                                    builder: (_) => const AddProjectDialog(),
                                  );
                                  if (result != null) {
                                    final bloc = context.read<ProjectBloc>();
                                    bloc.add(AddProject(result['name'], result['description'], result['color']));
                                    
                                    // Wait brief moment for bloc state to settle
                                    await Future.delayed(const Duration(milliseconds: 200));
                                    final st = bloc.state;
                                    if (st is ProjectLoaded) {
                                      setState(() {
                                        _selectedTargetProjectId = st.selectedProjectId;
                                      });
                                    }
                                  }
                                } else {
                                  setState(() => _selectedTargetProjectId = val);
                                }
                              },
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        // Preview table
        Expanded(
          child: ImportPreviewTable(
            items: state.items,
            onToggle: (i) =>
                context.read<ImportBloc>().add(ToggleImportRow(i)),
          ),
        ),
      ],
    );
  }

  // ─── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context, ImportState state, AppColors colors, bool isDark) {
    if (state is ImportIdle || state is ImportPicking) return const SizedBox.shrink();

    final isPreviewing = state is ImportPreviewing;
    final isCommitting = state is ImportCommitting;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? colors.surface.withValues(alpha: 0.8) : const Color(0xFFFCFDFD),
        border: Border(top: BorderSide(color: colors.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: isCommitting
                ? null
                : () {
                    context.read<ImportBloc>().add(ResetImport());
                    Navigator.pop(context);
                  },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          if (isPreviewing) ...[
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => context.read<ImportBloc>().add(ResetImport()),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: colors.border),
              ),
              child: const Text('Back to sources', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              icon: const Icon(Icons.download_done_rounded, size: 20),
              label: Text('Import ${(state).selectedCount} secrets', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              onPressed: isCommitting || (state).selectedCount == 0
                  ? null
                  : () => context.read<ImportBloc>().add(CommitImport(
                        groupByFolder: _groupByFolder,
                        fallbackProjectName: 'Imported Secrets',
                        targetProjectId: _selectedTargetProjectId,
                      )),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                backgroundColor: colors.accent,
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Source card ─────────────────────────────────────────────────────────────

class _SourceCard extends StatefulWidget {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double width;
  final VoidCallback? onTap;
  final AppColors colors;
  final bool isDark;

  const _SourceCard({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.width,
    required this.onTap,
    required this.colors,
    required this.isDark,
  });

  @override
  State<_SourceCard> createState() => _SourceCardState();
}

class _SourceCardState extends State<_SourceCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCirc,
          width: widget.width,
          padding: const EdgeInsets.all(20),
          transform: Matrix4.identity()..translate(0.0, _isHovered && widget.onTap != null ? -4.0 : 0.0),
          decoration: BoxDecoration(
            color: widget.isDark ? widget.colors.surface : Colors.white,
            gradient: _isHovered && widget.onTap != null
                ? LinearGradient(
                    colors: [
                      widget.isDark ? widget.colors.surface : Colors.white,
                      widget.color.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered && widget.onTap != null ? widget.color.withValues(alpha: 0.5) : widget.colors.border,
              width: _isHovered && widget.onTap != null ? 2 : 1,
            ),
            boxShadow: _isHovered && widget.onTap != null
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
               AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: EdgeInsets.all(_isHovered ? 12 : 10),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: _isHovered ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.icon,
                  size: _isHovered ? 28 : 24,
                  color: widget.color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                    const SizedBox(height: 2),
                    Text(widget.subtitle,
                        style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600, height: 1.2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── How to export guide ──────────────────────────────────────────────────────

class _HowToExportGuide extends StatelessWidget {
  final AppColors colors;
  final bool isDark;

  const _HowToExportGuide({required this.colors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.15) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          title: Row(
            children: [
              Icon(Icons.help_outline_rounded, size: 20, color: colors.accent),
              const SizedBox(width: 12),
              const Text('How to export from each manager', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _guide('LastPass', '1. Log in at lastpass.com\n2. Advanced Options > Export\n3. Enter master password → Download CSV')),
                  Expanded(child: _guide('Bitwarden', '1. Log in at vault.bitwarden.com\n2. Tools > Export Vault\n3. Format: .csv → Confirm export')),
                  Expanded(child: _guide('1Password', '1. Open 1Password desktop app\n2. File > Export > All Items\n3. Format: CSV → Save file')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guide(String name, String steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(steps, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, height: 1.5)),
      ],
    );
  }
}
