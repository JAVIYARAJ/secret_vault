import 'package:flutter_bloc/flutter_bloc.dart';
import 'secret_event.dart';
import 'package:uuid/uuid.dart';
import '../../models/secret.dart';
import '../../services/storage_service.dart';
import '../../services/encryption_service.dart';
import '../../services/clipboard_service.dart';
import 'secret_state.dart';
import '../audit/audit_bloc.dart';
import '../audit/audit_event.dart';
import '../../models/audit_entry.dart';

class SecretBloc extends Bloc<SecretEvent, SecretState> {
  final StorageService _storageService;
  final EncryptionService _encryptionService;
  final AuditBloc _auditBloc;
  final ClipboardService _clipboardService;
  final _uuid = const Uuid();
  
  String? _currentProjectId;
  List<Secret> _allProjectSecrets = [];

  SecretBloc(
    this._storageService, 
    this._encryptionService, 
    this._auditBloc,
    this._clipboardService,
  ) : super(SecretInitial()) {
    on<LoadSecrets>(_onLoadSecrets);
    on<AddSecret>(_onAddSecret);
    on<UpdateSecret>(_onUpdateSecret);
    on<DeleteSecret>(_onDeleteSecret);
    on<ToggleRevealField>(_onToggleRevealField);
    on<CopyField>(_onCopyField);
    on<AddCustomField>(_onAddCustomField);
    on<RemoveCustomField>(_onRemoveCustomField);
    on<SearchSecrets>(_onSearchSecrets);
    on<FilterByType>(_onFilterByType);
    on<LogSecretAccess>(_onLogSecretAccess);
    on<SetExpandedSecret>(_onSetExpandedSecret);
    on<ReorderSecrets>(_onReorderSecrets);
    on<MoveSecretToProject>(_onMoveSecretToProject);
    on<ToggleFavourite>(_onToggleFavourite);
  }

  Future<void> _onToggleFavourite(ToggleFavourite event, Emitter<SecretState> emit) async {
    final currentState = state;
    if (currentState is SecretLoaded) {
      final index = _allProjectSecrets.indexWhere((s) => s.id == event.secretId);
      if (index != -1) {
        final updatedSecret = _allProjectSecrets[index].copyWith(
          isFavourite: !_allProjectSecrets[index].isFavourite,
        );
        
        // Update ground truth
        _allProjectSecrets[index] = updatedSecret;
        
        // Emit immediately with new list reference and fresh nonce for reliable UI refresh
        final filtered = _filterSecrets(_allProjectSecrets, currentState.searchQuery, currentState.filterType);
        emit(currentState.copyWith(
          secrets: List.of(filtered),
          expansionNonce: currentState.expansionNonce + 1,
        ));
        
        // Persist in background
        await _storageService.saveSecret(updatedSecret);
        
        _logAudit(
          secretId: updatedSecret.id,
          secretTitle: updatedSecret.title,
          action: AuditAction.edited,
        );
      }
    }
  }

  Future<void> _onReorderSecrets(ReorderSecrets event, Emitter<SecretState> emit) async {
    final currentState = state;
    if (currentState is SecretLoaded) {
      // 1. Get visible unpinned items (filtered)
      final unpinnedVisible = currentState.unpinned;
      if (event.oldIndex < 0 || event.oldIndex >= unpinnedVisible.length) return;
      if (event.newIndex < 0 || event.newIndex >= unpinnedVisible.length) return;

      // 2. Identify source and target secrets
      final secretToMove = unpinnedVisible[event.oldIndex];
      final targetSecret = unpinnedVisible[event.newIndex];

      // 3. Update the full source of truth (_allProjectSecrets)
      final oldAllIndex = _allProjectSecrets.indexWhere((s) => s.id == secretToMove.id);
      final newAllIndex = _allProjectSecrets.indexWhere((s) => s.id == targetSecret.id);

      if (oldAllIndex != -1 && newAllIndex != -1) {
        final s = _allProjectSecrets.removeAt(oldAllIndex);
        _allProjectSecrets.insert(newAllIndex, s);
        
        // 4. Update sort orders for persistence based on the NEW full list order
        for (int i = 0; i < _allProjectSecrets.length; i++) {
           if (_allProjectSecrets[i].sortOrder != i) {
             _allProjectSecrets[i] = _allProjectSecrets[i].copyWith(sortOrder: i);
             _storageService.saveSecret(_allProjectSecrets[i]);
           }
        }
        
        // 5. Re-apply current filters to maintain visibility
        final filtered = _filterSecrets(_allProjectSecrets, currentState.searchQuery, currentState.filterType);
        emit(currentState.copyWith(secrets: filtered));
      }
    }
  }

  Future<void> _onMoveSecretToProject(MoveSecretToProject event, Emitter<SecretState> emit) async {
    try {
      final secret = _storageService.secretsBox.get(event.secretId);
      if (secret == null) return;

      // Update project ID and reset favorite status if cross-project moves shouldn't keep it?
      // Usually better to keep it.
      secret.projectId = event.toProjectId;
      
      // Find the last sortOrder in the target project
      final targetSecrets = _storageService.getSecrets(event.toProjectId);
      secret.sortOrder = targetSecrets.length;
      
      await _storageService.saveSecret(secret);

      // Reload secrets for the originating project reliably
      if (_currentProjectId != null) {
        add(LoadSecrets(_currentProjectId!));
      }
      
      _logAudit(
        secretId: secret.id,
        secretTitle: secret.title,
        action: AuditAction.edited,
      );
    } catch (_) {}
  }

  void _onSetExpandedSecret(SetExpandedSecret event, Emitter<SecretState> emit) {
    if (state is SecretLoaded) {
      final currentState = state as SecretLoaded;
      emit(currentState.copyWith(
        expandedId: event.secretId,
        expansionNonce: currentState.expansionNonce + 1,
      ));
    }
  }

  void _onLogSecretAccess(LogSecretAccess event, Emitter<SecretState> emit) {
    try {
      final secret = _allProjectSecrets.firstWhere((s) => s.id == event.secretId);
      _logAudit(secretId: secret.id, secretTitle: secret.title, action: AuditAction.accessed);
    } catch (_) {}
  }

  void _onLoadSecrets(LoadSecrets event, Emitter<SecretState> emit) {
    try {
      int newNonce = 0;
      if (state is SecretLoaded) {
        newNonce = (state as SecretLoaded).expansionNonce + 1;
      }

      // If switching projects, show loading. If same project, just update.
      if (_currentProjectId != event.projectId) {
        emit(SecretLoading());
        _currentProjectId = event.projectId;
      }

      _allProjectSecrets = _storageService.getSecrets(event.projectId);
      emit(SecretLoaded(
        secrets: _allProjectSecrets,
        typeCounts: _getTypeCounts(_allProjectSecrets),
        expandedId: event.initialExpandedId,
        expansionNonce: newNonce,
      ));
    } catch (e) {
      emit(SecretError('Failed to load secrets: ${e.toString()}'));
    }
  }

  void _onFilterByType(FilterByType event, Emitter<SecretState> emit) {
    if (state is SecretLoaded) {
      final currentState = state as SecretLoaded;
      final filtered = _filterSecrets(_allProjectSecrets, currentState.searchQuery, event.type);
      emit(currentState.copyWith(
        filterType: event.type, 
        secrets: filtered,
        clearFilter: event.type == null,
        typeCounts: _getTypeCounts(_allProjectSecrets),
      ));
    }
  }

  void _onAddSecret(AddSecret event, Emitter<SecretState> emit) async {
    if (_currentProjectId == null) return;
    
    final currentState = state;
    try {
      final now = DateTime.now();
      
      final encryptedFields = event.fields.map((f) => f.copyWith(
        encryptedValue: _encryptionService.encryptValue(f.encryptedValue),
      )).toList();
      
      final newSecret = Secret(
        id: _uuid.v4(),
        projectId: event.projectId,
        title: event.title,
        typeIndex: event.type.index,
        fields: encryptedFields,
        note: event.note,
        tags: event.tags,
        createdAt: now,
        updatedAt: now,
      );
      
      await _storageService.saveSecret(newSecret);
      _logAudit(secretId: newSecret.id, secretTitle: newSecret.title, action: AuditAction.created);
      
      _allProjectSecrets = _storageService.getSecrets(_currentProjectId!);
      
      if (currentState is SecretLoaded) {
        final filteredSecrets = _filterSecrets(_allProjectSecrets, currentState.searchQuery, currentState.filterType);
        emit(currentState.copyWith(
          secrets: filteredSecrets,
          typeCounts: _getTypeCounts(_allProjectSecrets),
        ));
      } else {
        emit(SecretLoaded(
          secrets: _allProjectSecrets,
          typeCounts: _getTypeCounts(_allProjectSecrets),
        ));
      }
    } catch (e) {
      emit(SecretError('Failed to add secret: ${e.toString()}'));
    }
  }

  void _onUpdateSecret(UpdateSecret event, Emitter<SecretState> emit) async {
    if (_currentProjectId == null) return;
    final currentState = state;
    
    try {
      final encryptedFields = event.secret.fields.map((f) => f.copyWith(
        encryptedValue: _encryptionService.encryptValue(f.encryptedValue),
      )).toList();

      final updatedSecret = event.secret.copyWith(
        fields: encryptedFields, 
        updatedAt: DateTime.now()
      );
      
      final oldSecret = _allProjectSecrets.firstWhere((s) => s.id == event.secret.id);
      final changes = _compareSecrets(oldSecret, updatedSecret);
      
      await _storageService.saveSecret(updatedSecret);
      _logAudit(
        secretId: updatedSecret.id, 
        secretTitle: updatedSecret.title, 
        action: AuditAction.edited,
        metadata: changes,
      );
      
      _allProjectSecrets = _storageService.getSecrets(_currentProjectId!);
      
      if (currentState is SecretLoaded) {
        final filtered = _filterSecrets(_allProjectSecrets, currentState.searchQuery, currentState.filterType);
        emit(currentState.copyWith(
          secrets: filtered,
          typeCounts: _getTypeCounts(_allProjectSecrets),
        ));
      }
    } catch (e) {
      emit(SecretError('Failed to update secret: ${e.toString()}'));
    }
  }

  void _onDeleteSecret(DeleteSecret event, Emitter<SecretState> emit) async {
    if (_currentProjectId == null) return;
    final currentState = state;
    
    try {
      final secret = _allProjectSecrets.firstWhere((s) => s.id == event.id);
      await _storageService.deleteSecret(event.id);
      _logAudit(secretId: secret.id, secretTitle: secret.title, action: AuditAction.deleted);
      
      _allProjectSecrets = _storageService.getSecrets(_currentProjectId!);
      
      if (currentState is SecretLoaded) {
         final filtered = _filterSecrets(_allProjectSecrets, currentState.searchQuery, currentState.filterType);
         emit(currentState.copyWith(
           secrets: filtered,
           typeCounts: _getTypeCounts(_allProjectSecrets),
         ));
      }
    } catch (e) {
       emit(SecretError('Failed to delete secret: ${e.toString()}'));
    }
  }

  void _onToggleRevealField(ToggleRevealField event, Emitter<SecretState> emit) {
    if (state is SecretLoaded) {
      final currentState = state as SecretLoaded;
      final newRevealed = Set<String>.from(currentState.revealedIds);
      final isRevealing = !newRevealed.contains(event.fieldId);
      
      if (isRevealing) {
        newRevealed.add(event.fieldId);
        try {
          Secret? secret;
          try {
            secret = _allProjectSecrets.firstWhere((s) => s.id == event.secretId);
          } catch (_) {
            // Secret might be from another project (cross-project search)
            secret = _storageService.secretsBox.get(event.secretId);
          }
          
          if (secret != null) {
            final field = secret.fields.firstWhere((f) => f.id == event.fieldId);
            _logAudit(
              secretId: secret.id, 
              secretTitle: secret.title, 
              action: AuditAction.revealed,
              fieldLabel: field.label,
            );
          }
        } catch (_) {}
      } else {
        newRevealed.remove(event.fieldId);
      }
      emit(currentState.copyWith(revealedIds: newRevealed));
    }
  }

  void _onCopyField(CopyField event, Emitter<SecretState> emit) async {
    if (state is SecretLoaded) {
      Secret? secret;
      try {
        secret = _allProjectSecrets.firstWhere((s) => s.id == event.secretId);
      } catch (_) {
        secret = _storageService.secretsBox.get(event.secretId);
      }

      if (secret != null) {
        try {
          final field = secret.fields.firstWhere((f) => f.id == event.fieldId);
          final decrypted = _encryptionService.decryptValue(field.encryptedValue);
          await _clipboardService.copyWithAutoClear(decrypted);
          
          _logAudit(
            secretId: secret.id, 
            secretTitle: secret.title, 
            action: AuditAction.copied,
            fieldLabel: field.label,
          );
        } catch (e) {
          // error decrypting or copying
        }
      }
    }
  }

  void _onAddCustomField(AddCustomField event, Emitter<SecretState> emit) async {
    if (state is SecretLoaded) {
      final secret = _allProjectSecrets.firstWhere((s) => s.id == event.secretId);
      final newField = SecretField(
        id: _uuid.v4(),
        label: 'New Field',
        encryptedValue: _encryptionService.encryptValue(''),
        isSecret: false,
      );
      
      final updatedFields = List<SecretField>.from(secret.fields)..add(newField);
      final updatedSecret = secret.copyWith(
        fields: updatedFields,
        updatedAt: DateTime.now(),
      );
      
      await _storageService.saveSecret(updatedSecret);
      _allProjectSecrets = _storageService.getSecrets(_currentProjectId!);
      
      final currentState = state as SecretLoaded;
      final filtered = _filterSecrets(_allProjectSecrets, currentState.searchQuery, currentState.filterType);
      emit(currentState.copyWith(
        secrets: filtered,
        typeCounts: _getTypeCounts(_allProjectSecrets),
      ));
    }
  }

  void _onRemoveCustomField(RemoveCustomField event, Emitter<SecretState> emit) async {
    if (state is SecretLoaded) {
      final secret = _allProjectSecrets.firstWhere((s) => s.id == event.secretId);
      final updatedFields = List<SecretField>.from(secret.fields)
        ..removeWhere((f) => f.id == event.fieldId);
        
      final updatedSecret = secret.copyWith(
        fields: updatedFields,
        updatedAt: DateTime.now(),
      );
      
      await _storageService.saveSecret(updatedSecret);
      _allProjectSecrets = _storageService.getSecrets(_currentProjectId!);
      
      final currentState = state as SecretLoaded;
      final filtered = _filterSecrets(_allProjectSecrets, currentState.searchQuery, currentState.filterType);
      emit(currentState.copyWith(
        secrets: filtered,
        typeCounts: _getTypeCounts(_allProjectSecrets),
      ));
    }
  }

  void _onSearchSecrets(SearchSecrets event, Emitter<SecretState> emit) {
    if (state is SecretLoaded) {
      final currentState = state as SecretLoaded;
      final filtered = _filterSecrets(_allProjectSecrets, event.query, currentState.filterType);
      emit(currentState.copyWith(
        searchQuery: event.query, 
        secrets: filtered,
        typeCounts: _getTypeCounts(_allProjectSecrets),
      ));
    }
  }
  
  Map<SecretType, int> _getTypeCounts(List<Secret> source) {
    final Map<SecretType, int> counts = {};
    for (var type in SecretType.values) {
      counts[type] = source.where((s) => s.type == type).length;
    }
    return counts;
  }
  
  List<Secret> _filterSecrets(List<Secret> source, String query, SecretType? type) {
    List<Secret> filtered = source;
    
    // Type filtering
    if (type != null) {
      filtered = filtered.where((s) => s.type == type).toList();
    }
    
    // Search filtering
    if (query.isEmpty) return filtered;
    final q = query.toLowerCase();
    return filtered.where((s) => 
      s.title.toLowerCase().contains(q) || 
      (s.note != null && s.note!.toLowerCase().contains(q)) ||
      (s.tags != null && s.tags!.any((t) => t.toLowerCase().contains(q)))
    ).toList();
  }

  void _logAudit({
    required String secretId,
    required String secretTitle,
    required AuditAction action,
    String? fieldLabel,
    String? metadata,
  }) {
    if (_currentProjectId == null) return;
    
    final project = _storageService.projectsBox.get(_currentProjectId);
    if (project == null) return;

    _auditBloc.add(LogAuditEntry(
      projectId: _currentProjectId!,
      projectName: project.name,
      secretId: secretId,
      secretTitle: secretTitle,
      action: action,
      fieldLabel: fieldLabel,
      metadata: metadata,
    ));
  }

  String _compareSecrets(Secret oldS, Secret newS) {
    List<String> changes = [];
    if (oldS.title != newS.title) {
      changes.add('Title: "${oldS.title}" → "${newS.title}"');
    }
    if (oldS.note != newS.note) {
      changes.add('Note: "${oldS.note ?? ''}" → "${newS.note ?? ''}"');
    }
    if (oldS.typeIndex != newS.typeIndex) {
      changes.add('Type changed: ${_labelForType(oldS.type)} → ${_labelForType(newS.type)}');
    }
    
    // Compare tags
    final oldTags = (oldS.tags ?? []).join(', ');
    final newTags = (newS.tags ?? []).join(', ');
    if (oldTags != newTags) {
      changes.add('Tags: "[$oldTags]" → "[$newTags]"');
    }

    // Compare fields
    if (oldS.fields.length != newS.fields.length) {
      changes.add('Fields: ${oldS.fields.length} items → ${newS.fields.length} items');
    } else {
      for (int i = 0; i < oldS.fields.length; i++) {
        final f1 = oldS.fields[i];
        final f2 = newS.fields[i];
        if (f1.label != f2.label) {
          changes.add('Field label: "${f1.label}" → "${f2.label}"');
        }
        if (f1.encryptedValue != f2.encryptedValue) {
          changes.add('Value updated for "${f2.label}"');
        }
      }
    }
    
    return changes.isEmpty ? 'Manual re-save' : changes.join('\n');
  }

  String _labelForType(SecretType type) {
    switch (type) {
      case SecretType.login: return 'Login';
      case SecretType.apiKey: return 'API Key';
      case SecretType.database: return 'Database';
      case SecretType.sshKey: return 'SSH Key';
      case SecretType.creditCard: return 'Credit Card';
      case SecretType.wifi: return 'WiFi';
      case SecretType.note: return 'Note';
      case SecretType.custom: return 'Custom';
    }
  }
}
