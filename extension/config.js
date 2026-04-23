// ═══════════════════════════════════════════════════════════════════════════
// config.js — Secret Vault Extension Configuration
// ═══════════════════════════════════════════════════════════════════════════
//
// All tuneable constants in one place.
// Referenced by: background.js (via importScripts) and popup.js (via <script>)
//
// ─── HOW TO CHANGE ──────────────────────────────────────────────────────────
//   1. Edit the value here
//   2. Go to chrome://extensions/ → click ↻ Reload on Secret Vault
//   3. Done — no other files need to change
// ════════════════════════════════════════════════════════════════════════════

const SV_CONFIG = Object.freeze({

  // ── Desktop App ────────────────────────────────────────────────────────────
  /** Base URL of the Secret Vault Flutter desktop HTTP server */
  DESKTOP_URL: 'http://localhost:42042',

  // ── Session Security ───────────────────────────────────────────────────────
  /**
   * How long (minutes) the master password is cached in chrome.storage.session.
   * After this, the user must re-enter their password.
   * chrome.storage.session is also cleared automatically when the browser closes.
   */
  SESSION_TIMEOUT_MINUTES: 15,

  // ── Auto-Sync (Background Polling) ─────────────────────────────────────────
  /**
   * How often (minutes) the background worker polls /vault-version on the
   * desktop app to detect changes (adds, edits, deletes).
   * Only does a full re-sync if the version has actually changed.
   * Minimum Chrome allows: 1 minute.
   */
  AUTO_SYNC_INTERVAL_MINUTES: 30,

  /**
   * Timeout (ms) for the lightweight /vault-version poll request.
   * Keep this short — it's just a version number check.
   */
  VERSION_POLL_TIMEOUT_MS: 3_000,

  /**
   * Timeout (ms) for the full /export-vault download request.
   * Can be longer since it downloads the full encrypted vault.
   */
  VAULT_EXPORT_TIMEOUT_MS: 8_000,

  // ── Staleness Warning (Popup UI) ────────────────────────────────────────────
  /**
   * After how many HOURS without a sync to show the amber
   * "vault may be outdated" warning banner in the popup.
   * Set to Infinity to disable the warning entirely.
   */
  STALE_WARNING_THRESHOLD_HOURS: 1,

  // ── UI Timers (Popup) ───────────────────────────────────────────────────────
  /**
   * How long (ms) the sync error banner stays visible before auto-hiding.
   */
  SYNC_ERROR_DISMISS_MS: 6_000,

  /**
   * How long (ms) the fill error banner stays visible before auto-hiding.
   */
  FILL_ERROR_DISMISS_MS: 4_000,

  /**
   * How long (ms) before the ↻ Sync button resets its label after
   * a sync attempt (success or failure).
   */
  SYNC_BTN_RESET_MS: 3_000,

  /**
   * Delay (ms) before popup re-initialises after a successful sync.
   * Gives the user a moment to see the "✓ Synced!" confirmation.
   */
  POST_SYNC_REINIT_DELAY_MS: 600,

  /**
   * Delay (ms) before the fill action fires after popup sends the message.
   * Small delay lets the page settle before values are injected.
   */
  FILL_DELAY_MS: 150,
});
