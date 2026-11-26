/* ============================================================================
   BHARAT ORGANIC MART — Shared Auth Module
   Uses the Supabase ANON (public) key only. The service_role key is NEVER
   loaded here — it stays server-side / in local scripts.
   ========================================================================== */

const SUPABASE_URL = 'https://syxrvkiqrvbecqdkyphs.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN5eHJ2a2lxcnZiZWNxZGt5cGhzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTU1MzA2NDksImV4cCI6MjExMTEwNjY0OX0.x52zcDxXj2rtjs5fPbRKXLpRuDBXshuyBT24SEDzeo4';

const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

/* Account type chosen on the form -> DB role in user_profiles.role */
const ACCOUNT_TYPE_ROLE = {
  farmer: 'operator',
  supplier: 'operator',
  buyer: 'buyer',
  other: 'operator'
};

const DASHBOARD_BY_ROLE = {
  buyer: 'buyer-dashboard.html',
  operator: 'supplier-dashboard.html',
  admin: 'admin/index.html',
  super_admin: 'admin/index.html'
};

/* ------------------------------------------------------------------ *
 * 1. Sign up (email + password + account type)
 * ------------------------------------------------------------------ */
async function authSignUp({ fullName, email, password, accountType }) {
  const role = ACCOUNT_TYPE_ROLE[accountType] || 'operator';

  const { data, error } = await sb.auth.signUp({
    email,
    password,
    options: {
      data: {
        full_name: fullName,
        account_type: accountType,   // kept in auth metadata (display label)
        role                        // mirrored into user_profiles by trigger
      }
    }
  });

  if (error) throw error;
  return data; // data.user may be null until email is confirmed
}

/* ------------------------------------------------------------------ *
 * 2. Sign in
 * ------------------------------------------------------------------ */
async function authSignIn({ email, password }) {
  const { data, error } = await sb.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

/* ------------------------------------------------------------------ *
 * 3. Sign out
 * ------------------------------------------------------------------ */
async function authSignOut() {
  const { error } = await sb.auth.signOut();
  if (error) throw error;
}

/* ------------------------------------------------------------------ *
 * 4. Password reset email
 * ------------------------------------------------------------------ */
async function authResetPassword(email) {
  const { error } = await sb.auth.resetPasswordForEmail(email, {
    redirectTo: window.location.origin + '/login.html?mode=reset'
  });
  if (error) throw error;
}

/* ------------------------------------------------------------------ *
 * 5. Resend email confirmation
 * ------------------------------------------------------------------ */
async function authResendConfirmation(email) {
  const { error } = await sb.auth.resend({
    email,
    type: 'signup'
  });
  if (error) throw error;
}

/* ------------------------------------------------------------------ *
 * 6. Session helpers
 * ------------------------------------------------------------------ */
async function getCurrentUser() {
  const { data } = await sb.auth.getUser();
  return data?.user || null;
}

async function getSession() {
  const { data } = await sb.auth.getSession();
  return data?.session || null;
}

/* Listen for login / logout / token refresh */
function onAuthStateChange(cb) {
  return sb.auth.onAuthStateChange((event, session) => cb(event, session));
}

/* ------------------------------------------------------------------ *
 * 7. Profile helpers (read via RLS — user can only read their own row)
 * ------------------------------------------------------------------ */
async function getMyProfile() {
  const user = getCurrentUser();
  if (!user) return null;

  const { data, error } = await sb
    .from('user_profiles')
    .select('*')
    .eq('id', user.id)
    .maybeSingle();

  if (error) throw error;
  return data;
}

/* ------------------------------------------------------------------ *
 * 8. Admin check — enforced by the DB, not by the browser.
 *    RLS on admin_users only lets you read YOUR OWN row, so a row
 *    returning here means the database itself says you are an admin.
 * ------------------------------------------------------------------ */
async function isAdmin() {
  const user = getCurrentUser();
  if (!user) return false;

  const { data, error } = await sb
    .from('admin_users')
    .select('role')
    .eq('id', user.id)
    .maybeSingle();

  // "no row" is not an error — it just means "not an admin"
  if (error && error.code !== 'PGRST116') throw error;
  return !!data;
}

/* ------------------------------------------------------------------ *
 * 9. Redirect helpers
 * ------------------------------------------------------------------ */
function dashboardForRole(role) {
  return DASHBOARD_BY_ROLE[role] || 'supplier-dashboard.html';
}

function redirectIfAuthenticated() {
  const user = getCurrentUser();
  if (!user) return;

  const role = user.user_metadata?.role || 'operator';
  const target = dashboardForRole(role);

  if (!window.location.pathname.endsWith(target)) {
    window.location.replace(target);
  }
}

/* ------------------------------------------------------------------ *
 * 10. Page guard — call at the top of every protected page.
 *     roles: optional array, e.g. ['admin'] or ['operator','buyer']
 * ------------------------------------------------------------------ */
async function requireAuth({ roles = null, loginPage = 'login.html' } = {}) {
  const session = await getSession();

  if (!session) {
    window.location.replace(loginPage + '?next=' + encodeURIComponent(window.location.pathname));
    return null;
  }

  const profile = await getMyProfile().catch(() => null);
  const role = profile?.role || session.user.user_metadata?.role || 'operator';

  if (roles && !roles.includes(role)) {
    document.body.innerHTML = `
      <div style="max-width:420px;margin:80px auto;padding:32px;text-align:center;font-family:sans-serif">
        <h1 style="font-size:24px;font-weight:700">Access denied</h1>
        <p style="margin-top:8px;color:#666">Your account type is not allowed on this page.</p>
        <a href="/" style="display:inline-block;margin-top:16px;color:#2D5A27;font-weight:600">Back to site</a>
      </div>`;
    return null;
  }

  return { user: session.user, profile, role };
}

/* Expose for pages that need it */
window.BOMAuth = {
  sb,
  signUp: authSignUp,
  signIn: authSignIn,
  signOut: authSignOut,
  resetPassword: authResetPassword,
  resendConfirmation: authResendConfirmation,
  currentUser: getCurrentUser,
  session: getSession,
  profile: getMyProfile,
  isAdmin,
  requireAuth,
  redirectIfAuthenticated,
  onAuthStateChange,
  dashboardForRole
};
