// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'secret.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SecretFieldAdapter extends TypeAdapter<SecretField> {
  @override
  final int typeId = 2;

  @override
  SecretField read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SecretField(
      id: fields[0] as String,
      label: fields[1] as String,
      encryptedValue: fields[2] as String,
      isSecret: fields[3] as bool,
      isMultiline: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SecretField obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.encryptedValue)
      ..writeByte(3)
      ..write(obj.isSecret)
      ..writeByte(4)
      ..write(obj.isMultiline);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecretFieldAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SecretAdapter extends TypeAdapter<Secret> {
  @override
  final int typeId = 1;

  @override
  Secret read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Secret(
      id: fields[0] as String,
      projectId: fields[1] as String,
      title: fields[2] as String,
      typeIndex: fields[3] as int,
      fields: (fields[4] as List).cast<SecretField>(),
      note: fields[5] as String?,
      tags: (fields[6] as List?)?.cast<String>(),
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
      sortOrder: fields[9] as int,
      isFavourite: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Secret obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.typeIndex)
      ..writeByte(4)
      ..write(obj.fields)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.tags)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.sortOrder)
      ..writeByte(10)
      ..write(obj.isFavourite);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecretAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
