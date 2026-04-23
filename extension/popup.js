const API_BASE = 'http://localhost:42042';

async function checkStatus() {
  try {
    const res = await fetch(`${API_BASE}/status`);
    const data = await res.json();
    
    document.getElementById('status-dot').className = 'status-dot online';
    document.getElementById('status-text').innerText = 'Vault Connected';
    
    chrome.storage.local.get(['pairedKey'], (result) => {
      if (result.pairedKey) {
        document.getElementById('search-section').style.display = 'block';
        document.getElementById('pair-section').style.display = 'none';
      } else {
        document.getElementById('pair-section').style.display = 'block';
        document.getElementById('search-section').style.display = 'none';
      }
    });
  } catch (e) {
    document.getElementById('status-dot').className = 'status-dot offline';
    document.getElementById('status-text').innerText = 'Desktop App Not Running';
  }
}

document.getElementById('pair-btn').onclick = async () => {
  const code = document.getElementById('pair-code').value;
  try {
    const res = await fetch(`${API_BASE}/pair`, {
      method: 'POST',
      body: JSON.stringify({ code })
    });
    const data = await res.json();
    if (data.key) {
      chrome.storage.local.set({ pairedKey: data.key }, () => {
        checkStatus();
      });
    } else {
      alert('Invalid code');
    }
  } catch (e) {
    alert('Failed to pair');
  }
};

document.getElementById('search').oninput = async (e) => {
  const q = e.target.value;
  const { pairedKey } = await chrome.storage.local.get(['pairedKey']);
  
  const res = await fetch(`${API_BASE}/secrets?q=${q}`, {
    headers: { 'Authorization': `Bearer ${pairedKey}` }
  });
  const data = await res.json();
  
  const results = document.getElementById('results');
  results.innerHTML = '';
  data.secrets.forEach(s => {
    const div = document.createElement('div');
    div.className = 'secret-item';
    div.innerHTML = `
      <div class="secret-info">
        <div class="secret-title">${s.title}</div>
        <div class="secret-type">${s.type}</div>
      </div>
      <button class="use-btn" data-id="${s.id}">USE</button>
    `;
    
    div.querySelector('.use-btn').onclick = (e) => {
      e.stopPropagation();
      getCredential(s.id);
    };
    
    results.appendChild(div);
  });
};

async function getCredential(id) {
  const { pairedKey } = await chrome.storage.local.get(['pairedKey']);
  
  // Get current tab URL for the approval dialog
  const [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
  const origin = new URL(tab.url).origin;

  const res = await fetch(`${API_BASE}/get-credential`, {
    method: 'POST',
    headers: { 
      'Authorization': `Bearer ${pairedKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ id, origin: origin })
  });
  
  const data = await res.json();
  if (data.status === 'approved') {
    chrome.tabs.sendMessage(tab.id, { 
      action: 'fill', 
      data: data.data 
    });
    window.close(); // Close popup after filling
  } else if (data.status === 'error') {
    alert(data.message || 'An error occurred');
  } else if (data.status === 'denied') {
    console.log('User denied request');
  }
}

checkStatus();
