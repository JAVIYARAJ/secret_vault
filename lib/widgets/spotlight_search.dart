import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/search/search_bloc.dart';
import '../blocs/search/search_event.dart';
import '../blocs/search/search_state.dart';
import '../blocs/secret/secret_bloc.dart'; // import to trigger actions
import '../blocs/secret/secret_event.dart';
import '../blocs/project/project_bloc.dart'; // to navigate
import '../blocs/project/project_event.dart';
import '../theme/app_theme.dart';

class SpotlightSearch extends StatefulWidget {
  final VoidCallback onClose;
  const SpotlightSearch({super.key, required this.onClose});

  @override
  State<SpotlightSearch> createState() => _SpotlightSearchState();
}

class _SpotlightSearchState extends State<SpotlightSearch> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();           // text field focus
  final _keyboardFocus = FocusNode();   // KeyboardListener focus
  final _scrollCtrl = ScrollController();
  late AnimationController _anim;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  static const double _itemHeight = 60.0; // approximate height of each result tile

  @override
  void initState() {
    super.initState();
    // Clear previous search results for a fresh start
    context.read<SearchBloc>().add(ClearSearch());
    
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
    _opacity = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocus.requestFocus(); // keyboard listener must be focused first
      _focus.requestFocus();         // then hand focus to the text field
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _keyboardFocus.dispose();
    _scrollCtrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  /// Scroll the list so the item at [index] is visible.
  void _scrollToIndex(int index) {
    if (!_scrollCtrl.hasClients) return;
    final target = index * _itemHeight;
    final viewStart = _scrollCtrl.offset;
    final viewEnd = viewStart + _scrollCtrl.position.viewportDimension;
    if (target < viewStart) {
      _scrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    } else if (target + _itemHeight > viewEnd) {
      _scrollCtrl.animateTo(
        target + _itemHeight - _scrollCtrl.position.viewportDimension,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  void _onEnter(BuildContext context, SearchLoaded state) {
    if (state.results.isEmpty) return;
    final res = state.results[state.selectedIndex];
    
    // Navigate to project and specify the secret to expand
    context.read<ProjectBloc>().add(
          SelectProject(res.project.id, targetSecretId: res.secret.id),
        );
    
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Blur background
          GestureDetector(
            onTap: widget.onClose,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return Container(
                  color: Colors.black.withValues(alpha: 0.4 * value),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10 * value, sigmaY: 10 * value),
                    child: Container(color: Colors.transparent),
                  ),
                );
              },
            ),
          ),
          
          Center(
            child: ScaleTransition(
              scale: _scale,
              child: FadeTransition(
                opacity: _opacity,
                child: Container(
                  width: 680,
                  constraints: const BoxConstraints(maxHeight: 520),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: colors.card.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.accent.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: -10,
                      )
                    ],
                  ),
                  child: KeyboardListener(
                    focusNode: _keyboardFocus,
                    onKeyEvent: (event) {
                      if (event is KeyDownEvent || event is KeyRepeatEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          context.read<SearchBloc>().add(SelectNextResult());
                          final s = context.read<SearchBloc>().state;
                          if (s is SearchLoaded) {
                            _scrollToIndex((s.selectedIndex + 1) % s.results.length);
                          }
                        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          context.read<SearchBloc>().add(SelectPrevResult());
                          final s = context.read<SearchBloc>().state;
                          if (s is SearchLoaded) {
                            final prev = (s.selectedIndex - 1 + s.results.length) % s.results.length;
                            _scrollToIndex(prev);
                          }
                        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                          widget.onClose();
                        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                          final state = context.read<SearchBloc>().state;
                          if (state is SearchLoaded) {
                            _onEnter(context, state);
                          }
                        }
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Search Input
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                          child: TextField(
                            controller: _ctrl,
                            focusNode: _focus,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              hintText: 'Search secrets across all projects...',
                              hintStyle: TextStyle(color: colors.accent.withValues(alpha: 0.3)),
                              prefixIcon: Icon(Icons.search_rounded, color: colors.accent, size: 24),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onChanged: (v) => context.read<SearchBloc>().add(RunSearch(v)),
                          ),
                        ),
                        
                        const Divider(height: 1),
                        
                        // Results List
                        Flexible(
                          child: BlocBuilder<SearchBloc, SearchState>(
                            builder: (context, state) {
                              if (state is SearchEmpty) {
                                return _buildEmptyState('Type to find credentials, API keys, or tags...');
                              }
                              if (state is SearchLoaded) {
                                if (state.results.isEmpty) {
                                  return _buildEmptyState('No matching secrets found.');
                                }
                                return ListView.builder(
                                  controller: _scrollCtrl,
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: state.results.length,
                                  itemBuilder: (context, i) {
                                    final r = state.results[i];
                                    final isSelected = i == state.selectedIndex;
                                    return _ResultTile(
                                      result: r,
                                      isSelected: isSelected,
                                      colors: colors,
                                      onTap: () {
                                        // Select this item then open it
                                        if (!isSelected) {
                                          context.read<SearchBloc>().add(SelectResult(i));
                                        }
                                        _onEnter(context, state.copyWith(selectedIndex: i));
                                      },

                                    );
                                  },
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        
                        // Footer Hints
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: colors.border)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _hint('↑↓', 'navigate'),
                              const SizedBox(width: 24),
                              _hint('Enter', 'copy & select'),
                              const SizedBox(width: 24),
                              _hint('Esc', 'close'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _hint(String key, String label) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
        ),
        child: Text(key, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
    ],
  );
}

class _ResultTile extends StatelessWidget {
  final SearchResult result;
  final bool isSelected;
  final AppColors colors;
  final VoidCallback onTap;

  const _ResultTile({
    required this.result,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.accent.withValues(alpha: 0.3) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(result.project.color).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.lock_outline_rounded, size: 16, color: Color(result.project.color)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.secret.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${result.project.name} · ${result.matchedField}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.keyboard_return_rounded, size: 14, color: colors.accent.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
