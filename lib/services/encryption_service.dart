import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionService {
  encrypt.Encrypter? _encrypter;

  void initialize(String masterPassword) {
    var bytes = utf8.encode(masterPassword);
    var digest = sha256.convert(bytes);
    final key = encrypt.Key(Uint8List.fromList(digest.bytes));
    _encrypter = encrypt.Encrypter(encrypt.AES(key));
  }

  void clear() {
    _encrypter = null;
  }

  bool get isInitialized => _encrypter != null;

  String encryptValue(String plainText) {
    if (_encrypter == null) throw Exception("Encrypter not initialized");
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(plainText, iv: iv);
    // Return iv + encrypted data concatenated by ':'
    return '${iv.base64}:${encrypted.base64}';
  }

  String decryptValue(String encryptedWithIv) {
    if (_encrypter == null) throw Exception("Encrypter not initialized");
    final parts = encryptedWithIv.split(':');
    if (parts.length != 2) throw Exception("Invalid encrypted value format");
    
    final iv = encrypt.IV.fromBase64(parts[0]);
    final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
    
    return _encrypter!.decrypt(encrypted, iv: iv);
  }
  
  String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
}
