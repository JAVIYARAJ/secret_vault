import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'secret.g.dart';

enum SecretType {
  login,
  apiKey,
  database,
  sshKey,
  creditCard,
  wifi,
  note,
  custom,
}

@HiveType(typeId: 2)
class SecretField extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String label;
  
  @HiveField(2)
  final String encryptedValue;
  
  @HiveField(3)
  final bool isSecret;
  
  @HiveField(4)
  final bool isMultiline;

  SecretField({
    required this.id,
    required this.label,
    required this.encryptedValue,
    this.isSecret = false,
    this.isMultiline = false,
  });

  SecretField copyWith({
    String? id,
    String? label,
    String? encryptedValue,
    bool? isSecret,
    bool? isMultiline,
  }) {
    return SecretField(
      id: id ?? this.id,
      label: label ?? this.label,
      encryptedValue: encryptedValue ?? this.encryptedValue,
      isSecret: isSecret ?? this.isSecret,
      isMultiline: isMultiline ?? this.isMultiline,
    );
  }
}

@HiveType(typeId: 1)
class Secret extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String projectId;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final int typeIndex;

  @HiveField(4)
  final List<SecretField> fields;

  @HiveField(5)
  final String? note;

  @HiveField(6)
  final List<String>? tags;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime updatedAt;

  @HiveField(9)
  int sortOrder;

  @HiveField(10)
  bool isFavourite;

  Secret({
    required this.id,
    required this.projectId,
    required this.title,
    required this.typeIndex,
    required this.fields,
    this.note,
    this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
    this.isFavourite = false,
  });

  SecretType get type => SecretType.values[typeIndex];

  Secret copyWith({
    String? id,
    String? projectId,
    String? title,
    int? typeIndex,
    List<SecretField>? fields,
    String? note,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
    bool? isFavourite,
  }) {
    return Secret(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      typeIndex: typeIndex ?? this.typeIndex,
      fields: fields ?? this.fields,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      isFavourite: isFavourite ?? this.isFavourite,
    );
  }
}

class SecretTemplates {
  static const uuid = Uuid();
  
  static List<SecretField> getTemplate(SecretType type) {
    List<SecretField> create(List<Map<String, dynamic>> items) {
      return items.map((e) => SecretField(
        id: uuid.v4(),
        label: e['label'],
        encryptedValue: '',
        isSecret: e['isSecret'] ?? false,
        isMultiline: e['isMultiline'] ?? false,
      )).toList();
    }

    switch (type) {
      case SecretType.login:
        return create([
          {'label': 'Email / Username'},
          {'label': 'Password', 'isSecret': true},
          {'label': 'Website URL'},
        ]);
      case SecretType.apiKey:
        return create([
          {'label': 'API Key', 'isSecret': true},
          {'label': 'Secret', 'isSecret': true},
          {'label': 'Base URL'},
        ]);
      case SecretType.database:
        return create([
          {'label': 'Host'},
          {'label': 'Port'},
          {'label': 'Database Name'},
          {'label': 'Username'},
          {'label': 'Password', 'isSecret': true},
        ]);
      case SecretType.sshKey:
        return create([
          {'label': 'Host'},
          {'label': 'Username'},
          {'label': 'Private Key', 'isSecret': true, 'isMultiline': true},
          {'label': 'Passphrase', 'isSecret': true},
        ]);
      case SecretType.creditCard:
        return create([
          {'label': 'Card Number', 'isSecret': true},
          {'label': 'Expiry (MM/YY)'},
          {'label': 'CVV', 'isSecret': true},
          {'label': 'Holder Name'},
        ]);
      case SecretType.wifi:
        return create([
          {'label': 'SSID'},
          {'label': 'Password', 'isSecret': true},
        ]);
      case SecretType.note:
        return create([
          {'label': 'Notes', 'isMultiline': true},
        ]);
      case SecretType.custom:
        return [];
    }
  }
}
