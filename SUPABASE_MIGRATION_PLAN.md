# Supabase Migration Plan — Bharat Organic Mart

## Project Structure Overview

| File | Purpose |
|------|---------|
| `index.html` | Homepage with navigation, mega menu, hero video |
| `directory/index.html` | Marketplace directory page (currently loads `clean_listings.json`) |
| `data/clean_listings.json` | Static JSON source of 7 demo listings |
| `certification/npop-certification-bodies.html` | Certification bodies directory |
| `learning-centre/how-to-get-organic-certification-in-india.html` | Learning centre article |

---

## Migration Plan

### Phase 1: Supabase Project Setup (No Website Changes)

Create the following in your Supabase project:

**Database Table: `directory_listings`**
```sql
CREATE TABLE directory_listings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  operator_type TEXT NOT NULL,
  name TEXT NOT NULL,
  address TEXT,
  scope_1 TEXT,
  cert_body_1 TEXT,
  scope_2 TEXT,
  cert_body_2 TEXT,
  scope_3 TEXT,
  cert_body_3 TEXT,
  country TEXT,
  state TEXT,
  city TEXT,
  facility_address TEXT,
  postal_code TEXT,
  contact_person TEXT,
  phone TEXT,
  email TEXT,
  website TEXT,
  product_name TEXT,
  certification_status TEXT,
  certification_date DATE,
  last_updated DATE,
  certified_land_area TEXT,
  organic_crops TEXT,
  crop_certification_status TEXT,
  grower_group_indicator TEXT,
  certified_area TEXT,
  is_demo_data BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

**Row Level Security (RLS)**
```sql
-- Enable RLS
ALTER TABLE directory_listings ENABLE ROW LEVEL SECURITY;

-- Public read access (anyone can view listings)
CREATE POLICY "Public read access" ON directory_listings
  FOR SELECT USING (true);

-- Admin write access (only authenticated admins)
CREATE POLICY "Admin write access" ON directory_listings
  FOR ALL USING (auth.role() = 'authenticated' AND EXISTS (
    SELECT 1 FROM admin_users WHERE id = auth.uid()
  ));
```

**Admin Users Table**
```sql
CREATE TABLE admin_users (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  role TEXT DEFAULT 'admin',
  created_at TIMESTAMPTZ DEFAULT now()
);
```

---

### Phase 2: Connect Website to Supabase

**Files to Modify:**
- `directory/index.html` — replace `fetch('../data/clean_listings.json')` with Supabase client fetch
- `index.html` — may need Supabase client script tags added

**Supabase Client Configuration:**
Include the Supabase JS library via CDN in `directory/index.html`:
```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
```

Initialize client:
```javascript
const SUPABASE_URL = 'https://your-project-ref.supabase.co';
const SUPABASE_ANON_KEY = 'your-public-anon-key';
const supabase = supabaseClient(SUPABASE_URL, SUPABASE_ANON_KEY);
```

**Replace JSON Loading Logic:**
```javascript
async function loadListings() {
  const { data, error } = await supabase
    .from('directory_listings')
    .select('*')
    .eq('is_demo_data', true);  // or remove for production data
  
  if (error) throw error;
  allListings = data;
  // ... rest of existing filter/render logic unchanged
}
```

**Preserved Functionality:**
- All 7 category tabs (`operator_type` field)
- Keyword search (name, product_name, organic_crops, city)
- State filter (from `state` column)
- Scope filter (from `scope_1`, `scope_2`, `scope_3`)
- Demo Record badges (from `is_demo_data` column)
- Navigation links (unchanged)

---

### Phase 3: Data Migration

Export 7 records from `data/clean_listings.json` and insert into `directory_listings` table via:
- Supabase Dashboard → Table Editor → Insert rows
- OR via SQL INSERT statements
- OR via Supabase CLI bulk import

Do **not** delete `data/clean_listings.json` yet — keep as backup.

---

### Phase 4: Admin Authentication & Dashboard (Later)

**Supabase Auth Configuration:**
- Enable email/password auth in Supabase Dashboard
- Create admin user accounts via Supabase Auth or manually

**Admin Dashboard Page:**
- New file: `admin/index.html` (protected route)
- Features: Add/edit/delete listings, toggle demo status
- Protected by checking `auth.role()` and admin_users table

**RLS Policies:**
- Only admins can INSERT/UPDATE/DELETE
- Public can only SELECT

---

### Phase 5: GitHub Pages Compatibility

**No server-side code needed.** The website remains static HTML/JS. Supabase is accessed via:
- CDN-loaded JavaScript library
- HTTPS API calls from the browser
- Anon key (safe for client-side use with RLS)

**No build step required.** GitHub Pages serves static files directly.

---

### Files to NOT Modify Yet

| File | Reason |
|------|--------|
| `index.html` | Homepage — only add Supabase script tags if needed later |
| `certification/npop-certification-bodies.html` | Separate certification directory, out of scope |
| `learning-centre/` | Out of scope |
| `data/clean_listings.json` | Keep as backup during migration |

---

### Testing Checklist

Before going live:
- [ ] Website loads on GitHub Pages without console errors
- [ ] All 7 listings display from Supabase (not JSON)
- [ ] All 7 category tabs filter correctly
- [ ] Search, state, and scope filters work
- [ ] RLS blocks unauthorized writes
- [ ] Admin login works (later phase)

---

**Next step:** When you're ready, share your Supabase project URL and anon key so I can prepare the exact code changes for `directory/index.html`.