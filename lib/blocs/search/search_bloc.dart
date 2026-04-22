import 'package:flutter_bloc/flutter_bloc.dart';
import 'search_event.dart';
import 'search_state.dart';
import '../../services/storage_service.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final StorageService _storageService;

  SearchBloc(this._storageService) : super(SearchEmpty()) {
    on<RunSearch>(_onSearch);
    on<ClearSearch>((_, emit) => emit(SearchEmpty()));
    on<SelectNextResult>(_onNext);
    on<SelectPrevResult>(_onPrev);
    on<SelectResult>(_onSelect);
  }


  Future<void> _onSearch(RunSearch e, Emitter<SearchState> emit) async {
    final q = e.query.toLowerCase().trim();
    if (q.isEmpty) { 
      emit(SearchEmpty()); 
      return; 
    }

    final secrets = _storageService.secretsBox.values.toList();
    final projects = {for (final p in _storageService.projectsBox.values) p.id: p};
    final results = <SearchResult>[];

    for (final secret in secrets) {
      final project = projects[secret.projectId];
      if (project == null) continue;

      bool matched = false;

      // match on title
      if (secret.title.toLowerCase().contains(q)) {
        results.add(SearchResult(secret: secret, project: project, matchedField: 'Title'));
        matched = true;
      }
      
      // match on tags
      if (!matched && (secret.tags?.any((t) => t.toLowerCase().contains(q)) ?? false)) {
        results.add(SearchResult(secret: secret, project: project, matchedField: 'Tag'));
        matched = true;
      }
      
      // match on field labels
      if (!matched) {
        for (final field in secret.fields) {
          if (field.label.toLowerCase().contains(q)) {
            results.add(SearchResult(secret: secret, project: project, matchedField: 'Field: ${field.label}'));
            matched = true;
            break;
          }
        }
      }

      // match on project name too?
      if (!matched && project.name.toLowerCase().contains(q)) {
        results.add(SearchResult(secret: secret, project: project, matchedField: 'Project'));
        matched = true;
      }
    }

    // Sort by title
    results.sort((a, b) => a.secret.title.compareTo(b.secret.title));

    emit(SearchLoaded(results: results.take(20).toList())); // Limit to 20 results for performance
  }

  void _onNext(SelectNextResult e, Emitter<SearchState> emit) {
    if (state is SearchLoaded) {
      final s = state as SearchLoaded;
      if (s.results.isEmpty) return;
      emit(s.copyWith(selectedIndex: (s.selectedIndex + 1) % s.results.length));
    }
  }

  void _onPrev(SelectPrevResult e, Emitter<SearchState> emit) {
    if (state is SearchLoaded) {
      final s = state as SearchLoaded;
      if (s.results.isEmpty) return;
      final prev = (s.selectedIndex - 1 + s.results.length) % s.results.length;
      emit(s.copyWith(selectedIndex: prev));
    }
  }


  void _onSelect(SelectResult e, Emitter<SearchState> emit) {
    if (state is SearchLoaded) {
      final s = state as SearchLoaded;
      if (e.index >= 0 && e.index < s.results.length) {
        emit(s.copyWith(selectedIndex: e.index));
      }
    }
  }
}

