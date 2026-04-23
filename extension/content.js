chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'fill') {
    console.log('%c[Secret Vault] Starting Universal Auto-fill...', 'color: #7C4DFF; font-weight: bold;');
    
    setTimeout(() => {
      const data = request.data;
      const inputs = Array.from(document.querySelectorAll('input:not([type="hidden"])'));
      
      // Find the best candidates
      let passwordField = inputs.find(i => i.type === 'password');
      let userField = inputs.find(i => 
        (i.type === 'text' || i.type === 'email') && 
        i !== passwordField &&
        i.offsetWidth > 0
      );

      console.log('[Secret Vault] Fields found:', { userField: !!userField, passwordField: !!passwordField });

      // Get values from the data object
      const values = Object.values(data);
      const userVal = data['username'] || data['email'] || data['login'] || data['user'] || values[0] || '';
      const passVal = data['password'] || data['pass'] || data['secret'] || values[1] || values.find(v => v.length > 8) || '';

      if (userField && userVal) {
        fillField(userField, userVal);
      }
      
      if (passwordField && passVal) {
        fillField(passwordField, passVal);
      }

      if (!userField && !passwordField) {
        console.error('[Secret Vault] Could not find any input fields to fill.');
      } else {
        console.log('%c[Secret Vault] Auto-fill complete!', 'color: #00E676; font-weight: bold;');
      }
    }, 150);
  }
});

function fillField(input, value) {
  try {
    input.focus();
    
    // Set value using multiple methods
    input.value = value;
    input.setAttribute('value', value);
    
    // Dispatch events
    const events = ['input', 'change', 'blur'];
    events.forEach(e => {
      input.dispatchEvent(new Event(e, { bubbles: true }));
    });
    
    // Some sites need a small delay before blur
    setTimeout(() => input.dispatchEvent(new Event('blur', { bubbles: true })), 50);
    
  } catch (err) {
    console.error('[Secret Vault] Error filling field:', err);
  }
}
