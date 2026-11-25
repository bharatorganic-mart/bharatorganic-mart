# Bharat Organic Mart — Supabase Architecture Review

**Status**: For Review — No SQL Executed, No Files Modified

---

## 1. Current SQL Assessment

### Tables That Can Be Retained (With Modifications)

| Table | Retain? | Required Changes |
|-------|---------|------------------|
| `directory_listings` | ✅ Yes | Add: `source_name`, `source_url`, `source_reference`, `collected_at`, `entered_by`, `reviewed_by`, `verification_notes`, `premium_visible` flag. Remove single `product_name` (replaced by `products` table). |
| `operator_sources` | ✅ Yes | Add: `source_type`, `contact_person`, `notes` fields. |
| `profile_claims` | ✅ Yes | Add: `documents_submitted`, `review_status`, `reviewed_by`, `reviewed_at`. |
| `verification_records` | ✅ Yes | Add: `documents_reviewed`, `verification_outcome`, `next_reverification_date`. |
| `user_profiles` | ✅ Yes | Add: `membership_tier_id`, `notification_consent`, `timezone`, `paused_notifications`. |
| `products` | ✅ Yes | Add: `certification_program`, `certification_body`, `min_order_qty`, `state`, `country`, `storage_available`, `packaging_details`, `processing_details`, `available_documents`, `availability_status`, `listing_date`, `is_premium_only`. |
| `buyer_requirements` | ✅ Yes | Add: `certification_program`, `required_country`, `delivery_destination`, `required_harvest_year`, `quality_specs`, `packaging_requirements`, `expiry_date`, `is_premium_only`. |
| `admin_users` | ✅ Yes | Keep as-is. |

### Tables Requiring Replacement / Redesign

| Current Table | Issue | Replacement |
|---------------|-------|-------------|
| `notification_preferences` | Uses `TEXT[]` for categories; no global frequency separation from commodity subscriptions; no channel prefs | Split into `notification_profiles` (global settings) + `notification_subscriptions` (per-commodity/event) + `notification_channels` |
| `certification_reminders` | Too simple; no link to actual certification dates; no user subscription | Expand with `user_id`, `certification_program`, `source_date`, `verification_status` |
| `farmer_advisories` | Standalone; no user subscription linkage | Add `farmer_advisory_subscriptions` join table |

### Critical Missing Tables (Must Be Added)

| Table | Purpose |
|-------|---------|
| `commodity_categories` | Dynamic commodity/product categories (admin-managed) |
| `certification_programs` | Dynamic certification programs (NPOP, NOP, EU, etc.) |
| `membership_tiers` | Free, Premium, Enterprise plans with entitlements |
| `user_memberships` | Links users to membership tiers with start/end dates |
| `notification_profiles` | ONE global profile per user: frequency, timezone, consent, paused status |
| `notification_subscriptions` | Per-commodity/event subscriptions linked to notification profile |
| `notification_channels` | Email, web (future WhatsApp) preferences per user |
| `notification_events` | Generated events from marketplace actions (new product, new RFQ, etc.) |
| `notification_queue` | Pending deliveries with user_id, event_id, scheduled_for, status |
| `notification_delivery_log` | History of sent/failed deliveries |
| `email_templates` | Subject/body templates for each notification type |
| `farmer_advisory_subscriptions` | User crop+location preferences for advisories |
| `audit_log` | Immutable log of important data changes |
| `excel_import_batches` | Track Excel workbook imports (file, imported_by, record_count, status) |

---

## 2. Global Delivery Frequency — Current Gap

**Current SQL**: `notification_preferences.frequency` is a single column on the preferences table.

**Required**: ONE global frequency per user (`instant` | `daily` | `weekly`) that applies to ALL enabled notification types.

**Fix**: Move `frequency`, `timezone`, `paused`, `email_consent` to `notification_profiles` (one row per user). Subscriptions in `notification_subscriptions` only store WHAT the user wants (commodities, event types), not HOW OFTEN.

---

## 3. Dynamic Category Expansion — Current Gap

**Current SQL**: `operator_type_enum` and `certification_scope_enum` are hardcoded PostgreSQL ENUMs.

**Required**: Admin must add categories without database migrations.

**Fix**: Replace ENUMs with reference tables:
- `operator_categories` (replaces `operator_type_enum`)
- `certification_programs` (replaces `certification_scope_enum`)
- `commodity_categories` (for products and notifications)

---

## 4. Manual Excel Import & Verification Workflow — Current Gap

**Current SQL**: `operator_sources` exists but lacks audit fields.

**Required Fields for `directory_listings`**:
```sql
source_name TEXT,              -- e.g., 'APEDA NPOP'
source_url TEXT,
source_reference TEXT,         -- certificate number, operator ID from source
collected_at TIMESTAMPTZ,
entered_by UUID REFERENCES admin_users(id),
reviewed_by UUID REFERENCES admin_users(id),
reviewed_at TIMESTAMPTZ,
verification_notes TEXT,
internal_verification_status TEXT, -- 'pending_review', 'verified', 'rejected'
verification_date TIMESTAMPTZ
```

**New Table**: `excel_import_batches` for tracking workbook imports.

---

## 5. Free vs Premium Access — Current Gap

**Current SQL**: No membership model; RLS policies don't distinguish premium content.

**Required**:
- `membership_tiers` table with `entitlements` JSONB (e.g., `{"view_contact": true, "view_full_products": true}`)
- `user_memberships` linking users to tiers with `status`, `starts_at`, `ends_at`, `payment_reference`
- RLS policies on `directory_listings`, `products`, `buyer_requirements` that check `membership_tier` entitlements via `auth.jwt()` or SECURITY DEFINER functions

---

## 6. Consolidated Revised Architecture

### A. Reference Tables (Admin-Managed, Dynamic)

```sql
operator_categories (id, name, description, display_order, is_active)
certification_programs (id, code, name, description, is_active)
commodity_categories (id, code, name, parent_id, description, is_active)
membership_tiers (id, name, slug, monthly_price, annual_price, entitlements_jsonb, is_active)
email_templates (id, template_key, subject, body_html, body_text, variables_jsonb, is_active)
```

### B. Core Operator & Marketplace Tables

```sql
directory_listings (
  id, operator_category_id, name, slug,
  registered_address, facility_address, city, state, country, postal_code,
  contact_person, phone, email, website,
  -- Certification (normalized)
  certifications JSONB, -- [{program_id, body, status, date, scope}]
  -- Land & crops
  certified_land_area, organic_crops, crop_certification_status,
  grower_group_indicator, certified_area,
  -- Source audit
  source_id, source_name, source_url, source_reference, collected_at,
  entered_by, reviewed_by, reviewed_at, verification_notes,
  internal_verification_status, verification_date,
  -- Status
  is_demo_data, publication_status, approval_status,
  verification_status, -- 'Unclaimed'|'Claimed'|'Verification Pending'|...
  approved_by, approved_at, rejection_reason,
  premium_visible, -- controls premium-only fields
  created_at, updated_at
)

products (
  id, operator_id, commodity_category_id, product_name, variety,
  certification_program_id, certification_body, certification_status,
  available_quantity, unit, min_order_qty, price, price_on_request,
  state, country, harvest_year, harvest_month, expected_harvest_date,
  production_location, storage_available, packaging_details, processing_details,
  available_documents, listing_date, availability_status,
  is_premium_only, created_at, updated_at
)

buyer_requirements (
  id, buyer_id, commodity_category_id, title, required_quantity, unit,
  certification_program_id, required_country, delivery_destination,
  required_harvest_year, quality_specs, packaging_requirements,
  expected_delivery_date, contact_details, expiry_date,
  is_premium_only, status, created_at
)
```

### C. User & Membership Tables

```sql
user_profiles (
  id (FK auth.users), full_name, role, phone, company_name,
  membership_tier_id, membership_status, membership_starts_at, membership_ends_at,
  notification_consent, email_consent, timezone, paused_notifications,
  created_at, updated_at
)

user_memberships (
  id, user_id, membership_tier_id, status, starts_at, ends_at,
  payment_reference, auto_renew, created_at
)
```

### D. Notification System (Normalized)

```sql
notification_profiles (
  user_id PK, global_frequency ('instant'|'daily'|'weekly'), timezone,
  email_consent, web_consent, paused, created_at, updated_at
)

notification_subscriptions (
  id, user_id, subscription_type ('commodity'|'event'|'advisory'|'certification'),
  reference_id, -- commodity_category_id, or event_type, or advisory_crop_id
  filters_jsonb, -- {certification: [...], min_qty: ..., state: ..., operator_types: [...]}
  enabled, created_at
)

notification_channels (
  user_id, channel ('email'|'web'|'whatsapp'), enabled, created_at
)

notification_events (
  id, event_type ('new_product'|'new_rfq'|'new_supplier'|'certification_reminder'|'advisory'),
  source_table, source_id, payload_jsonb, created_at
)

notification_queue (
  id, user_id, event_id, channel, scheduled_for, status ('pending'|'sent'|'failed'),
  attempts, last_error, sent_at
)

notification_delivery_log (
  id, user_id, event_id, channel, status, sent_at, error_message
)
```

### E. Claims, Verification & Audit

```sql
profile_claims (
  id, listing_id, user_id, status ('pending'|'approved'|'rejected'),
  documents_submitted, reviewed_by, reviewed_at, review_notes, claimed_at
)

verification_records (
  id, listing_id, verified_by, verification_date,
  documents_reviewed, verification_outcome, next_reverification_date, notes
)

audit_log (
  id, table_name, record_id, action ('INSERT'|'UPDATE'|'DELETE'),
  old_data_jsonb, new_data_jsonb, changed_by, changed_at
)

excel_import_batches (
  id, filename, imported_by, total_rows, successful_rows, failed_rows,
  error_details_jsonb, status, started_at, completed_at
)
```

### F. Certification Reminders & Advisories

```sql
certification_reminders (
  id, listing_id, user_id, certification_program_id,
  source_date, reminder_type ('renewal'|'inspection'|'expiry'),
  due_date, verification_status ('verified'|'pending'), is_sent, sent_at
)

farmer_advisories (
  id, title, commodity_category_id, crop_name, location, season,
  sowing_month, content, source_reference, source_url, published_at
)

farmer_advisory_subscriptions (
  id, user_id, commodity_category_id, crop_name, location, enabled
)
```

---

## 7. Key Relationships

```
auth.users
  │
  ├─► user_profiles (1:1)
  │       └─► user_memberships (1:N) ──► membership_tiers
  │       └─► notification_profiles (1:1)
  │       └─► notification_subscriptions (1:N)
  │       └─► notification_channels (1:N)
  │       └─► farmer_advisory_subscriptions (1:N)
  │
  ├─► directory_listings (claimed_by user_id via profile_claims)
  │       ├─► operator_categories (N:1)
  │       ├─► operator_sources (N:1)
  │       ├─► products (1:N) ──► commodity_categories (N:1)
  │       ├─► profile_claims (1:N)
  │       ├─► verification_records (1:N)
  │       └─► certification_reminders (1:N)
  │
  ├─► buyer_requirements (1:N) ──► commodity_categories (N:1)
  │
  └─► admin_users (1:1) ──► manages all
```

---

## 8. Security & RLS Strategy

| Table | Public (anon) | Registered Free | Premium | Admin |
|-------|---------------|-----------------|---------|-------|
| `directory_listings` | Name, category, city, basic cert, verification_status | + contact info if claimed/verified | + all fields | All |
| `products` | Basic public listings | + quantity, harvest info | + price, min_order, full docs | All |
| `buyer_requirements` | None | Title, category, qty | + contact, full specs | All |
| `notification_*` | None | Own only | Own only | All |

**Implementation**: Use SECURITY DEFINER functions for RLS checks that evaluate `user_memberships` + `membership_tiers.entitlements`.

---

## 9. Implementation Phases

| Phase | Scope | Dependencies |
|-------|-------|--------------|
| 1 | Core schema: reference tables, directory_listings, user_profiles, admin_users | None |
| 2 | Products, buyer_requirements, operator_sources, profile_claims, verification_records | Phase 1 |
| 3 | Membership tiers, user_memberships, premium RLS policies | Phase 1 |
| 4 | Notification system: profiles, subscriptions, channels, events, queue, templates | Phase 1-2 |
| 5 | Certification reminders, farmer advisories, audit_log, excel_import_batches | Phase 1-2 |
| 6 | Edge Functions for notification processor, digest scheduler, email delivery | Phase 4 |
| 7 | Website integration: directory/index.html → Supabase, claims UI, product UI | Phase 1-3 |

---

## 10. Risks & Limitations

| Risk | Mitigation |
|------|------------|
| ENUM migration requires data conversion | Use `ALTER TYPE ... ADD VALUE` for new enum values; plan for table-backed refs in Phase 2 |
| Notification queue scaling | Use pg_cron or pg_partman for `notification_queue` partitioning |
| Email deliverability | Abstract email provider via `email_templates` + Edge Function; support SendGrid/Resend/SES |
| Premium RLS complexity | Keep RLS simple; use Postgres functions for entitlement checks |
| Manual Excel import errors | `excel_import_batches` + validation in Edge Function before insert |

---

## 11. Estimated Ongoing Costs (Supabase)

| Resource | Estimate |
|----------|----------|
| Database (Pro plan) | $25/mo |
| Auth (MAU) | Included |
| Edge Functions (invocations) | ~$2-5/mo for notification processing |
| Email (Resend/SendGrid) | $10-50/mo depending on volume |
| Storage (documents) | $0.021/GB |

---

## 12. Next Steps (Awaiting Your Approval)

1. **Approve this consolidated architecture**
2. I will produce the **complete revised `001_initial_schema.sql`** with all tables, RLS, functions, and triggers
3. You execute the migration in Supabase Dashboard
4. We proceed to Phase 2: Website integration

**Please confirm approval or request changes.**