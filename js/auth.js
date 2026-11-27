/* ============================================================================
   BHARAT ORGANIC MART — Shared Auth Module
   Uses the Supabase ANON (public) key only. The service_role key is NEVER
   loaded here — it stays server-side / in local scripts.
   ========================================================================== */

const SUPABASE_URL = 'https://syxrvkiqrvbecqdkyphs.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN5eHJ2a2lxcnZiZWNxZGt5cGhzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTU1MzA2NDksImV4cCI6MjExMTEwNjY0OX0.x52zcDxXj2rtjs5fPbRKXLpRuDBXshuyBT24SEDzeo4';

const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true
  }
});

/* Account type chosen on the form -> DB role in user_profiles.role */
const ACCOUNT_TYPE_ROLE = {
  farmer: 'operator',
  supplier: 'operator',
  processor: 'operator',
  trader: 'operator',
  exporter: 'operator',
  importer: 'buyer',
  buyer: 'buyer',
  other: 'operator'
};

const ROLE_LABELS = {
  operator: 'Organic Supplier',
  buyer: 'Buyer / Importer',
  admin: 'Administrator',
  super_admin: 'Super Administrator'
};

const DASHBOARD_BY_ROLE = {
  buyer: 'buyer-dashboard.html',
  operator: 'supplier-dashboard.html',
  admin: 'admin/index.html',
  super_admin: 'admin/index.html'
};

const ROLE_NAV = {
  operator: [
    { label: 'My Farm Profile', href: 'supplier-dashboard.html#farm-profile', icon: 'fas fa-seedling', roles: ['operator'] },
    { label: 'My Crops', href: 'supplier-dashboard.html#my-crops', icon: 'fas fa-seedling', roles: ['operator'] },
    { label: 'Crop Availability', href: 'supplier-dashboard.html#crop-availability', icon: 'fas fa-calendar-alt', roles: ['operator'] },
    { label: 'Harvest Information', href: 'supplier-dashboard.html#harvest', icon: 'fas fa-tractor', roles: ['operator'] },
    { label: 'Contract Farming', href: 'supplier-dashboard.html#contract-farming', icon: 'fas fa-handshake', roles: ['operator'] },
    { label: 'Buyer Enquiries', href: 'supplier-dashboard.html#enquiries', icon: 'fas fa-envelope', roles: ['operator'] },
    { label: 'My Listings', href: 'supplier-dashboard.html#my-listings', icon: 'fas fa-list', roles: ['operator'] },
    { label: 'Certification & Documents', href: 'supplier-dashboard.html#certification', icon: 'fas fa-certificate', roles: ['operator'] },
    { label: 'Processing Capabilities', href: 'supplier-dashboard.html#processing', icon: 'fas fa-industry', roles: ['operator'] },
    { label: 'Export Markets', href: 'supplier-dashboard.html#export', icon: 'fas fa-globe', roles: ['operator'] },
    { label: 'Buyer Enquiries', href: 'supplier-dashboard.html#buyer-enquiries', icon: 'fas fa-inbox', roles: ['operator'] },
    { label: 'Private Label Opportunities', href: 'supplier-dashboard.html#private-label', icon: 'fas fa-tag', roles: ['operator'] }
  ],
  buyer: [
    { label: 'My Buyer Profile', href: 'buyer-dashboard.html#profile', icon: 'fas fa-user-tie', roles: ['buyer'] },
    { label: 'Post a Requirement', href: 'rfq-post.html', icon: 'fas fa-file-alt', roles: ['buyer'] },
    { label: 'My Requirements', href: 'buyer-dashboard.html#my-requirements', icon: 'fas fa-clipboard-list', roles: ['buyer'] },
    { label: 'Supplier Enquiries', href: 'buyer-dashboard.html#enquiries', icon: 'fas fa-search', roles: ['buyer'] },
    { label: 'Saved Suppliers', href: 'buyer-dashboard.html#saved', icon: 'fas fa-heart', roles: ['buyer'] },
    { label: 'Quotations / Responses', href: 'buyer-dashboard.html#quotations', icon: 'fas fa-file-invoice', roles: ['buyer'] },
    { label: 'Saved Suppliers', href: 'buyer-dashboard.html#saved-suppliers', icon: 'fas fa-bookmark', roles: ['buyer'] }
  ],
  admin: [
    { label: 'Admin Dashboard', href: 'admin/index.html', icon: 'fas fa-tachometer-alt', roles: ['admin', 'super_admin'] },
    { label: 'User Management', href: 'admin/index.html#users', icon: 'fas fa-users', roles: ['admin', 'super_admin'] },
    { label: 'Listing Management', href: 'admin/index.html#listings', icon: 'fas fa-list', roles: ['admin', 'super_admin'] },
    { label: 'Claims Management', href: 'admin/index.html#claims', icon: 'fas fa-flag', roles: ['admin', 'super_admin'] },
    { label: 'Certification Verification', href: 'admin/index.html#certification', icon: 'fas fa-certificate', roles: ['admin', 'super_admin'] },
    { label: 'Reports & Analytics', href: 'admin/index.html#reports', icon: 'fas fa-chart-bar', roles: ['admin', 'super_admin'] }
  ]
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
        account_type: accountType,
        role
      }
    }
  });

  if (error) throw error;
  return data;
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

async function getProfile() {
  const user = await getCurrentUser();
  if (!user) return null;
  const { data, error } = await sb
    .from('user_profiles')
    .select('*')
    .eq('id', user.id)
    .maybeSingle();
  if (error) throw error;
  return data;
}

/* Listen for login / logout / token refresh */
function onAuthStateChange(cb) {
  return sb.auth.onAuthStateChange((event, session) => cb(event, session));
}

/* ------------------------------------------------------------------ *
 * 7. Admin check
 * ------------------------------------------------------------------ */
async function isAdmin() {
  const user = await getCurrentUser();
  if (!user) return false;
  const { data, error } = await sb
    .from('admin_users')
    .select('role')
    .eq('id', user.id)
    .maybeSingle();
  if (error && error.code !== 'PGRST116') throw error;
  return !!data;
}

/* ------------------------------------------------------------------ *
 * 8. Redirect helpers
 * ------------------------------------------------------------------ */
function dashboardForRole(role) {
  return DASHBOARD_BY_ROLE[role] || 'supplier-dashboard.html';
}

function redirectIfAuthenticated() {
  getCurrentUser().then(user => {
    if (!user) return;
    const role = user.user_metadata?.role || 'operator';
    const target = dashboardForRole(role);
    if (!window.location.pathname.endsWith(target)) {
      window.location.replace(target);
    }
  });
}

/* ------------------------------------------------------------------ *
 * 9. Page guard
 * ------------------------------------------------------------------ */
async function requireAuth({ roles = null, loginPage = 'login.html' } = {}) {
  const session = await getSession();
  if (!session) {
    window.location.replace(loginPage + '?next=' + encodeURIComponent(window.location.pathname));
    return null;
  }
  const profile = await getProfile().catch(() => null);
  const role = profile?.role || session.user.user_metadata?.role || 'operator';
  if (roles && !roles.includes(role)) {
    document.body.innerHTML = `<div style="max-width:420px;margin:80px auto;padding:32px;text-align:center;font-family:sans-serif"><h1 style="font-size:24px;font-weight:700">Access denied</h1><p style="margin-top:8px;color:#666">Your account type is not allowed on this page.</p><a href="/" style="display:inline-block;margin-top:16px;color:#2D5A27;font-weight:600">Back to site</a></div>`;
    return null;
  }
  return { user: session.user, profile, role };
}

/* ------------------------------------------------------------------ *
 * 10. Header Authentication Manager
 * ------------------------------------------------------------------ */
class AuthHeaderManager {
  constructor() {
    this.authStatePromise = null;
    this.currentUser = null;
    this.currentProfile = null;
    this.dropdownOpen = false;
    this.authListener = null;
    this.initialized = false;
  }

  async init() {
    if (this.initialized) return;
    this.initialized = true;

    // Show loading state initially
    this.showLoadingState();

    // Initialize session
    await this.initSession();

    // Listen for auth state changes
    this.authListener = sb.auth.onAuthStateChange((event, session) => {
      this.handleAuthChange(event, session);
    });

    // Initial header render
    await this.updateHeader();
  }

  async initSession() {
    try {
      const { data: { session } } = await sb.auth.getSession();
      if (session) {
        this.currentUser = session.user;
        this.currentProfile = await this.getProfile(session.user.id);
      }
    } catch (e) {
      console.error('Session init error:', e);
    }
  }

  async getProfile(userId) {
    try {
      const { data, error } = await sb
        .from('user_profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle();
      if (error) throw error;
      return data;
    } catch (e) {
      console.error('Profile fetch error:', e);
      return null;
    }
  }

  handleAuthChange(event, session) {
    if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') {
      this.currentUser = session?.user || null;
      if (session?.user) {
        this.getProfile(session.user.id).then(profile => {
          this.currentProfile = profile;
          this.updateHeader();
        });
      } else {
        this.currentProfile = null;
        this.updateHeader();
      }
    } else if (event === 'SIGNED_OUT') {
      this.currentUser = null;
      this.currentProfile = null;
      this.updateHeader();
    }
  }

  showLoadingState() {
    const authContainer = document.getElementById('auth-buttons');
    if (authContainer) {
      authContainer.innerHTML = `
        <div class="hidden md:flex items-center justify-end gap-3 w-1/4">
          <div class="w-20 h-8 bg-gray-200 animate-pulse rounded-full"></div>
          <div class="w-24 h-8 bg-gray-200 animate-pulse rounded-full"></div>
        </div>
        <div class="md:hidden flex items-center gap-2">
          <div class="w-16 h-7 bg-gray-200 animate-pulse rounded-full"></div>
          <div class="w-20 h-7 bg-gray-200 animate-pulse rounded-full"></div>
        </div>
      `;
    }
  }

  getRoleLabel(role) {
    return ROLE_LABELS[role] || 'Organic Supplier';
  }

  getUserDisplayName() {
    if (!this.currentUser) return 'User';
    const meta = this.currentUser.user_metadata || {};
    return meta.full_name || meta.fullName || this.currentUser.email?.split('@')[0] || 'User';
  }

  getAccountType() {
    if (!this.currentProfile) return this.currentUser?.user_metadata?.account_type || 'operator';
    return this.currentProfile.account_type || this.currentProfile.role || 'operator';
  }

  getProfileCompletion() {
    if (!this.currentProfile) return 0;
    const fields = ['full_name', 'company_name', 'phone', 'address', 'city', 'state', 'business_description', 'products', 'certification_details'];
    const filled = fields.filter(f => this.currentProfile[f]).length;
    return Math.round((filled / fields.length) * 100);
  }

  buildDropdownItems() {
    const role = this.getAccountType();
    const navItems = ROLE_NAV[role] || ROLE_NAV.operator;
    const items = navItems.filter(item => item.roles.includes(this.getAccountType()) || item.roles.includes('all'));

    const profileCompletion = this.getProfileCompletion();

    return `
      <div class="absolute right-0 mt-2 w-72 bg-white rounded-xl shadow-lg border border-gray-100 py-2 shadow-xl z-50" id="user-dropdown">
        <!-- Account Header -->
        <div class="px-4 py-3 border-b border-gray-100">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 bg-green-100 rounded-full flex items-center justify-center">
              <i class="fas fa-user text-organic text-xl"></i>
            </div>
            <div class="flex-1 min-w-0">
              <p class="font-semibold text-gray-900 truncate">${this.getUserDisplayName()}</p>
              <p class="text-xs text-gray-500 capitalize">${this.getRoleLabel(this.getAccountType())}</p>
            </div>
          </div>
          <div class="mt-2 pt-2 border-t border-gray-100">
            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-500">Profile Completion</span>
              <span class="text-xs font-semibold text-organic">${this.getProfileCompletion()}%</span>
            </div>
            <div class="mt-1 h-1.5 bg-gray-100 rounded-full overflow-hidden">
              <div class="h-full bg-organic" style="width: ${this.getProfileCompletion()}%"></div>
            </div>
          </div>
        </div>

        <!-- Navigation Items -->
        <div class="py-1">
          ${items.map(item => `
            <a href="${item.href}" class="flex items-center gap-3 px-4 py-2.5 text-sm text-gray-700 hover:bg-green-50 hover:text-organic transition-colors group">
              <i class="${item.icon} text-gray-400 group-hover:text-organic transition-colors w-5"></i>
              <span>${item.label}</span>
            </a>
          `).join('')}
        </div>

        <div class="border-t border-gray-100 pt-1">
          <a href="#" onclick="window.BOMAuth.signOut().then(() => window.location.reload())" class="flex items-center gap-3 px-4 py-2.5 text-sm text-red-600 hover:bg-red-50 transition-colors">
            <i class="fas fa-sign-out-alt w-5"></i>
            <span>Logout</span>
          </a>
        </div>
      </div>
    `;
  }

  updateHeader() {
    const authContainer = document.getElementById('auth-buttons');
    if (!authContainer) return;

    if (this.currentUser) {
      const dropdownHtml = this.buildDropdownItems();
      authContainer.innerHTML = `
        <div class="hidden md:flex items-center justify-end gap-3 w-1/4" id="auth-buttons">
          <div class="relative" id="user-menu">
            <button id="user-menu-btn" class="inline-flex items-center gap-2 px-4 py-2 rounded-full text-sm font-medium text-gray-700 bg-gray-50 border border-gray-200 hover:bg-gray-100 transition focus:outline-none focus:ring-2 focus:ring-organic" aria-haspopup="true" aria-expanded="false">
              <i class="fas fa-user-circle text-organic text-lg"></i>
              <span class="font-medium text-gray-900 truncate max-w-[160px]">${this.getUserDisplayName()}</span>
              <i class="fas fa-chevron-down text-xs text-gray-400"></i>
            </button>
            ${this.buildDropdownItems()}
          </div>
        </div>
        <div class="md:hidden flex items-center gap-2">
          <div class="relative" id="user-menu-mobile">
            <button id="user-menu-btn-mobile" class="inline-flex items-center gap-2 px-3 py-2 rounded-full text-xs font-medium text-gray-700 bg-gray-100 border border-gray-200 transition focus:outline-none" aria-haspopup="true" aria-expanded="false">
              <i class="fas fa-user-circle text-organic text-lg"></i>
              <span class="font-medium text-gray-900 truncate max-w-[100px]">${this.getUserDisplayName()}</span>
              <i class="fas fa-chevron-down text-xs text-gray-400"></i>
            </button>
            ${this.buildDropdownItems()}
          </div>
        </div>
      `;
      this.attachDropdownListeners();
    } else {
      authContainer.innerHTML = `
        <div class="hidden md:flex items-center justify-end gap-3 w-1/4">
          <a href="login.html" class="inline-flex items-center gap-2 px-4 py-2 rounded-full text-sm font-medium text-gray-700 bg-gray-100 border border-gray-200 hover:bg-gray-200 transition">
            <i class="fas fa-sign-in-alt"></i> Login
          </a>
          <a href="login.html?tab=register" class="inline-flex items-center gap-2 px-5 py-2 rounded-full text-sm font-bold text-white bg-[#8B4513] hover:bg-[#7a3d11] transition">
            Join Free
          </a>
        </div>
        <div class="md:hidden flex items-center gap-2">
          <a href="login.html" class="inline-flex items-center gap-1 px-3 py-1.5 rounded-full text-xs font-medium text-gray-700 bg-gray-100 border border-gray-200 transition">
            <i class="fas fa-sign-in-alt"></i> Login
          </a>
          <a href="login.html?tab=register" class="inline-flex items-center gap-1 px-4 py-1.5 rounded-full text-xs font-bold text-white bg-[#8B4513] transition">
            Join Free
          </a>
        </div>
      `;
    }
  }

  attachDropdownListeners() {
    // Desktop dropdown
    const desktopMenu = document.getElementById('user-menu');
    const desktopBtn = document.getElementById('user-menu-btn');
    const dropdown = document.getElementById('user-dropdown');

    if (desktopBtn && dropdown) {
      desktopBtn.onclick = (e) => {
        e.stopPropagation();
        this.dropdownOpen = !this.dropdownOpen;
        dropdown.style.display = this.dropdownOpen ? 'block' : 'none';
        desktopBtn.setAttribute('aria-expanded', this.dropdownOpen);
      };
    }

    // Mobile dropdown
    const mobileMenu = document.getElementById('user-menu-mobile');
    const mobileBtn = document.getElementById('user-menu-btn-mobile');

    if (mobileBtn) {
      mobileBtn.onclick = (e) => {
        e.stopPropagation();
        this.dropdownOpen = !this.dropdownOpen;
        const mobileDropdown = document.getElementById('user-dropdown');
        if (mobileDropdown) {
          mobileDropdown.style.display = this.dropdownOpen ? 'block' : 'none';
        }
      };
    }

    // Close on outside click
    document.addEventListener('click', (e) => {
      if (this.dropdownOpen && !e.target.closest('#user-menu') && !e.target.closest('#user-menu-mobile')) {
        this.dropdownOpen = false;
        const dropdowns = document.querySelectorAll('#user-dropdown');
        dropdowns.forEach(d => d.style.display = 'none');
        document.querySelectorAll('[aria-expanded="true"]').forEach(btn => btn.setAttribute('aria-expanded', 'false'));
      }
    });

    // Close on escape
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && this.dropdownOpen) {
        this.dropdownOpen = false;
        document.querySelectorAll('#user-dropdown').forEach(d => d.style.display = 'none');
        document.querySelectorAll('[aria-expanded="true"]').forEach(btn => btn.setAttribute('aria-expanded', 'false'));
      }
    });
  }

  destroy() {
    if (this.authListener) {
      this.authListener.data.subscription.unsubscribe();
    }
  }
}

// Initialize header manager when DOM is ready
let headerManager = null;

document.addEventListener('DOMContentLoaded', async () => {
  headerManager = new AuthHeaderManager();
  await headerManager.init();
});

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
  profile: getProfile,
  isAdmin,
  requireAuth,
  redirectIfAuthenticated,
  onAuthStateChange,
  dashboardForRole,
  getProfile,
  getRoleLabel: (role) => ROLE_LABELS[role] || 'Organic Supplier',
  getAccountType: () => headerManager?.getAccountType() || 'operator',
  getProfileCompletion: () => headerManager?.getProfileCompletion() || 0
};
