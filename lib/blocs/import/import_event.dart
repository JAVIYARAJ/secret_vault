import 'package:equatable/equatable.dart';
import '../../services/import_service.dart';

abstract class ImportEvent extends Equatable {
  const ImportEvent();
  @override List<Object?> get props => [];
}

/// Step 1 — pick CSV file and parse into preview
class PickAndParseImport extends ImportEvent {
  final ImportSource source;
  const PickAndParseImport(this.source);
  @override List<Object> get props => [source];
}

/// User toggled a row in the preview table
class ToggleImportRow extends ImportEvent {
  final int index;
  const ToggleImportRow(this.index);
  @override List<Object> get props => [index];
}

/// User toggled select-all checkbox
class ToggleSelectAll extends ImportEvent {
  final bool selected;
  const ToggleSelectAll(this.selected);
  @override List<Object> get props => [selected];
}

/// Step 2 — commit the selected rows to Hive
class CommitImport extends ImportEvent {
  final bool groupByFolder;
  final String fallbackProjectName;
  final String? targetProjectId;
  const CommitImport({
    required this.groupByFolder,
    required this.fallbackProjectName,
    this.targetProjectId,
  });
  @override List<Object?> get props => [groupByFolder, fallbackProjectName, targetProjectId];
}

class ResetImport extends ImportEvent {}
