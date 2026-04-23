import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/secret.dart';
import 'extension_config.dart';
import 'storage_service.dart';
import 'encryption_service.dart';

class ExtensionRequest {
  final String id;
  final String origin;
  final String secretTitle;
  final Completer<bool> completer;

  ExtensionRequest({
    required this.id,
    required this.origin,
    required this.secretTitle,
    required this.completer,
  });
}

class ExtensionService extends ChangeNotifier {
  final StorageService _storageService;
  final EncryptionService _encryptionService;
  
  HttpServer? _server;
  final int _port = ExtensionConfig.serverPort;
  
  bool _isEnabled = false;

  // Increments on every vault change (save/delete) so the extension
  // can detect staleness without downloading the full vault.
  int _vaultVersion = 0;
  int get vaultVersion => _vaultVersion;

  // Called by BLoC after every save/delete to bump the version.
  void markVaultChanged() {
    _vaultVersion++;
    notifyListeners();
  }

  // Legacy: approval request stream (kept for backward compat)
  final _requestController = StreamController<ExtensionRequest>.broadcast();
  Stream<ExtensionRequest> get requests => _requestController.stream;

  ExtensionService(this._storageService, this._encryptionService);

  bool get isEnabled => _isEnabled;

  Future<void> start() async {
    if (_server != null) return;
    
    _isEnabled = _storageService.settingsBox.get('extension_enabled', defaultValue: false);
    if (!_isEnabled) return;


    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
      debugPrint('Extension server listening on port $_port');
      
      _server!.listen((HttpRequest request) {
        _handleRequest(request);
      });
    } catch (e) {
      debugPrint('Failed to start extension server: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> toggle(bool enabled) async {
    _isEnabled = enabled;
    await _storageService.settingsBox.put('extension_enabled', enabled);
    if (enabled) {
      await start();
    } else {
      await stop();
    }
    notifyListeners();
  }


  Future<void> _handleRequest(HttpRequest request) async {
    // Basic CORS
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;
    
    try {
      if (path == '/status') {
        _sendResponse(request, {'status': 'ok'});
      } else if (path == '/export-vault') {
        await _handleExportVault(request);
      } else if (path == '/vault-version') {
        _handleVaultVersion(request);
      } else if (path == '/add-secret') {
        await _handleAddSecret(request);
      } else if (path == '/projects') {
        _handleGetProjects(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } catch (e) {
      _sendResponse(request, {'error': 'Internal server error'}, status: HttpStatus.internalServerError);
    }
  }


  // ── Export vault (new standalone architecture) ────────────────────────────
  //
  // Returns the already-encrypted vault so the extension can decrypt it
  // locally using the master password — no plaintext ever leaves the app.
  Future<void> _handleExportVault(HttpRequest request) async {
    if (!_isEnabled) {
      _sendResponse(request, {'error': 'Extension not enabled'},
          status: HttpStatus.forbidden);
      return;
    }

    if (!_encryptionService.isInitialized) {
      _sendResponse(
        request,
        {'error': 'Vault is locked. Unlock the desktop app first.'},
        status: HttpStatus.forbidden,
      );
      return;
    }

    final allSecrets  = _storageService.getAllSecrets();
    final allProjects = {
      for (final p in _storageService.getProjects()) p.id: p.name
    };

    // Export secrets with their ALREADY-encrypted field values.
    // The extension decrypts them using the master password via WebCrypto.
    final vault = allSecrets.map((s) => {
      'id': s.id,
      'title': s.title,
      'type': s.type.name,
      'projectName': allProjects[s.projectId] ?? 'Unknown',
      'tags': s.tags ?? [],
      'fields': s.fields.map((f) => {
        'label': f.label,
        'isSecret': f.isSecret,
        // Already in "iv_base64:cipher_base64" format from encryptValue()
        'encryptedValue': f.encryptedValue,
      }).toList(),
    }).toList();

    // Verification token: encrypt a known string so the extension can verify
    // the master password before attempting to decrypt every field.
    final verificationToken =
        _encryptionService.encryptValue('secret_vault_verified');

    _sendResponse(request, {
      'vault': vault,
      'verificationToken': verificationToken,
      'vaultVersion': _vaultVersion,   // extension uses this to detect changes
    });
  }

  // ── Add secret from extension ──────────────────────────────────────────
  //
  // Receives { title, username, password } in plaintext from extension.
  // Encrypts and saves it to the local vault.
  Future<void> _handleAddSecret(HttpRequest request) async {
    if (!_isEnabled) {
      _sendResponse(request, {'error': 'Extension not enabled'}, status: HttpStatus.forbidden);
      return;
    }

    if (!_encryptionService.isInitialized) {
      _sendResponse(request, {'error': 'Vault is locked'}, status: HttpStatus.forbidden);
      return;
    }

    if (request.method != 'POST') {
      _sendResponse(request, {'error': 'POST expected'}, status: HttpStatus.methodNotAllowed);
      return;
    }

    final body = await _parseBody(request);
    final title = body['title'] ?? 'Captured Login';
    final user  = body['username'] ?? '';
    final pass  = body['password'] ?? '';
    final existingId = body['existingId'];
    final targetProjectId = body['projectId'];

    if (pass.isEmpty) {
      _sendResponse(request, {'error': 'Password is required'}, status: HttpStatus.badRequest);
      return;
    }

    final now = DateTime.now();

    // ── DUPLICATE & AUTO-UPDATE CHECK (Server-side safety) ──
    final allSecrets = _storageService.getAllSecrets();
    final normalizedTitle = title.toLowerCase().trim().replaceFirst('www.', '');
    final normalizedUser  = user.toLowerCase().trim();
    final normalizedPass  = pass.trim();

    Secret? duplicateMatch;
    Secret? updateMatch;

    for (final s in allSecrets) {
      final sTitle = s.title.toLowerCase().trim().replaceFirst('www.', '');
      if (!sTitle.contains(normalizedTitle) && !normalizedTitle.contains(sTitle)) continue;

      String? sUser;
      String? sPass;
      for (final f in s.fields) {
        final label = f.label.toLowerCase();
        final val = _encryptionService.decryptValue(f.encryptedValue);
        if (label.contains('user') || label.contains('email') || label.contains('login')) sUser = val;
        if (label.contains('password') || label.contains('pass')) sPass = val;
      }

      if (sUser?.toLowerCase().trim() == normalizedUser) {
        if (sPass?.trim() == normalizedPass) {
          duplicateMatch = s;
          break;
        }
        updateMatch = s;
      }
    }

    if (duplicateMatch != null) {
      _sendResponse(request, {'status': 'success', 'id': duplicateMatch.id, 'info': 'Duplicate ignored'});
      return;
    }

    final effectiveExistingId = existingId ?? updateMatch?.id;

    if (effectiveExistingId != null) {
      // ── UPDATE EXISTING ──
      final existingSecret = _storageService.secretsBox.get(effectiveExistingId);
      if (existingSecret != null) {
        final updatedFields = List<SecretField>.from(existingSecret.fields);
        
        // Update password field
        final passIndex = updatedFields.indexWhere((f) => f.label.toLowerCase().contains('pass'));
        if (passIndex != -1) {
          updatedFields[passIndex] = updatedFields[passIndex].copyWith(
            encryptedValue: _encryptionService.encryptValue(pass),
          );
        }

        // Update username if it exists
        if (user.isNotEmpty) {
          final userIndex = updatedFields.indexWhere((f) => 
            f.label.toLowerCase().contains('user') || f.label.toLowerCase().contains('email'));
          if (userIndex != -1) {
            updatedFields[userIndex] = updatedFields[userIndex].copyWith(
              encryptedValue: _encryptionService.encryptValue(user),
            );
          }
        }

        final updatedSecret = existingSecret.copyWith(
          fields: updatedFields,
          updatedAt: now,
        );
        await _storageService.saveSecret(updatedSecret);
        markVaultChanged();
        _sendResponse(request, {'status': 'updated', 'id': existingId});
        debugPrint('[ExtensionService] Updated existing secret: ${updatedSecret.title}');
        return;
      }
    }

    // ── CREATE NEW (Fallback or no existingId) ──
    // Determine target project
    final projects = _storageService.getProjects();
    if (projects.isEmpty) {
      _sendResponse(request, {'error': 'No projects found in desktop app'}, status: HttpStatus.badRequest);
      return;
    }
    
    // Use the provided projectId, or fallback to the first project
    String projectId = targetProjectId ?? projects.first.id;
    // Verify project exists
    if (!projects.any((p) => p.id == projectId)) {
      projectId = projects.first.id;
    }

    final fields = [
      if (user.isNotEmpty)
        SecretField(
          id: const Uuid().v4(),
          label: 'Email / Username',
          encryptedValue: _encryptionService.encryptValue(user),
          isSecret: false,
        ),
      SecretField(
        id: const Uuid().v4(),
        label: 'Password',
        encryptedValue: _encryptionService.encryptValue(pass),
        isSecret: true,
      ),
      SecretField(
        id: const Uuid().v4(),
        label: 'Website URL',
        encryptedValue: _encryptionService.encryptValue(title),
        isSecret: false,
      ),
    ];

    final newSecret = Secret(
      id: const Uuid().v4(),
      projectId: projectId,
      title: title,
      typeIndex: 0, // Login type
      fields: fields,
      createdAt: now,
      updatedAt: now,
    );

    await _storageService.saveSecret(newSecret);
    markVaultChanged(); // Triggers sync and UI refresh

    _sendResponse(request, {'status': 'success', 'id': newSecret.id});
    debugPrint('[ExtensionService] Added new secret: ${newSecret.title}');
  }

  // Lightweight poll endpoint — returns current vault version.
  // Extension background worker calls this every 30 min to check if
  // a full re-sync is needed, without downloading the whole vault.
  void _handleVaultVersion(HttpRequest request) {
    if (!_isEnabled) {
      _sendResponse(request, {'error': 'Extension not enabled'},
          status: HttpStatus.forbidden);
      return;
    }
    _sendResponse(request, {
      'version': _vaultVersion,
      'locked': !_encryptionService.isInitialized,
      'secretCount': _storageService.getAllSecrets().length,
    });
  }

  void _handleGetProjects(HttpRequest request) {
    if (!_isEnabled) {
      _sendResponse(request, {'error': 'Extension not enabled'}, status: HttpStatus.forbidden);
      return;
    }
    final projects = _storageService.getProjects();
    _sendResponse(request, {
      'projects': projects.map((p) => {'id': p.id, 'name': p.name}).toList(),
    });
  }


  void _sendResponse(HttpRequest request, Map<String, dynamic> data, {int status = HttpStatus.ok}) {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    request.response.close();
  }

  Future<Map<String, dynamic>> _parseBody(HttpRequest request) async {
    final content = await utf8.decoder.bind(request).join();
    if (content.isEmpty) return {};
    return jsonDecode(content);
  }
}
