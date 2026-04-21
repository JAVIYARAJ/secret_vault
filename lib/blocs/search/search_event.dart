import 'package:equatable/equatable.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();
  @override
  List<Object?> get props => [];
}

class RunSearch extends SearchEvent {
  final String query;
  const RunSearch(this.query);
  @override
  List<Object?> get props => [query];
}

class ClearSearch extends SearchEvent {}
class SelectNextResult extends SearchEvent {}
class SelectPrevResult extends SearchEvent {}
