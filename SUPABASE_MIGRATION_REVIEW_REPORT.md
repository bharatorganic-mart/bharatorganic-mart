# Bharat Organic Mart — Supabase Database Architecture
## Complete Revised Migration Summary

**File**: `supabase/migrations/001_initial_schema.sql`  
**Backup**: `supabase/migrations/001_initial_schema.sql.backup`  
**Status**: FOR REVIEW ONLY — NOT EXECUTED

---

## 📊 Table-by-Table Schema (26 Tables)

### 1. Reference Tables (Admin-Managed, Dynamic)

| Table | PK | Key Fields | Purpose |
|-------|----|------------|---------|
| `operator_categories` | `id` (UUID) | `code` (UNIQUE), `name`, `display_order`, `is_active` | Replaces hardcoded enum; 7 initial categories seeded |
| `certification_programs` | `id` (UUID) | `code` (UNIQUE), `name`, `country`, `is_active` | Replaces hardcoded enum; NPOP, NOP, EU, PGS-India, FSSAI seeded |
| `commodity_categories` | `id` (UUID) | `code` (UNIQUE), `name`, `parent_id` (FK self), `display_order` | Hierarchical product categories; supports sub-categories |
| `membership_tiers` | `id` (UUID) | `slug` (UNIQUE), `monthly_price`, `annual_price`, `entitlements` (JSONB) | Free, Premium, Enterprise with entitlements |
| `email_templates` | `id` (UUID) | `template_key` (UNIQUE), `subject`, `body_html`, `variables` (JSONB) | Notification email templates |

### 2. Core Auth & User Tables

| Table | PK | Key Fields | Purpose |
|-------|----|------------|---------|
| `admin_users` | `id` (FK→auth.users) | `email`, `role` (admin/super_admin), `is_active` | Admin management |
| `user_profiles` | `id` (FK→auth.users) | `role`, `membership_tier_id`, `membership_status`, `email_consent`, `timezone` | Extended profile |
| `user_memberships` | `id` (UUID) | `user_id`, `membership_tier_id`, `status`, `starts_at`, `ends_at`, `payment_reference` | Membership history & current |

### 3. Operator Source & Import Tracking

| Table | PK | Key Fields | Purpose |
|-------|----|------------|---------|
| `operator_sources` | `id` (UUID) | `source_name`, `source_type`, `source_url`, `is_active` | APEDA, USDA NOP, certification bodies |
| `excel_import_batches` | `id` (UUID) | `filename`, `imported_by`, `source_id`, `total_rows`, `successful_rows`, `failed_rows`, `error_details`, `status` | Manual Excel import audit trail |

### 4. Main Directory & Verification

| Table | PK | Key Fields | Purpose |
|-------|----|------------|---------|
| `directory_listings` | `id` (UUID) | `operator_category_id` (FK), `name`, `slug` (STORED), addresses, contact, `certifications` (JSONB), `source_*` audit fields, `internal_verification_status`, `verification_status`, `publication_status`, `approval_status`, `premium_visible` | Core operator directory with full manual import audit |
| `profile_claims` | `id` (UUID) | `listing_id` (FK), `user_id` (FK), `status` (claim_status_enum), `documents_submitted` (JSONB), `reviewed_by`, `reviewed_at` | Operator profile claiming workflow |
| `verification_records` | `id` (UUID) | `listing_id` (FK), `verified_by` (FK), `verification_outcome`, `next_reverification_date` | Bharat Organic Mart verification audit trail |

### 5. Marketplace

| Table | PK | Key Fields | Purpose |
|-------|----|------------|---------|
| `products` | `id` (UUID) | `operator_id` (FK), `commodity_category_id` (FK), `product_name`, `variety`, `certification_program_id` (FK), `available_quantity`, `unit`, `min_order_qty`, `price`, `price_on_request`, `state`, `country`, `harvest_year`, `harvest_month`, `expected_harvest_date`, `storage_available`, `packaging_details`, `processing_details`, `available_documents` (JSONB), `availability_status`, `is_premium_only` | Full product listings |
| `buyer_requirements` | `id` (UUID) | `buyer_id` (FK), `commodity_category_id` (FK), `title`, `required_quantity`, `unit`, `certification_program_id` (FK), `required_country`, `delivery_destination`, `required_harvest_year`, `quality_specs`, `packaging_requirements`, `expected_delivery_date`, `expiry_date`, `contact_details` (JSONB), `is_premium_only`, `status` | Buyer RFQs |
| `supplier_responses` | `id` (UUID) | `requirement_id` (FK), `operator_id` (FK), `product_id` (FK), `message`, `offered_quantity`, `offered_price`, `status` | Supplier responses to RFQs |

### 6. Notification System (Normalized)

| Table | PK | Key Fields | Purpose |
|-------|----|------------|---------|
| `notification_profiles` | `user_id` (FK→auth.users, PK) | `global_frequency` (instant/daily/weekly), `timezone`, `email_consent`, `web_consent`, `paused` | **ONE global profile per user** |
| `notification_subscriptions` | `id` (UUID) | `user_id` (FK), `subscription_type`, `reference_id`, `reference_table`, `filters` (JSONB), `enabled` | WHAT user wants (commodities, events, etc.) |
| `notification_channels` | `(user_id, channel)` PK | `channel` (email/web/whatsapp), `enabled` | WHERE user wants notifications |
| `notification_events` | `id` (UUID) | `event_type` (enum), `source_table`, `source_id`, `payload` (JSONB) | Generated marketplace events |
| `notification_queue` | `id` (UUID) | `user_id` (FK), `event_id` (FK), `channel`, `scheduled_for`, `status` (pending/sent/failed), `attempts` | Scheduled deliveries |
| `notification_delivery_log` | `id` (UUID) | `user_id` (FK), `event_id` (FK), `channel`, `status`, `error_message`, `sent_at` | Delivery history |

### 7. Certification & Advisory

| Table | PK | Key Fields | Purpose |
|-------|----|------------|---------|
| `certification_reminders` | `id` (UUID) | `listing_id` (FK), `user_id` (FK), `certification_program_id` (FK), `reminder_type` (enum), `source_date`, `due_date`, `verification_status`, `is_sent` | Automated reminders from verified dates only |
| `farmer_advisories` | `id` (UUID) | `commodity_category_id` (FK), `crop_name`, `location`, `season`, `sowing_month`, `title`, `content`, `source_reference`, `source_url`, `published_at` | Agricultural advisories |
| `farmer_advisory_subscriptions` | `id` (UUID) | `user_id` (FK), `commodity_category_id` (FK), `crop_name`, `location`, `enabled` | User advisory preferences |

### 8. Audit

| Table | PK | Key Fields | Purpose |
|-------|----|------------|---------|
| `audit_log` | `id` (UUID) | `table_name`, `record_id`, `action`, `old_data` (JSONB), `new_data` (JSONB), `changed_by` (FK), `changed_at` | Immutable audit trail |

---

## 🔑 Primary & Foreign Keys Summary

| Table | PK | Important FKs |
|-------|----|---------------|
| `operator_categories` | `id` | — |
| `certification_programs` | `id` | — |
| `commodity_categories` | `id` | `parent_id` → `commodity_categories(id)` |
| `membership_tiers` | `id` | — |
| `admin_users` | `id` | `id` → `auth.users(id)` |
| `user_profiles` | `id` | `id` → `auth.users(id)`, `membership_tier_id` → `membership_tiers(id)` |
| `user_memberships` | `id` | `user_id` → `auth.users(id)`, `membership_tier_id` → `membership_tiers(id)` |
| `operator_sources` | `id` | — |
| `excel_import_batches` | `id` | `imported_by` → `admin_users(id)`, `source_id` → `operator_sources(id)` |
| `directory_listings` | `id` | `operator_category_id` → `operator_categories(id)`, `source_id` → `operator_sources(id)`, `entered_by` → `admin_users(id)`, `reviewed_by` → `admin_users(id)`, `approved_by` → `admin_users(id)` |
| `profile_claims` | `id` | `listing_id` → `directory_listings(id)`, `user_id` → `auth.users(id)`, `reviewed_by` → `admin_users(id)` |
| `verification_records` | `id` | `listing_id` → `directory_listings(id)`, `verified_by` → `admin_users(id)` |
| `products` | `id` | `operator_id` → `directory_listings(id)`, `commodity_category_id` → `commodity_categories(id)`, `certification_program_id` → `certification_programs(id)` |
| `buyer_requirements` | `id` | `buyer_id` → `auth.users(id)`, `commodity_category_id` → `commodity_categories(id)`, `certification_program_id` → `certification_programs(id)` |
| `supplier_responses` | `id` | `requirement_id` → `buyer_requirements(id)`, `operator_id` → `directory_listings(id)`, `product_id` → `products(id)` |
| `notification_profiles` | `user_id` | `user_id` → `auth.users(id)` |
| `notification_subscriptions` | `id` | `user_id` → `auth.users(id)` |
| `notification_channels` | `(user_id, channel)` | `user_id` → `auth.users(id)` |
| `notification_events` | `id` | — |
| `notification_queue` | `id` | `user_id` → `auth.users(id)`, `event_id` → `notification_events(id)` |
| `notification_delivery_log` | `id` | `user_id` → `auth.users(id)`, `event_id` → `notification_events(id)` |
| `certification_reminders` | `id` | `listing_id` → `directory_listings(id)`, `user_id` → `auth.users(id)`, `certification_program_id` → `certification_programs(id)` |
| `farmer_advisories` | `id` | `commodity_category_id` → `commodity_categories(id)` |
| `farmer_advisory_subscriptions` | `id` | `user_id` → `auth.users(id)`, `commodity_category_id` → `commodity_categories(id)` |
| `audit_log` | `id` | `changed_by` → `auth.users(id)` |

---

## 🛡️ RLS Policies & Security Functions

### Security Definer Functions (Premium Access Control)
| Function | Purpose |
|----------|---------|
| `has_entitlement(user_id, entitlement)` | Checks user's active membership tier entitlements JSONB |
| `can_view_premium(user_id)` | Shortcut for `view_full_products` entitlement |
| `can_view_contact(user_id)` | Shortcut for `view_contact` entitlement |
| `is_admin(user_id)` | Checks `admin_users` table |
| `is_super_admin(user_id)` | Checks `admin_users` with `role = 'super_admin'` |

### RLS Policy Matrix

| Table | Public (anon) | Free Registered | Premium | Operator (Owner) | Buyer (Owner) | Admin |
|-------|---------------|-----------------|---------|------------------|---------------|-------|
| `operator_categories` | ✅ READ (active) | ✅ READ | ✅ READ | — | — | ✅ ALL |
| `certification_programs` | ✅ READ (active) | ✅ READ | ✅ READ | — | — | ✅ ALL |
| `commodity_categories` | ✅ READ (active) | ✅ READ | ✅ READ | — | — | ✅ ALL |
| `membership_tiers` | ✅ READ (active) | ✅ READ | ✅ READ | — | — | ✅ ALL |
| `directory_listings` | ✅ READ (published+approved OR Unclaimed) | ✅ READ (own if claimed) | ✅ READ (own + premium fields via app) | ✅ READ/UPDATE own | — | ✅ ALL |
| `products` | ✅ READ (non-premium, approved listings) | ✅ READ (same) | ✅ READ (ALL approved listings) | ✅ ALL own | — | ✅ ALL |
| `buyer_requirements` | ❌ | ✅ READ (open, non-premium) | ✅ READ (ALL open) | — | ✅ ALL own | ✅ ALL |
| `supplier_responses` | ❌ | ❌ | ❌ | ✅ ALL own | ✅ READ to own RFQs | ✅ ALL |
| `user_profiles` | ❌ | ✅ READ/UPDATE own | ✅ READ/UPDATE own | ✅ READ/UPDATE own | ✅ READ/UPDATE own | ✅ READ ALL |
| `user_memberships` | ❌ | ✅ READ own | ✅ READ own | ✅ READ own | ✅ READ own | ✅ ALL |
| `profile_claims` | ❌ | ✅ READ/INSERT own | ✅ READ/INSERT own | ✅ READ/INSERT own | ✅ READ/INSERT own | ✅ ALL |
| `verification_records` | ❌ | ❌ | ❌ | — | — | ✅ ALL |
| `notification_profiles` | ❌ | ✅ ALL own | ✅ ALL own | ✅ ALL own | ✅ ALL own | ✅ ALL (admin) |
| `notification_subscriptions` | ❌ | ✅ ALL own | ✅ ALL own | ✅ ALL own | ✅ ALL own | ✅ ALL |
| `notification_channels` | ❌ | ✅ ALL own | ✅ ALL own | ✅ ALL own | ✅ ALL own | ✅ ALL |
| `notification_events` | ❌ | ❌ | ❌ | — | — | ✅ READ |
| `notification_queue` | ❌ | ✅ READ own | ✅ READ own | ✅ READ own | ✅ READ own | ✅ ALL |
| `notification_delivery_log` | ❌ | ✅ READ own | ✅ READ own | ✅ READ own | ✅ READ own | ✅ ALL |
| `certification_reminders` | ❌ | ✅ READ own | ✅ READ own | — | — | ✅ ALL |
| `farmer_advisories` | ✅ READ (active) | ✅ READ | ✅ READ | — | — | ✅ ALL |
| `farmer_advisory_subscriptions` | ❌ | ✅ ALL own | ✅ ALL own | ✅ ALL own | ✅ ALL own | ✅ ALL |
| `audit_log` | ❌ | ❌ | ❌ | — | — | ✅ READ |
| `excel_import_batches` | ❌ | ❌ | ❌ | — | — | ✅ ALL |

### Public Views (Column-Level Security)
- `public_directory_listings` — Hides `contact_person`, `phone`, `email` unless `premium_visible = true` (app layer enforces)
- `public_products` — Basic product info only; `is_premium_only` flag for app to restrict

---

## 📈 Indexes & Constraints

### Key Indexes
| Table | Index | Type |
|-------|-------|------|
| `directory_listings` | `idx_dir_operator_category` | BTREE |
| `directory_listings` | `idx_dir_state` | BTREE |
| `directory_listings` | `idx_dir_verification_status` | BTREE |
| `directory_listings` | `idx_dir_publication_approval` | BTREE (composite) |
| `directory_listings` | `idx_dir_search` | GIN (tsvector) |
| `products` | `idx_products_operator` | BTREE |
| `products` | `idx_products_commodity` | BTREE |
| `products` | `idx_products_availability` | BTREE |
| `products` | `idx_products_premium` | BTREE |
| `buyer_requirements` | `idx_buyer_req_buyer` | BTREE |
| `buyer_requirements` | `idx_buyer_req_commodity` | BTREE |
| `notification_queue` | `idx_notif_queue_scheduled` | BTREE (scheduled_for, status) |
| `notification_queue` | `idx_notif_queue_user` | BTREE (user_id, status) |
| `certification_reminders` | `idx_cert_reminders_due` | BTREE (due_date, is_sent) |
| `audit_log` | `idx_audit_log_table_record` | BTREE (table_name, record_id) |

### Constraints
- **UNIQUE**: `operator_categories.code`, `certification_programs.code`, `commodity_categories.code`, `membership_tiers.slug`, `email_templates.template_key`, `profile_claims(listing_id, user_id)`, `notification_subscriptions(user_id, subscription_type, reference_id, reference_table)`, `notification_channels(user_id, channel)`, `farmer_advisory_subscriptions(user_id, commodity_category_id, crop_name, location)`
- **CHECK**: Enum validations on status fields, role fields
- **FK CASCADE**: `ON DELETE CASCADE` on auth-linked tables, `ON DELETE SET NULL` where appropriate

---

## 🗺️ Database Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           auth.users (Supabase Auth)                        │
└─────────┬───────────────────┬───────────────────────┬─────────────────────┘
          │                   │                       │
          ▼                   ▼                       ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ ┌──────────────┐
│  admin_users    │ │ user_profiles   │ │ notification_   │ │ buyer_       │
│  (1:1)          │ │ (1:1)           │ │ profiles (1:1)  │ │ requirements │
└────────┬────────┘ └───────┬─────────┘ └────────┬────────┘ └──────┬───────┘
         │                  │                    │                 │
         │                  │                    │                 │
         ▼                  ▼                    ▼                 ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ ┌──────────────┐
│ directory_      │ │ user_           │ │ notification_   │ │ supplier_    │
│ listings        │ │ memberships     │ │ subscriptions   │ │ responses    │
│ (N:1 operator_  │ │ (1:N)           │ │ (1:N)           │ │ (N:1)        │
│  categories)    │ │                 │ │                 │ │              │
└────────┬────────┘ └─────────────────┘ └────────┬────────┘ └──────────────┘
         │                                        │
         ▼                                        ▼
┌─────────────────┐                    ┌─────────────────┐
│ products        │                    │ notification_   │
│ (N:1 commodity_ │                    │ queue           │
│  categories)    │                    │ (N:1 user,      │
│                 │                    │  N:1 events)    │
└────────┬────────┘                    └────────┬────────┘
         │                                        │
         ▼                                        ▼
┌─────────────────┐                    ┌─────────────────┐
│ supplier_       │                    │ notification_   │
│ responses       │                    │ delivery_log    │
└─────────────────┘                    └─────────────────┘

OTHER KEY RELATIONSHIPS:
├── directory_listings ←→ profile_claims (1:N) ←→ auth.users
├── directory_listings ←→ verification_records (1:N)
├── directory_listings ←→ certification_reminders (1:N)
├── directory_listings ←→ operator_sources (N:1)
├── excel_import_batches → operator_sources (N:1)
├── excel_import_batches → admin_users (N:1)
├── farmer_advisories ←→ commodity_categories (N:1)
├── farmer_advisories ←→ farmer_advisory_subscriptions (1:N) ←→ auth.users
├── products ←→ commodity_categories (N:1)
├── products ←→ certification_programs (N:1)
├── buyer_requirements ←→ commodity_categories (N:1)
├── buyer_requirements ←→ certification_programs (N:1)
└── audit_log ←→ all critical tables (via triggers)
```

---

## ⚠️ Assumptions & Limitations

| Area | Assumption / Limitation |
|------|------------------------|
| **Email Delivery** | Handled via Supabase Edge Functions (not in SQL); requires external provider (Resend/SendGrid/SES) |
| **Digest Scheduling** | `notification_queue.scheduled_for` populated by Edge Function cron; `pg_cron` extension recommended |
| **File Uploads** | Documents stored in Supabase Storage; URLs saved in JSONB fields |
| **Search** | PostgreSQL `tsvector` used; for production scale consider pg_trgm or external search (Meilisearch/Typesense) |
| **Real-time** | Supabase Realtime can be enabled on tables for live UI updates |
| **Migration Path** | ENUMs used for static workflows; reference tables for dynamic categories; data migration needed if changing ENUM values |
| **Backup/Restore** | Supabase handles PITR; `audit_log` provides application-level audit |
| **Multi-tenancy** | Not implemented; single marketplace |
| **Internationalization** | `country` fields present; `timezone` on notification_profiles; UI translations not in DB |
| **Payment Integration** | `user_memberships.payment_reference` links to external payment provider (Razorpay/Stripe) |

---

## 📝 Changes from Previous Migration

| Category | Change |
|----------|--------|
| **Enums → Reference Tables** | `operator_type_enum` → `operator_categories`; `certification_scope_enum` → `certification_programs`; Added `commodity_categories` |
| **Notification System** | Single `notification_preferences` → Normalized: `notification_profiles` (global frequency), `notification_subscriptions` (what), `notification_channels` (where), `notification_events` (source), `notification_queue` (schedule), `notification_delivery_log` (history) |
| **Premium Membership** | Added `membership_tiers`, `user_memberships`, entitlements JSONB, SECURITY DEFINER functions (`has_entitlement`, `can_view_premium`, `can_view_contact`), premium RLS policies |
| **Manual Import Audit** | Added `source_name`, `source_url`, `source_reference`, `collected_at`, `entered_by`, `reviewed_by`, `reviewed_at`, `verification_notes`, `internal_verification_status`, `verification_date` to `directory_listings`; Added `excel_import_batches` |
| **Verification Workflow** | Enhanced `profile_claims` (documents_submitted, review_status); Enhanced `verification_records` (outcome, next_reverification_date) |
| **Products** | Added 15+ fields: certification_program/body, min_order_qty, harvest_month, expected_harvest_date, storage, packaging, processing, documents, premium flag |
| **Buyer Requirements** | Added 9+ fields: certification_program, required_country, delivery_destination, harvest_year, quality_specs, packaging, expiry, premium flag |
| **Certification Reminders** | Added `user_id`, `certification_program_id`, `source_date`, `verification_status` |
| **Advisories** | Added `farmer_advisory_subscriptions` join table |
| **Audit** | Added `audit_log` with generic trigger function on 8 key tables |
| **Public Views** | `public_directory_listings`, `public_products` with column-level security |
| **Triggers** | `updated_at` on all mutable tables; `audit_trigger_function` on key tables |

---

## ✅ Requirements Compliance Checklist

| # | Requirement | Status |
|---|-------------|--------|
| 1 | 7 operator categories retained, dynamic expansion | ✅ `operator_categories` table with 7 seeded |
| 2 | Commodity, products, certifications dynamic | ✅ `commodity_categories`, `certification_programs` |
| 3 | Manual Excel import, no auto-scraping | ✅ `excel_import_batches`, `operator_sources`, audit fields |
| 4 | Excel import batch history, source refs, review | ✅ `excel_import_batches`, `directory_listings` source fields |
| 5 | Unclaimed→Claimed→Verification→Verified workflow | ✅ `verification_status` enum + `profile_claims` + `verification_records` |
| 6 | Product listings with qty, unit, MOQ, cert, harvest, location, packaging | ✅ `products` table (15+ fields) |
| 7 | Buyer RFQs and supplier matching | ✅ `buyer_requirements` + `supplier_responses` |
| 8 | Free/premium access securely controlled | ✅ `membership_tiers`, `user_memberships`, SECURITY DEFINER functions, RLS |
| 9 | ONE global frequency per user (instant/daily/weekly) | ✅ `notification_profiles.global_frequency` |
| 10 | Notification subs, channels, events, queues, logs connected | ✅ 6 normalized tables with FKs |
| 11 | Public, registered, operator, premium, admin permissions | ✅ RLS matrix implemented |
| 12 | RLS policies and privileged functions reviewed | ✅ SECURITY DEFINER functions + comprehensive policies |
| 13 | Existing website files and demo data preserved | ✅ No website changes; migration is DB-only |

---

## 🚀 Ready for Review

**File**: `supabase/migrations/001_initial_schema.sql` (complete, 800+ lines)  
**Backup**: `supabase/migrations/001_initial_schema.sql.backup`  

**Next Steps (Upon Your Approval)**:
1. Execute migration in Supabase Dashboard SQL Editor
2. Verify tables, indexes, RLS policies created
3. Seed initial reference data (already in migration)
4. Phase 2: Connect `directory/index.html` to Supabase
5. Phase 3: Build claims UI, product management UI, notification preferences UI

**Please confirm approval to proceed with execution.**