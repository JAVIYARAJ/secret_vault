import 'package:csv/csv.dart';
import 'base_parser.dart';
import '../../models/secret.dart';

class OnePasswordParser extends BaseParser {
  @override
  List<ImportedSecret> parse(String csvContent) {
    final rows = const CsvToListConverter(eol: '\n')
        .convert(csvContent)
        .cast<List<dynamic>>();

    if (rows.isEmpty) return [];

    final header = rows.first.map((c) => c.toString()).toList();
    final idx = buildIndex(header);

    // Detect format: generic export vs. category-specific export
    final isGeneric = idx.containsKey('title') && idx.containsKey('type');
    final isCreditCard = idx.containsKey('card number') || idx.containsKey('number');
    final isLogin = idx.containsKey('username') && !isCreditCard;

    final dataRows = rows.skip(1).toList();
    final results = <ImportedSecret>[];

    for (final row in dataRows) {
      if (row.isEmpty) continue;

      if (isGeneric) {
        results.addAll(_parseGenericRow(row, idx));
      } else if (isCreditCard) {
        results.addAll(_parseCreditCardRow(row, idx));
      } else if (isLogin) {
        results.addAll(_parseLoginRow(row, idx));
      } else {
        results.addAll(_parseGenericRow(row, idx));
      }
    }

    return results;
  }

  List<ImportedSecret> _parseGenericRow(
      List<dynamic> row, Map<String, int> idx) {
    final title    = getValue(row, idx, 'title');
    final username = getValue(row, idx, 'username');
    final password = getValue(row, idx, 'password');
    final otp      = getValue(row, idx, 'otpauth');
    final urls     = getValue(row, idx, 'urls');
    final notes    = getValue(row, idx, 'notes');
    final typeName = getValue(row, idx, 'type');

    final type = mapType(typeName);
    final fields = <ImportedField>[];

    switch (type) {
      case SecretType.login:
        if (urls.isNotEmpty) {
          // 1Password may export multiple URLs separated by space
          final firstUrl = urls.split(' ').first;
          fields.add(ImportedField(label: 'Website URL', plaintextValue: firstUrl));
        }
        if (username.isNotEmpty) {
          fields.add(ImportedField(
              label: 'Email / Username', plaintextValue: username));
        }
        if (password.isNotEmpty) {
          fields.add(ImportedField(
              label: 'Password', plaintextValue: password, isSecret: true));
        }
        if (otp.isNotEmpty) {
          fields.add(ImportedField(
              label: 'OTP Auth', plaintextValue: otp, isSecret: true));
        }
        break;

      case SecretType.note:
        if (notes.isNotEmpty) {
          fields.add(ImportedField(
              label: 'Content', plaintextValue: notes, isMultiline: true));
        }
        break;

      default:
        if (username.isNotEmpty) {
          fields.add(ImportedField(label: 'Username', plaintextValue: username));
        }
        if (password.isNotEmpty) {
          fields.add(ImportedField(
              label: 'Password', plaintextValue: password, isSecret: true));
        }
        break;
    }

    return [
      ImportedSecret(
        title: buildTitle(title, username, urls),
        projectHint: '1Password Import',
        type: type,
        fields: fields,
        note: type != SecretType.note && notes.isNotEmpty ? notes : null,
        tags: ['1password'],
      )
    ];
  }

  List<ImportedSecret> _parseCreditCardRow(
      List<dynamic> row, Map<String, int> idx) {
    return [
      ImportedSecret(
        title: getValue(row, idx, 'title').isNotEmpty
            ? getValue(row, idx, 'title')
            : 'Credit Card',
        projectHint: '1Password Import',
        type: SecretType.creditCard,
        fields: [
          if (getValue(row, idx, 'cardholder name').isNotEmpty)
            ImportedField(
                label: 'Cardholder Name',
                plaintextValue: getValue(row, idx, 'cardholder name')),
          if (getValue(row, idx, 'card number').isNotEmpty ||
              getValue(row, idx, 'number').isNotEmpty)
            ImportedField(
              label: 'Card Number',
              plaintextValue: getValue(row, idx, 'card number').isNotEmpty
                  ? getValue(row, idx, 'card number')
                  : getValue(row, idx, 'number'),
              isSecret: true,
            ),
          if (getValue(row, idx, 'expiry date').isNotEmpty ||
              getValue(row, idx, 'expiration date').isNotEmpty)
            ImportedField(
              label: 'Expiry',
              plaintextValue: getValue(row, idx, 'expiry date').isNotEmpty
                  ? getValue(row, idx, 'expiry date')
                  : getValue(row, idx, 'expiration date'),
            ),
          if (getValue(row, idx, 'verification number').isNotEmpty ||
              getValue(row, idx, 'cvv').isNotEmpty)
            ImportedField(
              label: 'CVV',
              plaintextValue: getValue(row, idx, 'verification number').isNotEmpty
                  ? getValue(row, idx, 'verification number')
                  : getValue(row, idx, 'cvv'),
              isSecret: true,
            ),
        ],
        tags: ['1password'],
      )
    ];
  }

  List<ImportedSecret> _parseLoginRow(
      List<dynamic> row, Map<String, int> idx) {
    final title    = getValue(row, idx, 'title');
    final username = getValue(row, idx, 'username');
    final password = getValue(row, idx, 'password');
    final url      = getValue(row, idx, 'url');
    final notes    = getValue(row, idx, 'notes');

    return [
      ImportedSecret(
        title: buildTitle(title, username, url),
        projectHint: '1Password Import',
        type: SecretType.login,
        fields: [
          if (url.isNotEmpty)
            ImportedField(label: 'Website URL', plaintextValue: url),
          if (username.isNotEmpty)
            ImportedField(label: 'Email / Username', plaintextValue: username),
          if (password.isNotEmpty)
            ImportedField(
                label: 'Password', plaintextValue: password, isSecret: true),
        ],
        note: notes.isNotEmpty ? notes : null,
        tags: ['1password'],
      )
    ];
  }
}
