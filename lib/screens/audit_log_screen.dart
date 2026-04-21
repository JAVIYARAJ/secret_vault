import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/audit/audit_bloc.dart';
import '../blocs/audit/audit_event.dart';
import '../blocs/audit/audit_state.dart';
import '../models/audit_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';

class AuditLogScreen extends StatelessWidget {
  final String? projectId;
  final String? projectName;

  const AuditLogScreen({super.key, this.projectId, this.projectName});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return BlocProvider.value(
      value: context.read<AuditBloc>()..add(LoadAuditLog(projectId: projectId)),
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Audit Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (projectName != null)
                Text(projectName!, style: TextStyle(fontSize: 12, color: colors.accent.withValues(alpha: 0.7))),
            ],
          ),
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.download_rounded),
                tooltip: 'Export CSV',
                onPressed: () {
                   context.read<AuditBloc>().add(ExportAuditLog(projectId: projectId));
                   AppToast.show(context, message: 'Audit log exported to Downloads', type: ToastType.success);
                },
              ),
            ),
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.delete_sweep_rounded),
                tooltip: 'Clear log',
                onPressed: () => _confirmClear(context),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: BlocBuilder<AuditBloc, AuditState>(
          builder: (context, state) {
            if (state is AuditLoading) return const Center(child: CircularProgressIndicator());
            if (state is AuditError) return Center(child: Text(state.message));
            if (state is AuditLoaded) {
              if (state.entries.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off_rounded, size: 64, color: colors.border),
                      const SizedBox(height: 16),
                      Text('No audit entries yet', style: TextStyle(color: colors.accent.withValues(alpha: 0.5))),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.entries.length,
                itemBuilder: (context, i) {
                  final e = state.entries[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  e.projectName.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: colors.accent,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatTime(e.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(_actionIcon(e.action), color: _actionColor(e.action), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  e.secretTitle,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _actionColor(e.action).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  e.action.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _actionColor(e.action),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (e.fieldLabel != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const SizedBox(width: 28),
                                Icon(Icons.label_outline_rounded, size: 14, color: colors.accent.withValues(alpha: 0.4)),
                                const SizedBox(width: 6),
                                Text(
                                  'Field: ${e.fieldLabel}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (e.metadata != null && e.metadata!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                e.metadata!,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                  fontFamily: 'Consolas',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }

  IconData _actionIcon(AuditAction action) {
    return switch (action) {
      AuditAction.copied   => Icons.copy_rounded,
      AuditAction.revealed => Icons.visibility_rounded,
      AuditAction.edited   => Icons.edit_rounded,
      AuditAction.deleted  => Icons.delete_rounded,
      AuditAction.created  => Icons.add_circle_rounded,
      AuditAction.accessed => Icons.open_in_new_rounded,
    };
  }

  Color _actionColor(AuditAction action) {
    return switch (action) {
      AuditAction.copied   => Colors.blue,
      AuditAction.revealed => Colors.orange,
      AuditAction.edited   => Colors.purple,
      AuditAction.deleted  => Colors.red,
      AuditAction.created  => Colors.green,
      AuditAction.accessed => Colors.grey,
    };
  }

  String _formatTime(DateTime dt) {
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear logs?'),
        content: const Text('This will permanently delete the audit history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<AuditBloc>().add(ClearAuditLog(projectId: projectId));
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
