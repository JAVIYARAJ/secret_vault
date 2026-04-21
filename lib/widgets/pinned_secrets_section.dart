import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/secret/secret_bloc.dart';
import '../blocs/secret/secret_state.dart';
import '../models/secret.dart';
import 'secret_card.dart';

class PinnedSecretsSection extends StatelessWidget {
  final Function(Secret)? onEdit;
  final Function(String)? onDelete;
  final Function(Secret)? onMove;
  
  const PinnedSecretsSection({
    super.key,
    this.onEdit,
    this.onDelete,
    this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SecretBloc, SecretState>(
      builder: (context, state) {
        if (state is! SecretLoaded) return const SizedBox.shrink();
        final pinned = state.pinned;
        if (pinned.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(count: pinned.length),
            const SizedBox(height: 8),
            ...pinned.map((secret) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SecretCard(
                key: ValueKey('pinned_${secret.id}'),
                secret: secret,
                revealedFieldIds: state.revealedIds,
                onEdit: () => onEdit?.call(secret),
                onDelete: () => onDelete?.call(secret.id),
                onMove: () => onMove?.call(secret),
              ),
            )),
            const _SectionDivider(),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final int count;
  const _SectionHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
          ),
          const SizedBox(width: 8),
          Text(
            'PINNED SECRETS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.amber.shade700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.amber.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withValues(alpha: 0.2),
                    Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'ALL SECRETS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).dividerColor.withValues(alpha: 0.1),
                    Theme.of(context).dividerColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
