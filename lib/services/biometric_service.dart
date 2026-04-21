import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _passwordKey = 'vault_master_password';

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Scan your fingerprint to unlock Secret Vault',
        persistAcrossBackgrounding: true,
        biometricOnly: true,
      );
    } catch (e) {
      return false;
    }
  }

  Future<void> saveMasterPassword(String password) async {
    try {
      await _secureStorage.write(key: _passwordKey, value: password);
    } catch (e) {
      // Ignore if secure storage is not supported/configured properly
    }
  }

  Future<String?> getStoredMasterPassword() async {
    try {
      return await _secureStorage.read(key: _passwordKey);
    } catch (e) {
      return null;
    }
  }
  
  Future<void> clearMasterPassword() async {
    try {
      await _secureStorage.delete(key: _passwordKey);
    } catch (e) {
      // Ignore
    }
  }
}
