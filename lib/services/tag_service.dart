import '../models/secret.dart';

class TagService {
  static final Map<RegExp, String> _patterns = {
    RegExp(r'github\.com', caseSensitive: false): 'git',
    RegExp(r'gitlab\.com', caseSensitive: false): 'git',
    RegExp(r'5432'): 'postgres',
    RegExp(r'3306'): 'mysql',
    RegExp(r'6379'): 'redis',
    RegExp(r'27017'): 'mongodb',
    RegExp(r'aws|amazon', caseSensitive: false): 'cloud',
    RegExp(r'azure', caseSensitive: false): 'cloud',
    RegExp(r'google\.cloud|gcp', caseSensitive: false): 'cloud',
    RegExp(r'localhost|127\.0\.0\.1'): 'dev',
    RegExp(r'prod|production', caseSensitive: false): 'prod',
    RegExp(r'stg|staging', caseSensitive: false): 'stg',
    RegExp(r'test|qa', caseSensitive: false): 'test',
    RegExp(r'api|v1|v2', caseSensitive: false): 'api',
    RegExp(r'token|key|auth', caseSensitive: false): 'auth',
    RegExp(r'ssh|pem|id_rsa', caseSensitive: false): 'ssh',
    RegExp(r's3|bucket', caseSensitive: false): 'storage',
    RegExp(r'docker|kubernetes|k8s', caseSensitive: false): 'devops',
    RegExp(r'slack|discord', caseSensitive: false): 'social',
  };

  /// Analyzes the title, note, and fields to suggest tags
  Set<String> suggestTags({
    required String title,
    String? note,
    required List<SecretField> fields,
    List<String>? existingTags,
  }) {
    final suggestions = <String>{};
    final contentToAnalyze = [
      title,
      note ?? '',
      ...fields.map((f) => f.label),
      ...fields.map((f) => f.encryptedValue), // Here 'encryptedValue' is the plain text during edit
    ].join(' ').toLowerCase();

    for (final entry in _patterns.entries) {
      if (entry.key.hasMatch(contentToAnalyze)) {
        suggestions.add(entry.value);
      }
    }

    // Remove tags that are already present
    if (existingTags != null) {
      suggestions.removeAll(existingTags);
    }

    return suggestions;
  }
}
