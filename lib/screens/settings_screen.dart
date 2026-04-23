import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_event.dart';
import '../blocs/settings/settings_state.dart';
import '../blocs/project/project_bloc.dart';
import '../blocs/project/project_state.dart';
import '../blocs/import/import_bloc.dart';
import '../widgets/import_dialog.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../services/extension_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              backgroundColor: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.4),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Center(
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: colors.accent),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              title: Text(
                'Settings',
                style: TextStyle(
                  fontWeight: FontWeight.w900, 
                  fontSize: 22, 
                  letterSpacing: -1,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background accents consistent with Home
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00D8FF).withValues(alpha: 0.05),
              ),
            ),
          ),

          BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, state) {
              if (state is! SettingsLoaded) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 110, 24, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Appearance ─────────────────────────────
                        _ModernSection(
                          title: 'Appearance',
                          colors: colors,
                          children: [
                            _ModernSettingsRow(
                              icon: Icons.auto_awesome_rounded,
                              iconColor: const Color(0xFF7C4DFF),
                              title: 'Dark Mode',
                              subtitle: 'Adaptive theme for your environment',
                              trailing: Switch.adaptive(
                                value: state.isDarkMode,
                                onChanged: (_) => context.read<SettingsBloc>().add(ToggleTheme()),
                                activeColor: colors.accent,
                              ),
                              colors: colors,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── Security ────────────────────────────────
                        _ModernSection(
                          title: 'Security',
                          colors: colors,
                          children: [
                            _ModernSettingsRow(
                              icon: Icons.timer_rounded,
                              iconColor: const Color(0xFFFF9800),
                              title: 'Auto-Lock',
                              subtitle: 'Lock vault after inactivity',
                              trailing: _CompactDropdown(
                                value: state.autoLockMinutes,
                                items: const {1: '1m', 5: '5m', 15: '15m', 30: '30m', 60: '1h'},
                                onChanged: (val) {
                                  if (val != null) context.read<SettingsBloc>().add(SetAutoLockDuration(val));
                                },
                                colors: colors,
                              ),
                              colors: colors,
                            ),
                            _ModernSettingsRow(
                              icon: Icons.cleaning_services_rounded,
                              iconColor: const Color(0xFFE91E63),
                              title: 'Clipboard',
                              subtitle: 'Auto-clear sensitive data',
                              trailing: _CompactDropdown(
                                value: state.clipboardClearSeconds,
                                items: const {0: 'Off', 10: '10s', 30: '30s', 60: '1m', 120: '2m'},
                                onChanged: (val) {
                                  if (val != null) context.read<SettingsBloc>().add(SetClipboardClearDuration(val));
                                },
                                colors: colors,
                              ),
                              colors: colors,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── Browser Extension ───────────────────────
                        _ExtensionSettingsSection(colors: colors),

                        const SizedBox(height: 24),

                        // ── Data Management ─────────────────────────
                        _ModernSection(
                          title: 'Data Management',
                          colors: colors,
                          children: [
                            Builder(builder: (ctx) {
                              final selectedProjectId = ctx.select((ProjectBloc b) {
                                final s = b.state;
                                return s is ProjectLoaded ? s.selectedProjectId : null;
                              });

                              return _ModernSettingsRow(
                                icon: Icons.share_rounded,
                                iconColor: const Color(0xFF4CAF50),
                                title: 'Export Project',
                                subtitle: selectedProjectId == null ? 'Select a project to export' : 'Save as .env file',
                                trailing: TextButton(
                                  onPressed: selectedProjectId == null
                                      ? null
                                      : () => context.read<SettingsBloc>().add(ExportProjectEvent(selectedProjectId)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF4CAF50),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                  child: const Text('EXPORT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                ),
                                colors: colors,
                              );
                            }),
                            _ModernSettingsRow(
                              icon: Icons.cloud_download_rounded,
                              iconColor: const Color(0xFF2196F3),
                              title: 'Import',
                              subtitle: 'From LastPass or CSV',
                              trailing: TextButton(
                                onPressed: () => showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<ImportBloc>(),
                                    child: const ImportDialog(),
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF2196F3),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                child: const Text('IMPORT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                              colors: colors,
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // ── Creator Section ──────────────────────────
                        const _SectionHeader('CREATOR'),
                        const SizedBox(height: 12),
                        _CreatorCard(colors: colors, isDark: isDark),

                        const SizedBox(height: 40),
                        
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'SECRET VAULT v0',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                  color: colors.accent.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Securely Encrypted with AES-256',
                                style: TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModernSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final AppColors colors;

  const _ModernSection({required this.title, required this.children, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title.toUpperCase()),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? colors.surface.withValues(alpha: 0.4) 
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(height: 1, indent: 64, color: colors.border.withValues(alpha: 0.2)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _ModernSettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final AppColors colors;

  const _ModernSettingsRow({
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [iconColor.withValues(alpha: 0.2), iconColor.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class _CompactDropdown extends StatelessWidget {
  final int value;
  final Map<int, String> items;
  final ValueChanged<int?> onChanged;
  final AppColors colors;

  const _CompactDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110, // Fixed width for consistency
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.white.withValues(alpha: 0.08) 
            : Colors.grey.shade100,
        border: Border.all(color: colors.border.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          dropdownColor: colors.surface,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          isDense: true,
          alignment: Alignment.center, // Center the text
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          focusColor: Colors.transparent,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colors.accent,
          ),
          items: items.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    alignment: Alignment.center,
                    child: Text(e.value),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CreatorCard extends StatelessWidget {
  final AppColors colors;
  final bool isDark;

  const _CreatorCard({required this.colors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.accent, const Color(0xFF00D8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white24,
            ),
            child: const CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white,
              child: Text(
                'RJ',
                style: TextStyle(
                  color: Color(0xFF7C4DFF), 
                  fontWeight: FontWeight.w900, 
                  fontSize: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Raj Javiya',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Flutter Developer',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.code_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 8),
                      Text(
                        'Open Source Contributor',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtensionSettingsSection extends StatefulWidget {
  final AppColors colors;
  const _ExtensionSettingsSection({required this.colors});

  @override
  State<_ExtensionSettingsSection> createState() => _ExtensionSettingsSectionState();
}

class _ExtensionSettingsSectionState extends State<_ExtensionSettingsSection> {
  String? _currentPairingCode;

  @override
  Widget build(BuildContext context) {
    final extensionService = context.watch<ExtensionService>();
    final colors = widget.colors;

    return _ModernSection(
      title: 'Browser Extension',
      colors: colors,
      children: [
        _ModernSettingsRow(
          icon: Icons.extension_rounded,
          iconColor: const Color(0xFF00D8FF),
          title: 'Extension Bridge',
          subtitle: 'Enable communication with browser',
          trailing: Switch.adaptive(
            value: extensionService.isEnabled,
            onChanged: (val) => extensionService.toggle(val),
            activeColor: colors.accent,
          ),
          colors: colors,
        ),
        if (extensionService.isEnabled)
          _ModernSettingsRow(
            icon: Icons.phonelink_lock_rounded,
            iconColor: const Color(0xFFFF5252),
            title: 'Pairing',
            subtitle: extensionService.isPaired ? 'Device paired' : 'No device connected',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (extensionService.isPaired)
                  TextButton(
                    onPressed: () {
                      extensionService.revokePairing();
                      setState(() {});
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    child: const Text('REVOKE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentPairingCode = extensionService.generatePairingCode();
                    });
                  },
                  child: const Text('PAIR DEVICE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ],
            ),
            colors: colors,
          ),
        if (_currentPairingCode != null && extensionService.isEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.accent.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Enter this code in the extension:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _currentPairingCode!,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Expires in 5 minutes',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

