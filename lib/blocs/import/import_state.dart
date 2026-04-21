import 'package:equatable/equatable.dart';
import '../../services/import_service.dart';
import '../../services/parsers/base_parser.dart';

abstract class ImportState extends Equatable {
  const ImportState();
  @override List<Object?> get props => [];
}

class ImportIdle extends ImportState {}
class ImportPicking extends ImportState {}  // file picker open

class ImportPreviewing extends ImportState {
  final List<ImportedSecret> items;
  final ImportSource source;
  final int selectedCount;

  const ImportPreviewing({
    required this.items,
    required this.source,
    required this.selectedCount,
  });

  ImportPreviewing copyWith({
    List<ImportedSecret>? items,
    int? selectedCount,
  }) => ImportPreviewing(
    items: items ?? this.items,
    source: source,
    selectedCount: selectedCount ?? this.selectedCount,
  );

  @override List<Object?> get props => [items, source, selectedCount];
}

class ImportCommitting extends ImportState {}  // writing to Hive

class ImportSuccess extends ImportState {
  final int secretsImported;
  final int projectsCreated;
  const ImportSuccess({
    required this.secretsImported,
    required this.projectsCreated,
  });
  @override List<Object> get props => [secretsImported, projectsCreated];
}

class ImportFailure extends ImportState {
  final String message;
  const ImportFailure(this.message);
  @override List<Object> get props => [message];
}
