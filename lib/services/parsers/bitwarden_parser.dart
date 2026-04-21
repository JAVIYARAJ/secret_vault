import 'package:csv/csv.dart';
import 'base_parser.dart';
import '../../models/secret.dart';

class BitwardenParser extends BaseParser {
  @override
  List<ImportedSecret> parse(String csvContent) {
    final rows = const CsvToListConverter(eol: '\n')
        .convert(csvContent)
        .cast<List<dynamic>>();

    if (rows.isEmpty) return [];

    // Parse header to get column indices dynamically
    final header = rows.first.map((c) => c.toString()).toList();
    final idx = buildIndex(header);

    final dataRows = rows.skip(1).toList();
    final results = <ImportedSecret>[];

    for (final row in dataRows) {
      if (row.isEmpty) continue;

      final folder    = getValue(row, idx, 'folder');
      final typeName  = getValue(row, idx, 'type');
      final name      = getValue(row, idx, 'name');
      final notes     = getValue(row, idx, 'notes');
      final uri       = getValue(row, idx, 'login_uri');
      final username  = getValue(row, idx, 'login_username');
      final password  = getValue(row, idx, 'login_password');
      final totp      = getValue(row, idx, 'login_totp');
      final extraFields = getValue(row, idx, 'fields');

      final type = mapType(typeName);
      final fields = <ImportedField>[];

      switch (type) {
        case SecretType.login:
          if (uri.isNotEmpty) {
            fields.add(ImportedField(label: 'Website URL', plaintextValue: uri));
          }
          if (username.isNotEmpty) {
            fields.add(ImportedField(
                label: 'Email / Username', plaintextValue: username));
          }
          if (password.isNotEmpty) {
            fields.add(ImportedField(
                label: 'Password',
                plaintextValue: password,
                isSecret: true));
          }
          if (totp.isNotEmpty) {
            fields.add(ImportedField(
                label: 'TOTP Secret',
                plaintextValue: totp,
                isSecret: true));
          }
          break;

        case SecretType.note:
          if (notes.isNotEmpty) {
            fields.add(ImportedField(
                label: 'Content',
                plaintextValue: notes,
                isMultiline: true));
          }
          break;

        case SecretType.creditCard:
          // Bitwarden stores card fields in the 'fields' column as
          // "CardholderName:John\nNumber:1234..." — parse that
          fields.addAll(_parseBitwardenCardFields(extraFields));
          break;

        default:
          // Custom type — dump all known fields
          if (username.isNotEmpty) {
            fields.add(ImportedField(label: 'Username', plaintextValue: username));
          }
          if (password.isNotEmpty) {
            fields.add(ImportedField(
                label: 'Password', plaintextValue: password, isSecret: true));
          }
          // Parse extra custom fields
          fields.addAll(_parseBitwardenExtraFields(extraFields));
          break;
      }

      results.add(ImportedSecret(
        title: buildTitle(name, username, uri),
        projectHint: folder.isNotEmpty ? folder : 'Bitwarden Import',
        type: type,
        fields: fields,
        note: type != SecretType.note && notes.isNotEmpty ? notes : null,
        tags: ['bitwarden'],
      ));
    }

    return results;
  }

  /// Bitwarden extra fields format: "label:value\nlabel:value"
  List<ImportedField> _parseBitwardenExtraFields(String raw) {
    if (raw.isEmpty) return [];
    final fields = <ImportedField>[];
    for (final line in raw.split('\n')) {
      final colon = line.indexOf(':');
      if (colon == -1) continue;
      final label = line.substring(0, colon).trim();
      final value = line.substring(colon + 1).trim();
      if (label.isEmpty || value.isEmpty) continue;
      final isSecret = label.toLowerCase().contains('password') ||
          label.toLowerCase().contains('secret') ||
          label.toLowerCase().contains('key');
      fields.add(ImportedField(
          label: label, plaintextValue: value, isSecret: isSecret));
    }
    return fields;
  }

  List<ImportedField> _parseBitwardenCardFields(String raw) {
    // Known Bitwarden card field names
    const cardMap = {
      'cardholdername': ('Cardholder Name', false),
      'number':         ('Card Number', true),
      'expmonth':       ('Expiry Month', false),
      'expyear':        ('Expiry Year', false),
      'code':           ('CVV', true),
      'brand':          ('Brand', false),
    };

    final fields = <ImportedField>[];
    for (final line in raw.split('\n')) {
      final colon = line.indexOf(':');
      if (colon == -1) continue;
      final key = line.substring(0, colon).trim().toLowerCase();
      final value = line.substring(colon + 1).trim();
      if (value.isEmpty) continue;
      final mapping = cardMap[key];
      fields.add(ImportedField(
        label: mapping?.$1 ?? key,
        plaintextValue: value,
        isSecret: mapping?.$2 ?? false,
      ));
    }
    return fields;
  }
}
