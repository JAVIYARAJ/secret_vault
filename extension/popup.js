// popup.js — fully standalone. Desktop app only needed for initial ↻ Sync.
// All tuneable constants come from config.js (SV_CONFIG) — edit there.
// SV_CONFIG is loaded as a <script> before this file in popup.html.

const {
  DESKTOP_URL,
  STALE_WARNING_THRESHOLD_HOURS,
  SYNC_ERROR_DISMISS_MS,
  FILL_ERROR_DISMISS_MS,
  SYNC_BTN_RESET_MS,
  POST_SYNC_REINIT_DELAY_MS,
  FILL_DELAY_MS,
} = SV_CONFIG;

/** @type {Array<{id,title,type,projectName,fields,tags}>} */
let decryptedSecrets = [];
/** @type {CryptoKey|null} */
let cryptoKey = null;

// ─── Type icons ──────────────────────────────────────────────────────────────
const TYPE_ICONS = {
  login:      '👤',
  apiKey:     '🔑',
  database:   '🗄️',
  sshKey:     '💻',
  creditCard: '💳',
  wifi:       '📶',
  note:       '📝',
  custom:     '⚙️',
};

// ─── Init ─────────────────────────────────────────────────────────────────────
async function init() {
  const local = await chrome.storage.local.get(['encryptedVault', 'lastSync']);
  updateSyncStatus(local.lastSync);
  checkStaleness(local.lastSync);

  if (!local.encryptedVault) {
    showScreen('no-vault');
    setHeaderSub('No vault synced');
    return;
  }

  // Try to restore session if browser hasn't closed / alarm hasn't fired
  let sessionPwd = null;
  try {
    const s = await chrome.storage.session.get(['sessionMasterPassword']);
    sessionPwd = s.sessionMasterPassword || null;
  } catch (_) {}

  if (sessionPwd) {
    const ok = await tryUnlock(sessionPwd, { silent: true });
    if (ok) return;
  }

  showScreen('unlock');
  setHeaderSub('Vault locked');
}

// ─── Screen manager ───────────────────────────────────────────────────────────
function showScreen(name) {
  ['no-vault-screen', 'unlock-screen', 'main-screen'].forEach(id => {
    document.getElementById(id).style.display = 'none';
  });
  const map = { 'no-vault': 'no-vault-screen', unlock: 'unlock-screen', main: 'main-screen' };
  document.getElementById(map[name]).style.display = 'block';

  if (name === 'unlock') {
    const btn = document.getElementById('unlock-btn');
    btn.disabled = false;
    btn.textContent = 'Unlock Vault';
    setTimeout(() => document.getElementById('master-password').focus(), 40);
  }
  if (name === 'main')   setTimeout(() => document.getElementById('search').focus(), 40);
}

function setHeaderSub(text) {
  document.getElementById('header-sub').textContent = text;
}

// ─── Unlock ───────────────────────────────────────────────────────────────────
/**
 * @param {string} password
 * @param {{ silent?: boolean }} [opts]
 * @returns {Promise<boolean>}
 */
async function tryUnlock(password, opts = {}) {
  const { encryptedVault, verificationToken } =
    await chrome.storage.local.get(['encryptedVault', 'verificationToken']);

  if (!encryptedVault) return false;

  // Verify password via the verification token
  console.log('[SecretVault] Verifying password against token:', verificationToken ? verificationToken.substring(0, 20) + '…' : 'MISSING');
  const valid = await CryptoHelper.verifyPassword(verificationToken, password);
  console.log('[SecretVault] Password valid:', valid);
  if (!valid) return false;

  // Derive key and decrypt all secrets in browser
  cryptoKey = await CryptoHelper.deriveKey(password);
  decryptedSecrets = await CryptoHelper.decryptVault(encryptedVault, cryptoKey);

  // Cache password in session storage (auto-cleared when browser closes or alarm fires)
  try {
    await chrome.storage.session.set({ sessionMasterPassword: password });
  } catch (_) {}

  const count = decryptedSecrets.length;
  setHeaderSub(`${count} secret${count !== 1 ? 's' : ''}`);
  document.getElementById('secret-count').textContent =
    `${count} secret${count !== 1 ? 's' : ''}`;

  showScreen('main');
  renderSecrets('');
  return true;
}


// ─── Render ───────────────────────────────────────────────────────────────────
function renderSecrets(query) {
  const list = document.getElementById('secrets-list');
  const q = query.toLowerCase().trim();

  const filtered = q
    ? decryptedSecrets.filter(s =>
        s.title.toLowerCase().includes(q) ||
        s.type.toLowerCase().includes(q) ||
        s.projectName.toLowerCase().includes(q) ||
        s.tags.some(t => t.toLowerCase().includes(q))
      )
    : decryptedSecrets;

  if (filtered.length === 0) {
    list.innerHTML = `<div class="empty-results">${
      q ? `No secrets match "<b>${esc(query)}</b>"` : 'No secrets in vault'
    }</div>`;
    return;
  }

  list.innerHTML = '';
  filtered.forEach(secret => {
    const div = document.createElement('div');
    div.className = 'secret-item';
    div.innerHTML = `
      <div class="secret-icon">${TYPE_ICONS[secret.type] || '🔐'}</div>
      <div class="secret-info">
        <div class="secret-title">${esc(secret.title)}</div>
        <div class="secret-meta">${esc(secret.projectName)} · ${secret.type}</div>
      </div>
      <button class="fill-btn">Fill ↗</button>
    `;
    div.querySelector('.fill-btn').addEventListener('click', () => fillSecret(secret));
    list.appendChild(div);
  });
}

// ─── Auto-fill ────────────────────────────────────────────────────────────────
// Bitwarden-style: inject fill logic directly into the page via scripting API.
// This works even if the content script isn't pre-loaded (tabs opened before
// extension install/reload). Falls back to sendMessage if scripting is blocked.

async function fillSecret(secret) {
  const [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
  if (!tab?.id) {
    showFillError('No active tab found.');
    return;
  }

  // Check for restricted pages where scripting is never allowed
  const url = tab.url || '';
  if (url.startsWith('chrome://') || url.startsWith('chrome-extension://') ||
      url.startsWith('edge://') || url.startsWith('about:') || url === '') {
    showFillError('Cannot fill on browser system pages.');
    return;
  }

  const fields = secret.fields;

  try {
    // PRIMARY: inject fill function directly into the page (works on any tab,
    // even those opened before the extension was loaded — same as Bitwarden)
    await chrome.scripting.executeScript({
      target: { tabId: tab.id, allFrames: true },
      func: inPageFill,
      args: [fields],
    });
    window.close();
  } catch (scriptingErr) {
    console.warn('[SecretVault] scripting.executeScript failed:', scriptingErr.message);

    // FALLBACK: try the content script message channel
    try {
      await chrome.tabs.sendMessage(tab.id, { action: 'fill', data: fields });
      window.close();
    } catch (msgErr) {
      showFillError('Cannot fill on this page.\n' + msgErr.message);
    }
  }
}

/**
 * This function is serialised and injected directly into the page by
 * chrome.scripting.executeScript — it must be fully self-contained
 * (no references to variables/functions outside its scope).
 *
 * @param {Object} data — decrypted field map { "label": "value", ... }
 */
function inPageFill(data) {
  function fillField(input, value) {
    try {
      input.focus();
      // Native setter — works with React, Vue, Angular virtual DOM
      const nativeSetter = Object.getOwnPropertyDescriptor(
        window.HTMLInputElement.prototype, 'value'
      )?.set;
      if (nativeSetter) {
        nativeSetter.call(input, value);
      } else {
        input.value = value;
      }
      input.dispatchEvent(new Event('input',  { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
      setTimeout(() => input.dispatchEvent(new Event('blur', { bubbles: true })), 50);
    } catch (_) {}
  }

  const inputs = Array.from(document.querySelectorAll('input:not([type="hidden"])'));
  const passwordField = inputs.find(i => i.type === 'password');
  const userField = inputs.find(i =>
    (i.type === 'text' || i.type === 'email') &&
    i !== passwordField &&
    i.offsetWidth > 0
  );

  const userVal =
    data['email / username'] || data['username'] || data['email'] ||
    data['login'] || data['user'] || '';
  const passVal =
    data['password'] || data['pass'] || data['secret'] ||
    Object.entries(data).find(([k]) => k.includes('pass'))?.[1] || '';

  let filled = 0;
  if (userField     && userVal) { fillField(userField, userVal);         filled++; }
  if (passwordField && passVal) { fillField(passwordField, passVal);     filled++; }

  return filled; // returned value visible in scripting result for debugging
}

function showFillError(msg) {
  // Show a brief error banner inside the popup instead of closing it
  let banner = document.getElementById('fill-error-banner');
  if (!banner) {
    banner = document.createElement('div');
    banner.id = 'fill-error-banner';
    banner.style.cssText =
      'background:#2a1010;border:1px solid #f87171;border-radius:8px;' +
      'color:#f87171;font-size:11px;padding:8px 12px;margin:0 14px 8px;' +
      'line-height:1.5;white-space:pre-wrap;';
    const list = document.getElementById('secrets-list');
    list.parentNode.insertBefore(banner, list);
  }
  banner.textContent = '⚠ ' + msg;
  setTimeout(() => banner?.remove(), FILL_ERROR_DISMISS_MS);
}

// ─── Sync from desktop ────────────────────────────────────────────────────────
async function syncFromDesktop() {
  const btn = document.getElementById('sync-btn');
  btn.textContent = '↻ Syncing…';
  btn.disabled = true;
  hideSyncError();

  try {
    let res;
    try {
      res = await fetch(`${DESKTOP_URL}/export-vault`, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' },
      });
    } catch (fetchErr) {
      // Network error = desktop app not running
      showSyncError(
        '🖥️  Please open the Secret Vault desktop app first',
        'Make sure the app is open and unlocked, then click ↻ Sync again.'
      );
      return;
    }

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      // 403 = app locked
      if (res.status === 403) {
        showSyncError(
          '🔒  Desktop app is locked',
          'Open Secret Vault desktop app and unlock it first, then sync.'
        );
      } else {
        showSyncError('✗  Sync failed', err.error || `HTTP ${res.status}`);
      }
      return;
    }

    const data = await res.json();

    await chrome.storage.local.set({
      encryptedVault: data.vault,
      verificationToken: data.verificationToken,
      lastSync: Date.now(),
    });

    updateSyncStatus(Date.now());
    btn.textContent = '✓ Synced!';

    // Clear stale session so user re-enters password against new vault
    try { await chrome.storage.session.remove('sessionMasterPassword'); } catch (_) {}
    cryptoKey = null;
    decryptedSecrets = [];

    setTimeout(init, POST_SYNC_REINIT_DELAY_MS);
  } catch (e) {
    showSyncError('✗  Sync failed', e.message);
    console.error('[SecretVault] Sync error:', e.message);
  } finally {
    setTimeout(() => {
      btn.textContent = '↻ Sync';
      btn.disabled = false;
    }, SYNC_BTN_RESET_MS);
  }
}

function showSyncError(title, detail) {
  hideSyncError();
  const bar = document.createElement('div');
  bar.id = 'sync-error-banner';
  bar.style.cssText =
    'background:linear-gradient(135deg,#1a1030,#120d28);' +
    'border:1px solid #7c6af755;border-radius:10px;' +
    'padding:11px 13px;margin:8px 14px 0;text-align:left;' +
    'position:relative;overflow:hidden;';
  bar.innerHTML = `
    <div style="position:absolute;top:0;left:0;right:0;height:2px;
      background:linear-gradient(90deg,#f87171,#fb923c,#f87171);
      background-size:200% 100%;animation:shimmer 2s linear infinite;"></div>
    <div style="font-size:12px;font-weight:700;color:#fca5a5;margin-bottom:3px;">${title}</div>
    <div style="font-size:11px;color:#7070a0;line-height:1.5;">${detail}</div>
  `;
  const syncBar = document.querySelector('.sync-bar');
  syncBar.after(bar);
  setTimeout(hideSyncError, SYNC_ERROR_DISMISS_MS);
}

function hideSyncError() {
  document.getElementById('sync-error-banner')?.remove();
}

function updateSyncStatus(lastSync) {
  const dot   = document.getElementById('sync-dot');
  const label = document.getElementById('sync-status');
  if (!lastSync) {
    dot.className = 'sync-dot sync-no';
    label.textContent = 'Never synced';
    return;
  }
  dot.className = 'sync-dot sync-ok';
  const mins = Math.floor((Date.now() - lastSync) / 60000);
  const hrs  = Math.floor(mins / 60);
  const days = Math.floor(hrs  / 24);
  label.textContent =
    days > 0 ? `Synced ${days}d ago` :
    hrs  > 0 ? `Synced ${hrs}h ago` :
    mins > 0 ? `Synced ${mins}m ago` : 'Synced just now';
}

/**
 * Shows a subtle amber warning if the vault hasn't been synced recently.
 * Bitwarden shows this as a "vault may be outdated" indicator.
 * Deletions/edits in the desktop app won't show until re-synced.
 */
function checkStaleness(lastSync) {
  // Remove any existing staleness banner
  document.getElementById('stale-banner')?.remove();

  if (!lastSync) return; // never synced — no-vault screen handles this

  const ageMs  = Date.now() - lastSync;
  const ageHrs = ageMs / (1000 * 60 * 60);

  if (ageHrs < STALE_WARNING_THRESHOLD_HOURS) return; // fresh enough, no warning needed

  const ageText = ageHrs < 24
    ? `${Math.floor(ageHrs)}h ago`
    : `${Math.floor(ageHrs / 24)}d ago`;

  const bar = document.createElement('div');
  bar.id = 'stale-banner';
  bar.style.cssText =
    'background:#1a150a;border:1px solid #f59e0b44;border-radius:8px;' +
    'padding:7px 12px;margin:6px 14px 0;display:flex;align-items:center;' +
    'gap:8px;font-size:10px;color:#d97706;line-height:1.4;';
  bar.innerHTML = `
    <span style="flex-shrink:0">⚠️</span>
    <span>
      Last synced <b>${ageText}</b> — if you deleted or edited secrets in the
      desktop app, click <b>↻ Sync</b> to update.
    </span>
  `;

  // Insert below sync-bar, above the active screen
  const syncBar = document.querySelector('.sync-bar');
  syncBar.after(bar);
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
function esc(str) {
  return String(str)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// ─── Event listeners ─────────────────────────────────────────────────────────
document.getElementById('unlock-btn').addEventListener('click', async () => {
  const pwd = document.getElementById('master-password').value;
  if (!pwd) return;

  const btn = document.getElementById('unlock-btn');
  const err = document.getElementById('error-msg');
  
  try {
    err.style.display = 'none';
    btn.disabled = true;
    btn.textContent = 'Unlocking…';

    const ok = await tryUnlock(pwd);

    if (!ok) {
      err.style.display = 'block';
      btn.disabled = false;
      btn.textContent = 'Unlock Vault';
      document.getElementById('master-password').select();
    }
  } catch (e) {
    console.error('[SecretVault] Unlock error:', e);
    err.style.display = 'block';
    err.textContent = '✗ Error: ' + e.message;
    btn.disabled = false;
    btn.textContent = 'Unlock Vault';
  }
});

document.getElementById('master-password').addEventListener('keydown', e => {
  if (e.key === 'Enter') document.getElementById('unlock-btn').click();
});

document.getElementById('eye-btn').addEventListener('click', () => {
  const inp = document.getElementById('master-password');
  inp.type = inp.type === 'password' ? 'text' : 'password';
  document.getElementById('eye-btn').textContent = inp.type === 'password' ? '👁' : '🙈';
});

document.getElementById('search').addEventListener('input', e => renderSecrets(e.target.value));

document.getElementById('lock-btn').addEventListener('click', async () => {
  try { await chrome.storage.session.remove('sessionMasterPassword'); } catch (_) {}
  cryptoKey = null;
  decryptedSecrets = [];
  document.getElementById('master-password').value = '';
  document.getElementById('error-msg').style.display = 'none';
  showScreen('unlock');
  setHeaderSub('Vault locked');
});

document.getElementById('sync-btn').addEventListener('click', syncFromDesktop);

// ─── Start ────────────────────────────────────────────────────────────────────
init();
