# Secret Vault Encryption Guide

This document explains the security architecture and the encryption/decryption flow used in the Secret Vault application to protect sensitive user data.

## 🔒 Security Overview
Secret Vault uses **AES-256** encryption to secure all secrets stored on the device. It follows a "Zero-Knowledge" architecture, meaning the application never stores your actual Master Password or the raw encryption key on the disk.

## 🗝️ Key Derivation
The encryption key is derived from the **Master Password** provided during the vault unlock process.

1. **Hashing**: The Master Password string is hashed using **SHA-256**.
2. **Key Generation**: The resulting 256-bit (32-byte) digest is used directly as the AES encryption key.
3. **Volatility**: The key is only held in memory (`EncryptionService`) while the application is unlocked. It is wiped immediately upon auto-lock or manual logout.

## 📦 Encryption Flow
Every sensitive field (e.g., password, API key, secure note) is encrypted individually before being saved to the local Hive database.

| Step | Action | Description |
| :--- | :--- | :--- |
| 1 | **IV Generation** | A unique, 16-byte random **Initialization Vector (IV)** is generated using a secure random generator. |
| 2 | **AES Encryption** | The plain text value is encrypted using **AES-256 (SIC/CTR mode)** with the derived Key and the unique IV. |
| 3 | **Serialization** | The IV and the Encrypted Data are converted to Base64 and joined with a colon. |
| 4 | **Storage** | The string `base64(iv):base64(encrypted)` is saved to the `secretsBox`. |

**Why use a unique IV?**  
Using a unique IV for every field ensures that even if two secrets have the same value (e.g., two accounts sharing the same password), their encrypted representations in the database will be completely different.

## 👁️ Decryption Flow
When a user requests to view a secret (by clicking the reveal icon), the following occurs:

1. **Fetch**: The encrypted string is retrieved from the `secretsBox`.
2. **Parsing**: The string is split by the `:` delimiter into the `iv` and `encryptedValue`.
3. **Decryption**: The `EncryptionService` uses the **in-memory Key** and the extracted **IV** to decrypt the payload.
4. **Presentation**: The resulting plain text is passed to the UI for display.

## 💻 Implementation Details
The core logic resides in:
*   **Service**: `lib/services/encryption_service.dart`
*   **Encrypter**: Uses the `encrypt` package for Dart.
*   **Mode**: AES-256 with Random IVs.

## 🚨 Security Guarantees
*   **Data at Rest**: Even if the local `.hive` files are stolen, the internal data is unreadable without the Master Password.
*   **Collision Resistance**: Identical passwords result in unique ciphertext.
*   **Zero Storage**: No plain-text sensitive data ever touches the persistent storage.

---
*Note: This documentation is intended for developers maintaining the Secret Vault codebase.*
