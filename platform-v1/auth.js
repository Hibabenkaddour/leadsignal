/* Supabase Auth controls identity; database membership controls access. */
const authPanel = document.getElementById('authPanel');
const authStatus = document.getElementById('authStatus');
const loginForm = document.getElementById('loginForm');
let applicationStarted = false;
const recoveryFlow = /type=(recovery|invite)/.test(location.hash);
function clearWorkspaceCache() {
  ['leadSignalState', 'leadSignalActiveIcpId', 'leadSignalHermesSignalTestSecret',
    'leadSignalHermesSignalTestEndpoint'].forEach(key => localStorage.removeItem(key));
}
clearWorkspaceCache();
window.authorizedFetch = async function(url, options = {}) {
  const target = new URL(url, location.origin);
  if (target.origin !== location.origin) throw new Error('Destination non autorisée.');
  const { data: { session } } = await supabaseClient.auth.getSession();
  if (!session) throw new Error('Veuillez vous reconnecter.');
  const headers = new Headers(options.headers);
  headers.set('Authorization', `Bearer ${session.access_token}`);
  return fetch(target, { ...options, headers });
};
async function enterWorkspace() {
  const { data: { user }, error } = await supabaseClient.auth.getUser();
  if (error || !user) return;
  const { data: allowed, error: membershipError } = await supabaseClient.rpc('is_platform_member');
  if (membershipError || allowed !== true) {
    authStatus.textContent = membershipError ? 'Accès indisponible : la configuration des accès doit être finalisée.' : 'Votre compte n’a pas accès à cet espace. Contactez votre administrateur.';
    document.getElementById('authSignOut').hidden = false;
    return;
  }
  if (applicationStarted) return;
  window.platformUserId = user.id;
  applicationStarted = true;
  document.getElementById('accountEmail').textContent = user.email;
  document.body.classList.remove('locked');
  authPanel.hidden = true;
  const script = document.createElement('script');
    script.src = 'app.js?v=cluster-display-20261014-v3';
  script.onerror = () => { authStatus.textContent = 'Impossible de charger la plateforme.'; authPanel.hidden = false; document.body.classList.add('locked'); };
  document.body.appendChild(script);
}
loginForm.addEventListener('submit', async event => {
  event.preventDefault();
  const submit = loginForm.querySelector('button');
  submit.disabled = true;
  authStatus.textContent = 'Connexion…';
  try {
    const { error } = await supabaseClient.auth.signInWithPassword({ email: document.getElementById('loginEmail').value.trim(), password: document.getElementById('loginPassword').value });
    if (error) { authStatus.textContent = 'Connexion refusée. Vérifiez vos identifiants ou réessayez plus tard.'; return; }
    document.getElementById('loginPassword').value = '';
    await enterWorkspace();
  } catch { authStatus.textContent = 'Connexion indisponible. Réessayez.'; }
  finally { submit.disabled = false; }
});
async function logout() {
  document.body.classList.add('locked');
  clearWorkspaceCache();
  await supabaseClient.auth.signOut({ scope: 'local' });
  location.replace(location.pathname);
}
document.getElementById('logoutButton').onclick = logout;
document.getElementById('authSignOut').onclick = logout;
document.getElementById('resetPassword').onclick = async () => {
  const email = document.getElementById('loginEmail');
  if (!email.reportValidity() || !email.value) return;
  await supabaseClient.auth.resetPasswordForEmail(email.value.trim(), { redirectTo: location.origin + '/index.html' });
  authStatus.textContent = 'Si ce compte existe, un lien de réinitialisation vous sera envoyé.';
};
document.getElementById('passwordForm').onsubmit = async event => {
  event.preventDefault();
  const password = document.getElementById('newPassword').value;
  const { error } = await supabaseClient.auth.updateUser({ password });
  if (error) { authStatus.textContent = 'Impossible de définir ce mot de passe. Demandez un nouveau lien si nécessaire.'; return; }
  document.getElementById('newPassword').value = '';
  history.replaceState(null, '', location.pathname);
  document.getElementById('passwordForm').hidden = true;
  await enterWorkspace();
};
supabaseClient.auth.onAuthStateChange(event => {
  if (event === 'SIGNED_OUT' && applicationStarted) { clearWorkspaceCache(); location.replace(location.pathname); }
  if (event === 'PASSWORD_RECOVERY') {
    loginForm.hidden = true;
    document.getElementById('passwordForm').hidden = false;
  }
});
if (recoveryFlow) {
  loginForm.hidden = true;
  document.getElementById('passwordForm').hidden = false;
} else enterWorkspace().catch(() => { authStatus.textContent = 'Connexion indisponible.'; });
