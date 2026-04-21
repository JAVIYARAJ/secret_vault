import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../models/secret.dart';
import 'storage_service.dart';
import 'encryption_service.dart';

class ExportService {
  final StorageService _storageService;
  final EncryptionService _encryptionService;

  ExportService(this._storageService, this._encryptionService);

  Future<void> exportProject(String projectId) async {
    final project = _storageService.projectsBox.get(projectId);
    if (project == null) return;
    
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Project to .env',
      fileName: '${project.name.toLowerCase().replaceAll(' ', '_')}.env',
      type: FileType.custom,
      allowedExtensions: ['env'],
    );

    if (result != null) {
      final file = File(result);
      final secrets = _storageService.getSecrets(projectId);
      
      final buffer = StringBuffer();
      for (var secret in secrets) {
        if (secret.note != null && secret.note!.isNotEmpty) {
          buffer.writeln('\n# Secret: ${secret.title} - ${secret.note}');
        } else {
          buffer.writeln('\n# Secret: ${secret.title}');
        }
        for (var field in secret.fields) {
          final decryptedValue = _encryptionService.decryptValue(field.encryptedValue);
          final formattedTitle = secret.title.toUpperCase().replaceAll(' ', '_');
          final formattedField = field.label.toUpperCase().replaceAll(' ', '_').replaceAll('/', '_');
          buffer.writeln('${formattedTitle}_$formattedField="$decryptedValue"');
        }
      }
      
      await file.writeAsString(buffer.toString());
    }
  }

  Future<void> importEnvFile(String filePath, String projectId) async {
    final file = File(filePath);
    if (!await file.exists()) return;
    
    final lines = await file.readAsLines();
    final importedFields = <SecretField>[];
    
    for (var line in lines) {
      if (line.trim().isEmpty || line.startsWith('#')) continue;
      
      final eqIndex = line.indexOf('=');
      if (eqIndex != -1) {
        final key = line.substring(0, eqIndex).trim();
        final value = line.substring(eqIndex + 1).trim();
        
        var cleanValue = value;
        if ((cleanValue.startsWith('"') && cleanValue.endsWith('"')) ||
            (cleanValue.startsWith("'") && cleanValue.endsWith("'"))) {
          cleanValue = cleanValue.substring(1, cleanValue.length - 1);
        }
        
        final encryptedValue = _encryptionService.encryptValue(cleanValue);
        
        importedFields.add(SecretField(
          id: DateTime.now().microsecondsSinceEpoch.toString() + key,
          label: key,
          encryptedValue: encryptedValue,
          isSecret: true,
          isMultiline: cleanValue.contains('\n'),
        ));
      }
    }
    
    if (importedFields.isNotEmpty) {
       final now = DateTime.now();
       final newSecret = Secret(
         id: DateTime.now().millisecondsSinceEpoch.toString(),
         projectId: projectId,
         title: 'Imported Env-${now.millisecondsSinceEpoch}',
         typeIndex: SecretType.custom.index,
         fields: importedFields,
         createdAt: now,
         updatedAt: now,
       );
       await _storageService.saveSecret(newSecret);
    }
  }
}
