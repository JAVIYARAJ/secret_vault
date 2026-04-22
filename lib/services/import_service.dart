import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/project.dart';
import '../models/secret.dart';
import 'encryption_service.dart';
import 'storage_service.dart';
import 'parsers/base_parser.dart';
import 'parsers/lastpass_parser.dart';
import 'parsers/bitwarden_parser.dart';
import 'parsers/onepassword_parser.dart';

enum ImportSource { lastPass, bitwarden, onePassword }

class ImportService {
  final StorageService _storage;
  final EncryptionService _enc;
  static const _uuid = Uuid();

  ImportService(this._storage, this._enc);

  Future<ImportParseResult> pickAndParse(ImportSource source) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select ${_sourceName(source)} CSV export',
      allowedExtensions: ['csv'],
      type: FileType.custom,
    );

    if (result == null || result.files.single.path == null) {
      return ImportParseResult.cancelled();
    }

    final path = result.files.single.path!;
    final content = await File(path).readAsString();

    if (content.trim().isEmpty) {
      return ImportParseResult.failure('The selected file is empty.');
    }

    try {
      final parser = _getParser(source);
      final parsed = parser.parse(content);

      if (parsed.isEmpty) {
        return ImportParseResult.failure(
          'No importable entries found. Make sure you selected the correct '
          'CSV format for ${_sourceName(source)}.',
        );
      }

      return ImportParseResult.success(parsed, source);
    } catch (e) {
      return ImportParseResult.failure(
        'Failed to parse CSV: ${e.toString()}\n\n'
        'Make sure the file is a valid ${_sourceName(source)} export.',
      );
    }
  }

  Future<ImportCommitResult> commitImport(
    List<ImportedSecret> selected, {
    required bool groupByFolder, 
    required String fallbackProjectName,
    String? targetProjectId,
  }) async {
    if (selected.isEmpty) return ImportCommitResult.failure('Nothing selected.');

    final existingProjects = _storage.getProjects();
    final projectIdCache = <String, String>{};

    for (final p in existingProjects) {
      projectIdCache[p.name.toLowerCase()] = p.id;
    }

    int importedSecrets = 0;
    int importedProjects = 0;

    for (final item in selected) {
      String projectId;

      if (!groupByFolder && targetProjectId != null && targetProjectId.isNotEmpty) {
        projectId = targetProjectId;
      } else {
        final folderKey = groupByFolder
            ? item.projectHint.toLowerCase()
            : fallbackProjectName.toLowerCase();

        final projectName = groupByFolder ? item.projectHint : fallbackProjectName;

        if (projectIdCache.containsKey(folderKey)) {
          projectId = projectIdCache[folderKey]!;
        } else {
          projectId = _uuid.v4();
          final project = Project(
            id: projectId,
            name: projectName,
            description: 'Imported from ${item.tags.firstOrNull ?? "CSV"}',
            createdAt: DateTime.now(),
            color: _colorForIndex(importedProjects),
          );
          await _storage.saveProject(project);
          projectIdCache[folderKey] = projectId;
          importedProjects++;
        }
      }

      final encryptedFields = item.fields.map((f) {
        final encryptedValue = f.plaintextValue.isNotEmpty
            ? _enc.encryptValue(f.plaintextValue)
            : '';
        return SecretField(
          id: _uuid.v4(),
          label: f.label,
          encryptedValue: encryptedValue,
          isSecret: f.isSecret,
          isMultiline: f.isMultiline,
        );
      }).toList();

      final secret = Secret(
        id: _uuid.v4(),
        projectId: projectId,
        title: item.title,
        typeIndex: item.type.index,
        fields: encryptedFields,
        note: item.note,
        tags: item.tags,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isFavourite: false,
      );

      await _storage.saveSecret(secret);
      importedSecrets++;
    }

    return ImportCommitResult.success(
      secretsImported: importedSecrets,
      projectsCreated: importedProjects,
    );
  }

  BaseParser _getParser(ImportSource source) {
    return switch (source) {
      ImportSource.lastPass   => LastPassParser(),
      ImportSource.bitwarden  => BitwardenParser(),
      ImportSource.onePassword => OnePasswordParser(),
    };
  }

  String _sourceName(ImportSource source) {
    return switch (source) {
      ImportSource.lastPass    => 'LastPass',
      ImportSource.bitwarden   => 'Bitwarden',
      ImportSource.onePassword => '1Password',
    };
  }

  int _colorForIndex(int i) => i % 8; 
}

enum ParseStatus { success, failure, cancelled }
enum CommitStatus { success, failure }

class ImportParseResult {
  final ParseStatus status;
  final List<ImportedSecret> items;
  final ImportSource? source;
  final String? error;

  const ImportParseResult._({
    required this.status,
    this.items = const [],
    this.source,
    this.error,
  });

  factory ImportParseResult.success(
          List<ImportedSecret> items, ImportSource source) =>
      ImportParseResult._(
          status: ParseStatus.success, items: items, source: source);

  factory ImportParseResult.failure(String error) =>
      ImportParseResult._(status: ParseStatus.failure, error: error);

  factory ImportParseResult.cancelled() =>
      const ImportParseResult._(status: ParseStatus.cancelled);
}

class ImportCommitResult {
  final CommitStatus status;
  final int secretsImported;
  final int projectsCreated;
  final String? error;

  const ImportCommitResult._({
    required this.status,
    this.secretsImported = 0,
    this.projectsCreated = 0,
    this.error,
  });

  factory ImportCommitResult.success({
    required int secretsImported,
    required int projectsCreated,
  }) => ImportCommitResult._(
        status: CommitStatus.success,
        secretsImported: secretsImported,
        projectsCreated: projectsCreated,
      );

  factory ImportCommitResult.failure(String error) =>
      ImportCommitResult._(status: CommitStatus.failure, error: error);
}
