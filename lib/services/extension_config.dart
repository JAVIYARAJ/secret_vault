/// extension_config.dart — Secret Vault Extension Configuration (Flutter side)
///
/// All tuneable constants for the browser extension integration.
/// Change values here; no other files need to be modified.
///
/// ── HOW TO CHANGE ──────────────────────────────────────────────────────────
///   1. Edit the value below
///   2. Hot-restart the app (⇧R in terminal or IDE)
///   3. Done — no other Dart files need to change
/// ─────────────────────────────────────────────────────────────────────────────

class ExtensionConfig {
  ExtensionConfig._(); // prevent instantiation

  // ── HTTP Server ─────────────────────────────────────────────────────────────

  /// Port the local HTTP server listens on for extension requests.
  /// Must match SV_CONFIG.DESKTOP_URL in config.js.
  static const int serverPort = 42042;


  // ── Vault Version ────────────────────────────────────────────────────────────

  /// The extension polls /vault-version every [autoSyncInterval] minutes.
  /// This constant is informational — the actual interval is set in config.js.
  /// Keep them in sync if you change one.
  static const Duration autoSyncInterval = Duration(minutes: 30);

  // ── Request Timeouts ─────────────────────────────────────────────────────────

  /// Maximum time to wait for the extension HTTP server to bind on startup.
  static const Duration serverBindTimeout = Duration(seconds: 5);
}
