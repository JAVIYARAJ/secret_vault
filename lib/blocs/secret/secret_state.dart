import 'package:equatable/equatable.dart';
import '../../models/secret.dart';

abstract class SecretState extends Equatable {
  const SecretState();
  
  @override
  List<Object?> get props => [];
}

class SecretInitial extends SecretState {}

class SecretLoading extends SecretState {}

class SecretLoaded extends SecretState {
  final List<Secret> secrets;
  final Set<String> revealedIds;
  final String searchQuery;
  final SecretType? filterType;
  final Map<SecretType, int> typeCounts;
  final String? expandedId;
  final int expansionNonce;

  const SecretLoaded({
    required this.secrets,
    this.revealedIds = const {},
    this.searchQuery = '',
    this.filterType,
    this.typeCounts = const {},
    this.expandedId,
    this.expansionNonce = 0,
  });

  List<Secret> get pinned => secrets.where((s) => s.isFavourite).toList();
  List<Secret> get unpinned => secrets.where((s) => !s.isFavourite).toList();

  SecretLoaded copyWith({
    List<Secret>? secrets,
    Set<String>? revealedIds,
    String? searchQuery,
    SecretType? filterType,
    Map<SecretType, int>? typeCounts,
    bool clearFilter = false,
    String? expandedId,
    int? expansionNonce,
  }) {
    return SecretLoaded(
      secrets: secrets ?? this.secrets,
      revealedIds: revealedIds ?? this.revealedIds,
      searchQuery: searchQuery ?? this.searchQuery,
      filterType: clearFilter ? null : (filterType ?? this.filterType),
      typeCounts: typeCounts ?? this.typeCounts,
      expandedId: expandedId ?? this.expandedId,
      expansionNonce: expansionNonce ?? this.expansionNonce,
    );
  }

  @override
  List<Object?> get props => [
        secrets,
        revealedIds,
        searchQuery,
        filterType,
        typeCounts,
        expandedId,
        expansionNonce,
      ];
}

class SecretError extends SecretState {
  final String message;

  const SecretError(this.message);

  @override
  List<Object?> get props => [message];
}
