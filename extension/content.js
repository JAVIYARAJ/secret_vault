// content.js — universal auto-fill & login capture

// ─── Auto-fill Listener ──────────────────────────────────────────────────────
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'fill') {
    handleFill(request.data);
  } else if (request.action === 'show-save-prompt') {
    showSavePrompt(request.credentials);
  }
});

function handleFill(data) {
  console.log('%c[Secret Vault] Auto-fill triggered', 'color:#7c6af7;font-weight:bold');

  setTimeout(() => {
    const inputs = Array.from(document.querySelectorAll('input:not([type="hidden"])'));
    const passwordField = inputs.find(i => i.type === 'password');
    const userField = inputs.find(i =>
      (i.type === 'text' || i.type === 'email') &&
      i !== passwordField &&
      i.offsetWidth > 0
    );

    const userVal = data['email / username'] || data['username'] || data['email'] || data['login'] || data['user'] || '';
    const passVal = data['password'] || data['pass'] || data['secret'] || Object.entries(data).find(([k]) => k.includes('pass'))?.[1] || '';

    let filled = 0;
    if (userField && userVal) { fillField(userField, userVal); filled++; }
    if (passwordField && passVal) { fillField(passwordField, passVal); filled++; }

    if (filled > 0) {
      console.log(`%c[Secret Vault] Filled ${filled} field(s)`, 'color:#34d399;font-weight:bold');
    }
  }, 150);
}

function fillField(input, value) {
  try {
    input.focus();
    const nativeSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value')?.set;
    if (nativeSetter) nativeSetter.call(input, value);
    else input.value = value;
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
    setTimeout(() => input.dispatchEvent(new Event('blur', { bubbles: true })), 50);
  } catch (err) { console.error('[Secret Vault] Fill error:', err); }
}

// ─── Login Capture ───────────────────────────────────────────────────────────
window.addEventListener('submit', e => {
  const form = e.target;
  const pass = form.querySelector('input[type="password"]');
  if (!pass || !pass.value) return;

  const user = form.querySelector('input[type="text"], input[type="email"]');
  const credentials = {
    title: window.location.hostname,
    username: user ? user.value : '',
    password: pass.value
  };

  // Notify background script about potential new login
  chrome.runtime.sendMessage({ action: 'captured-login', credentials });
}, true);

// ─── UI: Save Password Prompt ────────────────────────────────────────────────
function showSavePrompt(creds) {
    document.getElementById('sv-save-prompt')?.remove();
    const prompt = document.createElement('div');
    prompt.id = 'sv-save-prompt';
    
    const isUpdate = creds.isUpdate;
    const accentColor = isUpdate ? '#f59e0b' : '#7c6af7';
    const accentGradient = isUpdate ? 'linear-gradient(135deg, #f59e0b, #d97706)' : 'linear-gradient(135deg, #7c6af7, #5b4de0)';
    const titleText = isUpdate ? 'Update Password?' : 'Save to Vault?';

    Object.assign(prompt.style, {
      position: 'fixed', top: '24px', right: '24px', zIndex: '2147483647',
      width: '340px', background: '#0B0B10', color: '#fff', padding: '24px',
      borderRadius: '20px', boxShadow: `0 20px 50px rgba(0,0,0,0.7), 0 0 0 1px ${accentColor}22`,
      border: `1px solid ${accentColor}33`, fontFamily: '"Outfit", "Inter", sans-serif',
      animation: 'sv-slide-in 0.4s cubic-bezier(0.16, 1, 0.3, 1)',
      overflow: 'hidden'
    });

    if (!document.getElementById('sv-styles')) {
      const style = document.createElement('style');
      style.id = 'sv-styles';
      style.textContent = `
        @keyframes sv-slide-in { from { transform: translateX(50px) scale(0.95); opacity: 0; } to { transform: translateX(0) scale(1); opacity: 1; } }
        .sv-btn:hover { transform: translateY(-1px); filter: brightness(1.1); }
        .sv-btn:active { transform: translateY(0); }
        .sv-select:focus { border-color: ${accentColor} !important; }
      `;
      document.head.appendChild(style);
    }

    const projects = (creds.projects || []).map(p => `<option value="${p.id}">${p.name}</option>`).join('');

    prompt.innerHTML = `
      <div style="position:absolute;top:0;left:0;width:100%;height:4px;background:${accentGradient}"></div>
      
      <div style="display:flex;align-items:center;gap:14px;margin-bottom:20px;">
        <div style="width:40px;height:40px;background:${accentGradient};border-radius:12px;display:flex;align-items:center;justify-content:center;font-size:20px;box-shadow:0 4px 15px ${accentColor}44;">
          ${isUpdate ? '🔄' : '🔐'}
        </div>
        <div>
          <div style="font-weight:800;font-size:16px;letter-spacing:-0.2px;">${titleText}</div>
          <div style="font-size:12px;color:#66667e;margin-top:2px;">${creds.title}</div>
        </div>
        <button id="sv-dismiss" style="margin-left:auto;background:none;border:none;color:#44445a;cursor:pointer;font-size:20px;padding:5px;">×</button>
      </div>

      <div style="background:#13131D;border:1px solid #1e1e2e;border-radius:14px;padding:14px;margin-bottom:20px;">
        <div style="display:flex;align-items:center;gap:10px;margin-bottom:10px;">
          <div style="font-size:11px;color:#55556a;width:60px;">Username</div>
          <div style="font-size:12px;color:#eee;font-weight:600;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${creds.username || '—'}</div>
        </div>
        <div style="display:flex;align-items:center;gap:10px;">
          <div style="font-size:11px;color:#55556a;width:60px;">Password</div>
          <div style="font-size:12px;color:#eee;letter-spacing:3px;">••••••••</div>
        </div>
      </div>

      ${(!isUpdate && projects) ? `
        <div style="margin-bottom:20px;">
          <div style="font-size:11px;color:#55556a;margin-bottom:8px;margin-left:4px;">Project / Vault</div>
          <select id="sv-project" class="sv-select" style="width:100%;background:#13131D;color:#fff;border:1px solid #1e1e2e;padding:12px;border-radius:12px;font-size:12px;outline:none;cursor:pointer;transition:all 0.2s;">
            ${projects}
          </select>
        </div>` : ''}

      <div style="display:flex;gap:12px;">
        <button id="sv-cancel" class="sv-btn" style="flex:1;background:#13131D;border:1px solid #1e1e2e;color:#888;padding:12px;border-radius:12px;font-size:12px;font-weight:600;cursor:pointer;transition:all 0.2s;">Not now</button>
        <button id="sv-save" class="sv-btn" style="flex:2;background:${accentGradient};border:none;color:#fff;padding:12px;border-radius:12px;font-size:12px;font-weight:800;cursor:pointer;transition:all 0.2s;box-shadow:0 4px 15px ${accentColor}33;">
          ${isUpdate ? 'Update Entry' : 'Save Password'}
        </button>
      </div>
    `;

    document.body.appendChild(prompt);

    const timer = setTimeout(() => prompt.remove(), 15000);
    document.getElementById('sv-dismiss').onclick = 
    document.getElementById('sv-cancel').onclick = () => { clearTimeout(timer); prompt.remove(); };
    
    document.getElementById('sv-save').onclick = () => {
      clearTimeout(timer);
      const sel = document.getElementById('sv-project');
      if (sel) creds.projectId = sel.value;
      chrome.runtime.sendMessage({ action: 'save-captured-login', credentials: creds });
      prompt.innerHTML = `
        <div style="text-align:center;padding:10px 0;">
          <div style="font-size:32px;margin-bottom:12px;">✅</div>
          <div style="font-size:16px;font-weight:800;color:#34d399;">Success!</div>
          <div style="font-size:11px;color:#66667e;margin-top:4px;">Credential synced to vault</div>
        </div>`;
      setTimeout(() => prompt.remove(), 2000);
    };
  }
