import 'package:equatable/equatable.dart';
import '../../models/secret.dart';
import '../../models/project.dart';

class SearchResult {
  final Secret secret;
  final Project project;
  final String matchedField; // which field matched the query
  const SearchResult({required this.secret, required this.project, required this.matchedField});
}

abstract class SearchState extends Equatable {
  const SearchState();
  @override
  List<Object?> get props => [];
}

class SearchEmpty extends SearchState {}

class SearchLoaded extends SearchState {
  final List<SearchResult> results;
  final int selectedIndex;
  const SearchLoaded({required this.results, this.selectedIndex = 0});
  
  @override
  List<Object?> get props => [results, selectedIndex];

  SearchLoaded copyWith({List<SearchResult>? results, int? selectedIndex}) =>
      SearchLoaded(
        results: results ?? this.results, 
        selectedIndex: selectedIndex ?? this.selectedIndex,
      );
}
