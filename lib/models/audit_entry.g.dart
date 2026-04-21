// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AuditEntryAdapter extends TypeAdapter<AuditEntry> {
  @override
  final int typeId = 4;

  @override
  AuditEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AuditEntry()
      ..id = fields[0] as String
      ..projectId = fields[1] as String
      ..projectName = fields[2] as String
      ..secretId = fields[3] as String
      ..secretTitle = fields[4] as String
      ..actionIndex = fields[5] as int
      ..timestamp = fields[6] as DateTime
      ..fieldLabel = fields[7] as String?
      ..metadata = fields[8] as String?;
  }

  @override
  void write(BinaryWriter writer, AuditEntry obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.projectName)
      ..writeByte(3)
      ..write(obj.secretId)
      ..writeByte(4)
      ..write(obj.secretTitle)
      ..writeByte(5)
      ..write(obj.actionIndex)
      ..writeByte(6)
      ..write(obj.timestamp)
      ..writeByte(7)
      ..write(obj.fieldLabel)
      ..writeByte(8)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AuditActionAdapter extends TypeAdapter<AuditAction> {
  @override
  final int typeId = 3;

  @override
  AuditAction read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AuditAction.accessed;
      case 1:
        return AuditAction.copied;
      case 2:
        return AuditAction.revealed;
      case 3:
        return AuditAction.edited;
      case 4:
        return AuditAction.deleted;
      case 5:
        return AuditAction.created;
      default:
        return AuditAction.accessed;
    }
  }

  @override
  void write(BinaryWriter writer, AuditAction obj) {
    switch (obj) {
      case AuditAction.accessed:
        writer.writeByte(0);
        break;
      case AuditAction.copied:
        writer.writeByte(1);
        break;
      case AuditAction.revealed:
        writer.writeByte(2);
        break;
      case AuditAction.edited:
        writer.writeByte(3);
        break;
      case AuditAction.deleted:
        writer.writeByte(4);
        break;
      case AuditAction.created:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditActionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
