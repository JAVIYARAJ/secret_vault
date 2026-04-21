import 'package:flutter/material.dart';
import '../services/parsers/base_parser.dart';
import '../models/secret.dart';

class ImportPreviewTable extends StatelessWidget {
  final List<ImportedSecret> items;
  final void Function(int index) onToggle;

  const ImportPreviewTable({
    super.key,
    required this.items,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: DataTable(
        columnSpacing: 16,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 56,
        columns: const [
          DataColumn(label: Text('')),           // checkbox
          DataColumn(label: Text('Title')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Project / Folder')),
          DataColumn(label: Text('Fields')),
        ],
        rows: List.generate(items.length, (i) {
          final item = items[i];
          return DataRow(
            selected: item.selected,
            cells: [
              // Checkbox
              DataCell(Checkbox(
                value: item.selected,
                onChanged: (_) => onToggle(i),
              )),
              // Title
              DataCell(
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                onTap: () => onToggle(i),
              ),
              // Type badge
              DataCell(_TypeBadge(type: item.type)),
              // Project hint
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_outlined,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        item.projectHint,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Field count
              DataCell(
                Tooltip(
                  message: item.fields
                      .map((f) => '${f.label}: ${f.isSecret ? "●●●●" : f.plaintextValue.substring(0, f.plaintextValue.length.clamp(0, 20))}')
                      .join('\n'),
                  child: Text(
                    '${item.fields.length} field${item.fields.length != 1 ? "s" : ""}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final SecretType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      SecretType.login      => ('Login',   Colors.blue),
      SecretType.apiKey     => ('API Key', Colors.purple),
      SecretType.database   => ('Database',Colors.orange),
      SecretType.sshKey     => ('SSH',     Colors.teal),
      SecretType.wifi       => ('WiFi',    Colors.green),
      SecretType.creditCard => ('Card',    Colors.pink),
      SecretType.note       => ('Note',    Colors.grey),
      SecretType.custom     => ('Custom',  Colors.brown),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10,
            color: color.shade700,
            fontWeight: FontWeight.w500),
      ),
    );
  }
}
