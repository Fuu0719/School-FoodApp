const form = document.querySelector('#admin-login');
const statusNode = document.querySelector('#workspace-status');

sessionStorage.removeItem('adminToken');

function showStatus(message, error = false) {
  statusNode.textContent = message;
  statusNode.classList.toggle('error', error);
}

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  const button = form.querySelector('button[type="submit"]');
  button.disabled = true;
  showStatus('正在驗證身分…');
  try {
    const response = await fetch('/api/admin/auth/login', {
      method: 'POST',
      headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
      body: JSON.stringify(Object.fromEntries(new FormData(form))),
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(result.message || '登入失敗');
    form.reset();
    location.replace('/admin.html');
  } catch (error) {
    form.reset();
    showStatus(error.message, true);
    button.disabled = false;
    form.querySelector('input[name="email"]').focus();
  }
});
