import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
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
  final int _port = 42042;
  
  bool _isEnabled = false;
  String? _pairingCode;
  String? _pairedKey; // The shared secret once paired
  
  final _requestController = StreamController<ExtensionRequest>.broadcast();
  Stream<ExtensionRequest> get requests => _requestController.stream;

  ExtensionService(this._storageService, this._encryptionService);

  bool get isEnabled => _isEnabled;
  String? get pairingCode => _pairingCode;
  bool get isPaired => _pairedKey != null;

  Future<void> start() async {
    if (_server != null) return;
    
    _isEnabled = _storageService.settingsBox.get('extension_enabled', defaultValue: false);
    if (!_isEnabled) return;

    _pairedKey = _storageService.settingsBox.get('extension_paired_key');

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

  String generatePairingCode() {
    final random = Random();
    _pairingCode = (100000 + random.nextInt(900000)).toString();
    // Pairing code expires in 5 minutes
    Timer(const Duration(minutes: 5), () {
      _pairingCode = null;
      notifyListeners();
    });
    notifyListeners();
    return _pairingCode!;
  }

  void revokePairing() {
    _pairedKey = null;
    _storageService.settingsBox.delete('extension_paired_key');
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
        _sendResponse(request, {'status': 'ok', 'paired': isPaired});
      } else if (path == '/pair') {
        await _handlePairing(request);
      } else if (path == '/secrets') {
        await _handleGetSecrets(request);
      } else if (path == '/get-credential') {
        await _handleGetCredential(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } catch (e) {
      _sendResponse(request, {'error': 'Internal server error'}, status: HttpStatus.internalServerError);
    }
  }

  Future<void> _handlePairing(HttpRequest request) async {
    if (request.method != 'POST') {
      _sendResponse(request, {'error': 'Method not allowed'}, status: HttpStatus.methodNotAllowed);
      return;
    }

    final body = await _parseBody(request);
    final code = body['code'];

    if (_pairingCode != null && code == _pairingCode) {
      _pairedKey = _encryptionService.generateRandomKey(32);
      await _storageService.settingsBox.put('extension_paired_key', _pairedKey);
      _pairingCode = null; // Use once
      _sendResponse(request, {'status': 'success', 'key': _pairedKey});
    } else {
      _sendResponse(request, {'status': 'error', 'message': 'Invalid or expired code'}, status: HttpStatus.unauthorized);
    }
  }

  Future<void> _handleGetSecrets(HttpRequest request) async {
    if (!await _authenticate(request)) return;

    final query = request.uri.queryParameters['q']?.toLowerCase() ?? '';
    final allSecrets = _storageService.getAllSecrets();
    
    // Simple domain matching for the extension
    final matches = allSecrets.where((s) {
      final title = s.title.toLowerCase();
      return title.contains(query);
    }).map((s) => {
      'id': s.id,
      'title': s.title,
      'type': s.type.name,
    }).toList();

    _sendResponse(request, {'secrets': matches});
  }

  Future<void> _handleGetCredential(HttpRequest request) async {
    if (!await _authenticate(request)) return;

    final body = await _parseBody(request);
    final secretId = body['id'];
    final origin = body['origin'] ?? 'Unknown';

    final secret = _storageService.secretsBox.get(secretId);
    if (secret == null) {
      _sendResponse(request, {'error': 'Secret not found'}, status: HttpStatus.notFound);
      return;
    }

    // Request approval from user
    final completer = Completer<bool>();
    _requestController.add(ExtensionRequest(
      id: secretId,
      origin: origin,
      secretTitle: secret.title,
      completer: completer,
    ));

    final approved = await completer.future;

    if (approved) {
      if (!_encryptionService.isInitialized) {
        _sendResponse(request, {'status': 'error', 'message': 'Vault is locked'}, status: HttpStatus.forbidden);
        return;
      }

      final data = <String, String>{};
      for (final field in secret.fields) {
        try {
          data[field.label.toLowerCase()] = _encryptionService.decryptValue(field.encryptedValue);
        } catch (_) {}
      }
      
      if (data.isEmpty) {
        _sendResponse(request, {'status': 'error', 'message': 'No data found in secret'}, status: HttpStatus.notFound);
        return;
      }

      _sendResponse(request, {'status': 'approved', 'data': data});
    } else {
      _sendResponse(request, {'status': 'denied'}, status: HttpStatus.forbidden);
    }
  }

  Future<bool> _authenticate(HttpRequest request) async {
    final auth = request.headers.value('Authorization');
    if (auth != null && auth == 'Bearer $_pairedKey') {
      return true;
    }
    _sendResponse(request, {'error': 'Unauthorized'}, status: HttpStatus.unauthorized);
    return false;
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
