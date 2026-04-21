import 'package:flutter_bloc/flutter_bloc.dart';
import 'import_event.dart';
import 'import_state.dart';
import '../../services/import_service.dart';
import '../../services/parsers/base_parser.dart';

class ImportBloc extends Bloc<ImportEvent, ImportState> {
  final ImportService _service;

  ImportBloc(this._service) : super(ImportIdle()) {
    on<PickAndParseImport>(_onPick);
    on<ToggleImportRow>(_onToggleRow);
    on<ToggleSelectAll>(_onToggleAll);
    on<CommitImport>(_onCommit);
    on<ResetImport>((_, emit) => emit(ImportIdle()));
  }

  Future<void> _onPick(
      PickAndParseImport e, Emitter<ImportState> emit) async {
    emit(ImportPicking());
    final result = await _service.pickAndParse(e.source);

    switch (result.status) {
      case ParseStatus.success:
        emit(ImportPreviewing(
          items: result.items,
          source: result.source!,
          selectedCount: result.items.length, // all selected by default
        ));
        break;
      case ParseStatus.failure:
        emit(ImportFailure(result.error!));
        break;
      case ParseStatus.cancelled:
        emit(ImportIdle());
        break;
    }
  }

  void _onToggleRow(ToggleImportRow e, Emitter<ImportState> emit) {
    if (state is! ImportPreviewing) return;
    final s = state as ImportPreviewing;
    final updated = List<ImportedSecret>.from(s.items);
    updated[e.index] = _toggleSelected(updated[e.index]);
    final selectedCount = updated.where((i) => i.selected).length;
    emit(s.copyWith(items: updated, selectedCount: selectedCount));
  }

  void _onToggleAll(ToggleSelectAll e, Emitter<ImportState> emit) {
    if (state is! ImportPreviewing) return;
    final s = state as ImportPreviewing;
    final updated = s.items.map((item) {
      item.selected = e.selected;
      return item;
    }).toList();
    emit(s.copyWith(
        items: updated, selectedCount: e.selected ? updated.length : 0));
  }

  Future<void> _onCommit(CommitImport e, Emitter<ImportState> emit) async {
    if (state is! ImportPreviewing) return;
    final s = state as ImportPreviewing;
    final selected = s.items.where((i) => i.selected).toList();

    if (selected.isEmpty) {
      emit(const ImportFailure('Please select at least one item to import.'));
      return;
    }

    emit(ImportCommitting());

    final result = await _service.commitImport(
      selected,
      groupByFolder: e.groupByFolder,
      fallbackProjectName: e.fallbackProjectName,
      targetProjectId: e.targetProjectId,
    );

    switch (result.status) {
      case CommitStatus.success:
        emit(ImportSuccess(
          secretsImported: result.secretsImported,
          projectsCreated: result.projectsCreated,
        ));
        break;
      case CommitStatus.failure:
        emit(ImportFailure(result.error!));
        break;
    }
  }

  ImportedSecret _toggleSelected(ImportedSecret item) {
    item.selected = !item.selected;
    return item;
  }
}
