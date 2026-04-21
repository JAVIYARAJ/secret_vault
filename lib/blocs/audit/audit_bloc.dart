import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'audit_event.dart';
import 'audit_state.dart';
import '../../models/audit_entry.dart';

class AuditBloc extends Bloc<AuditEvent, AuditState> {
  static const _boxName = 'audit_log';
  final _uuid = const Uuid();

  AuditBloc() : super(AuditInitial()) {
    on<LogAuditEntry>(_onLog);
    on<LoadAuditLog>(_onLoad);
    on<ClearAuditLog>(_onClear);
    on<ExportAuditLog>(_onExport);
  }

  Box<AuditEntry> get _box => Hive.box<AuditEntry>(_boxName);

  Future<void> _onLog(LogAuditEntry e, Emitter<AuditState> emit) async {
    final entry = AuditEntry()
      ..id = _uuid.v4()
      ..projectId = e.projectId
      ..projectName = e.projectName
      ..secretId = e.secretId
      ..secretTitle = e.secretTitle
      ..actionIndex = e.action.index
      ..timestamp = DateTime.now()
      ..fieldLabel = e.fieldLabel
      ..metadata = e.metadata;
    
    await _box.put(entry.id, entry);
    
    // keep max 1000 entries to avoid unbounded growth
    if (_box.length > 1000) {
      final values = _box.values.toList();
      values.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final oldestCount = _box.length - 1000;
      final keysToDelete = values.take(oldestCount).map((e) => e.id).toList();
      await _box.deleteAll(keysToDelete);
    }
  }

  Future<void> _onLoad(LoadAuditLog e, Emitter<AuditState> emit) async {
    emit(AuditLoading());
    try {
      var entries = _box.values.toList();
      if (e.projectId != null) {
        entries = entries.where((x) => x.projectId == e.projectId).toList();
      }
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      emit(AuditLoaded(entries));
    } catch (err) {
      emit(AuditError(err.toString()));
    }
  }

  Future<void> _onClear(ClearAuditLog e, Emitter<AuditState> emit) async {
    if (e.projectId == null) {
      await _box.clear();
    } else {
      final keys = _box.values
          .where((x) => x.projectId == e.projectId)
          .map((x) => x.id)
          .toList();
      await _box.deleteAll(keys);
    }
    add(LoadAuditLog(projectId: e.projectId));
  }

  Future<void> _onExport(ExportAuditLog e, Emitter<AuditState> emit) async {
    var entries = _box.values.toList();
    if (e.projectId != null) {
      entries = entries.where((x) => x.projectId == e.projectId).toList();
    }
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final buffer = StringBuffer();
    buffer.writeln('timestamp,project,secret,action,field,details');
    for (final entry in entries) {
      buffer.writeln(
        '${entry.timestamp.toIso8601String()},'
        '"${entry.projectName}","${entry.secretTitle}",'
        '${entry.action.name},"${entry.fieldLabel ?? ""}",'
        '"${entry.metadata ?? ""}"',
      );
    }

    final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/secret_vault_audit_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buffer.toString());
  }
}
