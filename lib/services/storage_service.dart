import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/project.dart';
import '../models/secret.dart';
import '../models/audit_entry.dart';

class StorageService {
  static const String _projectsBoxName = 'projectsBox';
  static const String _secretsBoxName = 'secretsBox';
  static const String _settingsBoxName = 'settingsBox';
  static const String _auditBoxName = 'audit_log';

  // Increment this constant whenever the Secret / SecretField Hive schema changes.
  // On next launch, the old secrets box will be deleted automatically.
  // Increment these constants whenever models change.
  static const int _currentSecretsSchemaVersion = 4;
  static const int _currentProjectsSchemaVersion = 2;
  static const String _secretsSchemaVersionKey = 'secrets_schema_version';
  static const String _projectsSchemaVersionKey = 'projects_schema_version';

  late Box<Project> projectsBox;
  late Box<Secret> secretsBox;
  late Box settingsBox;
  late Box<AuditEntry> auditBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(ProjectAdapter());
    Hive.registerAdapter(SecretAdapter());
    Hive.registerAdapter(SecretFieldAdapter());
    Hive.registerAdapter(AuditEntryAdapter());
    Hive.registerAdapter(AuditActionAdapter());

    settingsBox = await Hive.openBox(_settingsBoxName);

    // Schema versioning for Secrets
    final storedSecretsVersion = settingsBox.get(_secretsSchemaVersionKey, defaultValue: 0) as int;
    if (storedSecretsVersion != _currentSecretsSchemaVersion) {
      await _deleteBoxFiles(_secretsBoxName);
      await settingsBox.put(_secretsSchemaVersionKey, _currentSecretsSchemaVersion);
    }
    secretsBox = await Hive.openBox<Secret>(_secretsBoxName);

    // Schema versioning for Projects
    final storedProjectsVersion = settingsBox.get(_projectsSchemaVersionKey, defaultValue: 0) as int;
    if (storedProjectsVersion != _currentProjectsSchemaVersion) {
      await _deleteBoxFiles(_projectsBoxName);
      await settingsBox.put(_projectsSchemaVersionKey, _currentProjectsSchemaVersion);
    }
    projectsBox = await Hive.openBox<Project>(_projectsBoxName);

    auditBox = await Hive.openBox<AuditEntry>(_auditBoxName);
  }

  Future<void> _deleteBoxFiles(String boxName) async {
    final dir = await getApplicationDocumentsDirectory();
    for (final ext in ['.hive', '.lock']) {
      final file = File(p.join(dir.path, '$boxName$ext'));
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  Future<void> saveMasterPasswordHash(String hash) async {
    await settingsBox.put('master_password_hash', hash);
  }

  Future<String?> getMasterPasswordHash() async {
    return settingsBox.get('master_password_hash');
  }

  Future<void> saveProject(Project project) async {
    await projectsBox.put(project.id, project);
  }

  Future<void> deleteProject(String id) async {
    await projectsBox.delete(id);
    final secretsToDelete = secretsBox.values
        .where((s) => s.projectId == id)
        .map((s) => s.id)
        .toList();
    for (var secretId in secretsToDelete) {
      await secretsBox.delete(secretId);
    }
  }

  List<Project> getProjects() {
    final projects = projectsBox.values.toList();
    projects.sort((a, b) {
      final cmp = a.sortOrder.compareTo(b.sortOrder);
      if (cmp != 0) return cmp;
      return b.createdAt.compareTo(a.createdAt);
    });
    return projects;
  }

  Future<void> saveSecret(Secret secret) async {
    await secretsBox.put(secret.id, secret);
  }

  Future<void> deleteSecret(String id) async {
    await secretsBox.delete(id);
  }

  List<Secret> getSecrets(String projectId) {
    final secrets = secretsBox.values
        .where((s) => s.projectId == projectId)
        .toList();
    secrets.sort((a, b) {
      final cmp = a.sortOrder.compareTo(b.sortOrder);
      if (cmp != 0) return cmp;
      return b.createdAt.compareTo(a.createdAt);
    });
    return secrets;
  }

  List<Secret> getAllSecrets() {
    final secrets = secretsBox.values.toList();
    secrets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return secrets;
  }
}
