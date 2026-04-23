// crypto.js — AES-SIC (Counter mode) + PKCS7 unpadding, matching Flutter's encrypt ^5 package
//
// Flutter EncryptionService:
//   encrypt.Encrypter(encrypt.AES(key))
//   → mode = AESMode.sic (default)     → WebCrypto: AES-CTR, counter=IV, length=128
//   → padding = 'PKCS7' (default)      → must strip PKCS7 padding after decrypt
//
// Key derivation: sha256(utf8(masterPassword)) → 32-byte raw key
// Encrypted format: "base64(iv_16bytes):base64(ciphertext_with_pkcs7)"

const CryptoHelper = {

  /**
   * Derive AES-CTR key from master password.
   * Matches Flutter: sha256.convert(utf8.encode(password)) → Key(bytes)
   */
  async deriveKey(masterPassword) {
    const enc = new TextEncoder();
    const hashBuffer = await crypto.subtle.digest('SHA-256', enc.encode(masterPassword));
    return crypto.subtle.importKey(
      'raw',
      hashBuffer,
      { name: 'AES-CTR' },
      false,
      ['decrypt']
    );
  },

  /**
   * Remove PKCS7 padding from a Uint8Array.
   * Flutter's encrypt package applies PKCS7 padding even in SIC/CTR mode
   * because SICBlockCipher is a BlockCipher and PaddedBlockCipher wraps it.
   *
   * PKCS7: last N bytes each have value N (1 ≤ N ≤ 16)
   */
  removePKCS7Padding(bytes) {
    const len = bytes.length;
    if (len === 0) return bytes;

    const padLen = bytes[len - 1];

    // Basic sanity check
    if (padLen < 1 || padLen > 16 || padLen > len) return bytes;

    // Verify all padding bytes are equal to padLen
    for (let i = len - padLen; i < len; i++) {
      if (bytes[i] !== padLen) return bytes; // not valid PKCS7, return as-is
    }

    return bytes.slice(0, len - padLen);
  },

  /**
   * Decrypt a single field value and strip PKCS7 padding.
   * Format from Flutter encryptValue(): "base64(iv):base64(ciphertext)"
   *
   * AES-CTR params:
   *   counter = IV bytes (16 bytes, initial counter value)
   *   length  = 128 → full 128-bit block is the counter (matches PointyCastle SIC)
   */
  async decryptField(encryptedValue, cryptoKey) {
    try {
      const parts = encryptedValue.split(':');
      if (parts.length !== 2) {
        console.warn('[SecretVault] Unexpected encrypted format (parts:', parts.length, ')');
        return null;
      }

      const counter    = Uint8Array.from(atob(parts[0]), c => c.charCodeAt(0));
      const ciphertext = Uint8Array.from(atob(parts[1]), c => c.charCodeAt(0));

      const decryptedBuffer = await crypto.subtle.decrypt(
        { name: 'AES-CTR', counter, length: 128 },
        cryptoKey,
        ciphertext
      );

      // Strip PKCS7 padding that Flutter's encrypt package adds
      const raw       = new Uint8Array(decryptedBuffer);
      const unpadded  = this.removePKCS7Padding(raw);

      return new TextDecoder().decode(unpadded);
    } catch (e) {
      console.error('[SecretVault] Decrypt failed:', e);
      return null;
    }
  },

  /**
   * Verify master password against the stored verification token.
   * Token is Flutter's encryption of the string 'secret_vault_verified'.
   */
  async verifyPassword(encryptedToken, masterPassword) {
    try {
      if (!encryptedToken) {
        console.error('[SecretVault] verifyPassword: no token stored');
        return false;
      }
      const key    = await this.deriveKey(masterPassword);
      const result = await this.decryptField(encryptedToken, key);
      console.log('[SecretVault] Token decrypted to:', JSON.stringify(result));
      return result === 'secret_vault_verified';
    } catch (e) {
      console.error('[SecretVault] verifyPassword error:', e);
      return false;
    }
  },

  /**
   * Decrypt the entire vault.
   * @param {Array} encryptedVault 
   * @param {CryptoKey} key 
   */
  async decryptVault(encryptedVault, key) {
    const secrets = [];
    for (const item of encryptedVault) {
      const fields = {};
      for (const f of item.fields) {
        const val = await this.decryptField(f.encryptedValue, key);
        if (val !== null) {
          fields[f.label.toLowerCase()] = val;
        }
      }
      secrets.push({
        id: item.id,
        title: item.title,
        type: item.type,
        projectName: item.projectName || '',
        fields,
        tags: item.tags || [],
      });
    }
    return secrets;
  }
};
