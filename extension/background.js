// background.js — MV3 service worker
importScripts('config.js');
importScripts('crypto.js');

const { DESKTOP_URL, AUTO_SYNC_INTERVAL_MINUTES, SESSION_TIMEOUT_MINUTES,
        VERSION_POLL_TIMEOUT_MS, VAULT_EXPORT_TIMEOUT_MS } = SV_CONFIG;

let backgroundDecryptedSecrets = [];
const pendingLogins = {};

// ─── Tab Persistence ─────────────────────────────────────────────────────────
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status === 'complete' && pendingLogins[tabId]) {
    const pending = pendingLogins[tabId];
    if (Date.now() - pending.timestamp < 30000) {
      // Clear the SPA fallback timer since we navigated successfully
      if (pending.timeoutId) clearTimeout(pending.timeoutId);
      showPrompt(tabId, pending.creds);
    } else {
      delete pendingLogins[tabId];
    }
  }
});

// ─── Message Handler ────────────────────────────────────────────────────────
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.action === 'syncVault') {
    backgroundDecryptedSecrets = [];
    chrome.storage.local.set({
      encryptedVault: msg.vault,
      verificationToken: msg.verificationToken,
      lastSync: Date.now(),
      knownVaultVersion: msg.vaultVersion ?? -1,
    }, () => sendResponse?.({ success: true }));
    return true;
  }

  if (msg.action === 'captured-login') {
    handleCapturedLogin(sender.tab.id, msg.credentials);
  } else if (msg.action === 'save-captured-login') {
    saveToDesktop(sender.tab.id, msg.credentials);
  }

  if (msg.action === 'getVaultStatus') {
    chrome.storage.local.get(['encryptedVault', 'lastSync', 'knownVaultVersion'], (result) => {
      chrome.storage.session.get(['sessionMasterPassword'], (sess) => {
        sendResponse({
          hasVault: !!result.encryptedVault,
          lastSync: result.lastSync,
          knownVaultVersion: result.knownVaultVersion ?? -1,
          unlocked: !!sess.sessionMasterPassword,
        });
      });
    });
    return true;
  }
});

// ─── Alarms ───────────────────────────────────────────────────────────────────
chrome.alarms.create('clearSession', { periodInMinutes: SESSION_TIMEOUT_MINUTES });
chrome.alarms.create('autoSync', { periodInMinutes: AUTO_SYNC_INTERVAL_MINUTES });

chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === 'clearSession') {
    backgroundDecryptedSecrets = [];
    chrome.storage.session.remove('sessionMasterPassword');
  }
  if (alarm.name === 'autoSync') await attemptAutoSync();
});

// ─── Auto-sync ────────────────────────────────────────────────────────────────
async function attemptAutoSync() {
  try {
    const versionRes = await fetch(`${DESKTOP_URL}/vault-version`, { signal: AbortSignal.timeout(VERSION_POLL_TIMEOUT_MS) });
    if (!versionRes.ok) return;
    const { version: remoteVersion } = await versionRes.json();
    const local = await chrome.storage.local.get(['knownVaultVersion']);
    if (remoteVersion === local.knownVaultVersion) return;

    const exportRes = await fetch(`${DESKTOP_URL}/export-vault`, { signal: AbortSignal.timeout(VAULT_EXPORT_TIMEOUT_MS) });
    if (!exportRes.ok) return;

    const data = await exportRes.json();
    await chrome.storage.local.set({
      encryptedVault: data.vault,
      verificationToken: data.verificationToken,
      lastSync: Date.now(),
      knownVaultVersion: data.vaultVersion ?? remoteVersion,
    });
    backgroundDecryptedSecrets = [];
  } catch (e) {}
}

// ─── Login Capture ──────────────────────────────────────────────────────────
async function handleCapturedLogin(tabId, creds) {
  try {
    let hostname = 'unknown';
    try { hostname = new URL(creds.url).hostname.toLowerCase().replace(/^www\.|^login\.|^signin\.|^auth\./, ''); } catch (e) { hostname = (creds.title || 'unknown').toLowerCase().replace(/^www\./, '').split(' ')[0]; }
    const domain = hostname.split('.')[0];
    const username = (creds.username || '').toLowerCase().trim();
    const password = (creds.password || '').trim();

    const { encryptedVault } = await chrome.storage.local.get('encryptedVault');
    
    let domainMatchFound = false;
    if (encryptedVault?.length) {
      domainMatchFound = !!encryptedVault.find(s => {
        const sTitle = (s.title || '').toLowerCase().replace(/^www\.|^login\./, '');
        return sTitle.includes(domain) || domain.includes(sTitle.split('.')[0]);
      });
    }

    let isUpdate = false;
    let existingId = null;

    if (domainMatchFound) {
      const { sessionMasterPassword } = await chrome.storage.session.get('sessionMasterPassword');
      if (sessionMasterPassword && encryptedVault?.length) {
        if (!backgroundDecryptedSecrets.length) {
          try {
            const key = await CryptoHelper.deriveKey(sessionMasterPassword);
            backgroundDecryptedSecrets = await CryptoHelper.decryptVault(encryptedVault, key);
          } catch (e) {}
        }

        const existing = backgroundDecryptedSecrets.find(s => {
          const sTitle = s.title.toLowerCase().replace(/^www\.|^login\./, '');
          const sUrl = (s.fields['website url'] || '').toLowerCase().replace(/^https?:\/\//, '').replace(/^www\.|^login\./, '');
          const hostMatch = sTitle.includes(domain) || sUrl.includes(domain) || domain.includes(sTitle.split('.')[0]);
          if (!hostMatch) return false;
          return Object.values(s.fields).map(v => v.toLowerCase().trim()).includes(username);
        });

        if (existing) {
          const passMatch = Object.values(existing.fields).map(v => v.trim()).includes(password);
          if (passMatch) return; // CASE 2: Silent
          isUpdate = true;
          existingId = existing.id;
        }
      } else {
        return; // Locked -> Silent for managed domains
      }
    }

    creds.isUpdate = isUpdate;
    creds.existingId = existingId;
    
    // Store in pending and WAIT for navigation or 2s timeout
    const timeoutId = setTimeout(() => {
      if (pendingLogins[tabId] && pendingLogins[tabId].timeoutId === timeoutId) {
        showPrompt(tabId, pendingLogins[tabId].creds);
      }
    }, 2000);

    pendingLogins[tabId] = { creds, timestamp: Date.now(), timeoutId };

  } catch (err) {}
}

async function showPrompt(tabId, creds) {
  const projectRes = await fetch(`${SV_CONFIG.DESKTOP_URL}/projects`, { signal: AbortSignal.timeout(2000) }).catch(() => null);
  creds.projects = (projectRes && projectRes.ok) ? (await projectRes.json()).projects || [] : [];
  chrome.tabs.sendMessage(tabId, { action: 'show-save-prompt', credentials: creds }).catch(() => {});
}

async function saveToDesktop(tabId, creds) {
  try {
    const endpoint = creds.isUpdate ? '/update-secret' : '/add-secret';
    const res = await fetch(`${DESKTOP_URL}${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(creds)
    });
    if (res.ok) {
      delete pendingLogins[tabId];
      await attemptAutoSync();
      chrome.tabs.sendMessage(tabId, { action: 'save-success' }).catch(() => {});
    } else {
      throw new Error('App error');
    }
  } catch (e) {
    chrome.tabs.sendMessage(tabId, { action: 'save-failed', message: 'App not open! Please open Secret Vault on your desktop and try again.' }).catch(() => {});
  }
}

attemptAutoSync();
