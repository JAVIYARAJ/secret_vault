import '../../models/secret.dart';

/// A parsed row before it becomes a Secret.
/// Keeps plaintext values until EncryptionService encrypts them on import.
class ImportedSecret {
  final String title;
  final String projectHint;   // folder/group name from source manager
  final SecretType type;
  final List<ImportedField> fields;
  final List<String> tags;
  final String? note;
  bool selected;              // user can deselect rows in preview

  ImportedSecret({
    required this.title,
    required this.projectHint,
    required this.type,
    required this.fields,
    this.tags = const [],
    this.note,
    this.selected = true,
  });
}

class ImportedField {
  final String label;
  final String plaintextValue;
  final bool isSecret;
  final bool isMultiline;

  const ImportedField({
    required this.label,
    required this.plaintextValue,
    this.isSecret = false,
    this.isMultiline = false,
  });
}

abstract class BaseParser {

  /// Parse raw CSV string into ImportedSecret list.
  List<ImportedSecret> parse(String csvContent);

  /// Map a source type string (e.g. "Login", "Secure Note") to SecretType.
  SecretType mapType(String? sourceType) {
    if (sourceType == null) return SecretType.login;
    final t = sourceType.toLowerCase().trim();
    if (t.contains('note') || t.contains('secure note')) return SecretType.note;
    if (t.contains('card') || t.contains('credit')) return SecretType.creditCard;
    if (t.contains('bank') || t.contains('account')) return SecretType.custom;
    if (t.contains('ssh') || t.contains('key')) return SecretType.sshKey;
    if (t.contains('wifi') || t.contains('wireless')) return SecretType.wifi;
    if (t.contains('database') || t.contains('server')) return SecretType.database;
    if (t.contains('api')) return SecretType.apiKey;
    return SecretType.login;
  }

  /// Safe CSV cell read — returns empty string if index out of range.
  String cell(List<dynamic> row, int index) {
    if (index >= row.length) return '';
    return (row[index] as String? ?? '').trim();
  }

  /// Build a title from name + username + url
  String buildTitle(String name, String username, [String url = '']) {
    if (name.isNotEmpty) return name;

    if (url.isNotEmpty) {
      try {
        var parsedUrl = url;
        if (!parsedUrl.startsWith('http')) {
          parsedUrl = 'https://$parsedUrl';
        }
        final uri = Uri.parse(parsedUrl);
        if (uri.host.isNotEmpty) {
          var host = uri.host.toLowerCase();
          if (host.startsWith('www.')) host = host.substring(4);
          final parts = host.split('.');
          if (parts.length > 1) {
            String domain = parts[parts.length - 2];
            return domain[0].toUpperCase() + domain.substring(1);
          } else {
            return host;
          }
        }
      } catch (_) {}
    }

    if (username.isNotEmpty) return username;
    return 'Untitled';
  }

  Map<String, int> buildIndex(List<String> header) {
    final map = <String, int>{};
    for (int i = 0; i < header.length; i++) {
      map[header[i].toLowerCase().trim()] = i;
    }
    return map;
  }

  String getValue(List<dynamic> row, Map<String, int> idx, String key) {
    final i = idx[key.toLowerCase().trim()];
    if (i == null || i >= row.length) return '';
    return (row[i] as String? ?? '').trim();
  }

  String getAnyValue(List<dynamic> row, Map<String, int> idx, List<String> keys) {
    for (final key in keys) {
      final i = idx[key.toLowerCase().trim()];
      if (i != null && i < row.length) {
        final val = (row[i] as String? ?? '').trim();
        if (val.isNotEmpty) return val;
      }
    }
    return '';
  }
}
