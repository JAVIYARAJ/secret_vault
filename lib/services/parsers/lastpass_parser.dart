import 'package:csv/csv.dart';
import 'base_parser.dart';
import '../../models/secret.dart';

class LastPassParser extends BaseParser {
  @override
  List<ImportedSecret> parse(String csvContent) {
    final rows = const CsvToListConverter(eol: '\n')
        .convert(csvContent)
        .cast<List<dynamic>>();

    if (rows.isEmpty) return [];

    final header = rows.first.map((c) => c.toString()).toList();
    final idx = buildIndex(header);

    // Skip header row
    final dataRows = header.any((c) => c.toLowerCase().contains('url'))
        ? rows.skip(1).toList()
        : rows;

    final results = <ImportedSecret>[];

    for (final row in dataRows) {
      if (row.isEmpty) continue;

      final url      = getAnyValue(row, idx, ['url']);
      final username = getAnyValue(row, idx, ['username']);
      final password = getAnyValue(row, idx, ['password']);
      final extra    = getAnyValue(row, idx, ['extra', 'notes']); 
      final name     = getAnyValue(row, idx, ['name', 'title']);
      final grouping = getAnyValue(row, idx, ['grouping', 'folder', 'group']);
      // fav is ignored, user can pin in app

      // LastPass uses "http://sn" as URL for secure notes
      final isNote = url == 'http://sn';
      final type = isNote ? SecretType.note : SecretType.login;

      final fields = <ImportedField>[];

      if (!isNote) {
        if (url.isNotEmpty) {
          fields.add(ImportedField(label: 'Website URL', plaintextValue: url));
        }
        if (username.isNotEmpty) {
          fields.add(ImportedField(
            label: 'Email / Username',
            plaintextValue: username,
          ));
        }
        if (password.isNotEmpty) {
          fields.add(ImportedField(
            label: 'Password',
            plaintextValue: password,
            isSecret: true,
          ));
        }
      } else {
        // Secure note — put extra content as multiline field
        if (extra.isNotEmpty) {
          fields.add(ImportedField(
            label: 'Content',
            plaintextValue: extra,
            isMultiline: true,
          ));
        }
      }

      results.add(ImportedSecret(
        title: buildTitle(name, username, url),
        projectHint: grouping.isNotEmpty ? grouping : 'LastPass Import',
        type: type,
        fields: fields,
        note: !isNote && extra.isNotEmpty ? extra : null,
        tags: ['lastpass'],
      ));
    }

    return results;
  }
}
