import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_event.dart';
import '../blocs/settings/settings_state.dart';
import '../blocs/project/project_bloc.dart';
import '../blocs/project/project_state.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: isDark ? colors.surface : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: colors.border,
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 18),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colors.border),
        ),
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state is! SettingsLoaded) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Appearance ─────────────────────────────
                    const _SectionHeader('Appearance'),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      colors: colors,
                      isDark: isDark,
                      children: [
                        _SettingsRow(
                          icon: Icons.dark_mode_outlined,
                          iconColor: const Color(0xFF7C4DFF),
                          title: 'Dark Mode',
                          subtitle: 'Switch between light and dark theme',
                          trailing: Switch(
                            value: state.isDarkMode,
                            onChanged: (_) =>
                                context.read<SettingsBloc>().add(ToggleTheme()),
                            activeThumbColor: colors.accent,
                            activeTrackColor:
                                colors.accent.withValues(alpha: 0.5),
                          ),
                          colors: colors,
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Security ────────────────────────────────
                    const _SectionHeader('Security'),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      colors: colors,
                      isDark: isDark,
                      children: [
                        _SettingsRow(
                          icon: Icons.timer_outlined,
                          iconColor: const Color(0xFFFF9800),
                          title: 'Auto-Lock Duration',
                          subtitle: 'Lock vault after inactivity period',
                          trailing: _StyledDropdown(
                            value: state.autoLockMinutes,
                            items: const {1: '1 min', 5: '5 min', 15: '15 min', 30: '30 min', 60: '1 hour'},
                            onChanged: (val) {
                              if (val != null) {
                                context
                                    .read<SettingsBloc>()
                                    .add(SetAutoLockDuration(val));
                              }
                            },
                            colors: colors,
                          ),
                          colors: colors,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Divider(height: 1, color: colors.border),
                        ),
                        _SettingsRow(
                          icon: Icons.content_paste_go_rounded,
                          iconColor: const Color(0xFFE91E63),
                          title: 'Clipboard Auto-Clear',
                          subtitle: 'Clear copied text after specified time',
                          trailing: _StyledDropdown(
                            value: state.clipboardClearSeconds,
                            items: const {
                              0: 'Never',
                              10: '10 sec',
                              30: '30 sec',
                              60: '60 sec',
                              120: '2 min',
                            },
                            onChanged: (val) {
                              if (val != null) {
                                context
                                    .read<SettingsBloc>()
                                    .add(SetClipboardClearDuration(val));
                              }
                            },
                            colors: colors,
                          ),
                          colors: colors,
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Data Management ─────────────────────────
                    const _SectionHeader('Data Management'),
                    const SizedBox(height: 12),
                    Builder(builder: (ctx) {
                      final selectedProjectId = ctx.select((ProjectBloc b) {
                        final s = b.state;
                        return s is ProjectLoaded ? s.selectedProjectId : null;
                      });

                      return _SettingsCard(
                        colors: colors,
                        isDark: isDark,
                        children: [
                          _SettingsRow(
                            icon: Icons.file_upload_outlined,
                            iconColor: const Color(0xFF4CAF50),
                            title: 'Export Current Project',
                            subtitle: selectedProjectId == null
                                ? 'Select a project first to export it'
                                : 'Export all secrets as a .env file',
                            trailing: FilledButton.icon(
                              icon: const Icon(Icons.download_rounded, size: 16),
                              label: const Text('Export'),
                              style: FilledButton.styleFrom(
                                backgroundColor: selectedProjectId == null
                                    ? Colors.grey
                                    : const Color(0xFF4CAF50),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                textStyle: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              onPressed: selectedProjectId == null
                                  ? null
                                  : () => context.read<SettingsBloc>().add(
                                        ExportProjectEvent(selectedProjectId),
                                      ),
                            ),
                            colors: colors,
                          ),
                        ],
                      );
                    }),

                    const SizedBox(height: 40),

                    // ── About ───────────────────────────────────
                    const _SectionHeader('About'),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      colors: colors,
                      isDark: isDark,
                      children: [
                        _SettingsRow(
                          icon: Icons.shield_rounded,
                          iconColor: const Color(0xFF7C4DFF),
                          title: 'Secret Vault',
                          subtitle: 'Version 2.0 · AES-256 Encrypted',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                              border: Border.all(
                                  color: const Color(0xFF7C4DFF)
                                      .withValues(alpha: 0.25)),
                            ),
                            child: const Text(
                              'v2.0',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF7C4DFF)),
                            ),
                          ),
                          colors: colors,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final AppColors colors;
  final bool isDark;
  final List<Widget> children;

  const _SettingsCard({
    required this.colors,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? colors.card : Colors.white,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 1, color: colors.border),
              ),
          ]
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final AppColors colors;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: iconColor.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }
}

class _StyledDropdown extends StatelessWidget {
  final int value;
  final Map<int, String> items;
  final ValueChanged<int?> onChanged;
  final AppColors colors;

  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
        color: colors.surface,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          borderRadius: BorderRadius.circular(12),
          isDense: true,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          items: items.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
