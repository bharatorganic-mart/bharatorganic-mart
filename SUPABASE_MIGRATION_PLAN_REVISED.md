# Supabase Migration Plan — Bharat Organic Mart (Revised Growth Strategy)

## 1. Revised Database Architecture (Normalized)

The architecture is now expanded to support official data imports, operator claims, marketplace activity (products/requirements), and notification systems.

### A. Core Tables
*   **`operator_sources`**: Tracks the USDA/APEDA databases, URLs, and collection dates.
*   **`directory_listings`**: Now handles both unclaimed and claimed profiles.
    *   `source_id` (FK to `operator_sources`)
    *   `verification_status` (Enum: Unclaimed, Claimed, Verification Pending, etc.)
    *   `operator_status` (Enum: Verified, Pending, etc.)
*   **`profile_claims`**: Audit trail for operators claiming their records.
*   **`verification_records`**: Detailed history of the Bharat Organic Mart verification process.

### B. Marketplace & User Tables
*   **`user_profiles`**: Extended `auth.users` profile with subscription preferences.
*   **`products`**: Marketplace items published by suppliers.
*   **`buyer_requirements`**: RFQs posted by registered buyers.
*   **`notification_preferences`**: Settings for category subscriptions (Rice, Wheat, etc.) and frequency (Instant, Daily, Weekly).
*   **`notification_logs`**: History of sent notifications.

### C. Advisory & Reminders
*   **`certification_reminders`**: Automated alerts for NPOP/NOP renewals based on source dates.
*   **`farmer_advisories`**: Crop-wise guidance modules.

---

## 2. SQL Schema Proposal

```sql
-- Enums (Expanded)
CREATE TYPE verification_status_enum AS ENUM ('Unclaimed', 'Claimed', 'Verification Pending', 'Verification in Progress', 'Verified', 'Verification Rejected', 'Reverification Required');
CREATE TYPE notification_frequency_enum AS ENUM ('instant', 'daily', 'weekly', 'none');

-- 1. Operator Sources
CREATE TABLE operator_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_name TEXT NOT NULL, -- e.g., 'APEDA NPOP', 'USDA NOP'
  source_url TEXT,
  last_collected_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Extended Directory Listings
ALTER TABLE directory_listings ADD COLUMN source_id UUID REFERENCES operator_sources(id);
ALTER TABLE directory_listings ADD COLUMN verification_status verification_status_enum DEFAULT 'Unclaimed';

-- 3. Profile Claims
CREATE TABLE profile_claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID REFERENCES directory_listings(id),
  user_id UUID REFERENCES auth.users(id),
  status TEXT DEFAULT 'pending',
  claimed_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Marketplace Products
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operator_id UUID REFERENCES directory_listings(id),
  product_name TEXT NOT NULL,
  category TEXT NOT NULL,
  quantity NUMERIC,
  unit TEXT,
  price NUMERIC,
  availability_status TEXT,
  harvest_year INT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Notification System
CREATE TABLE notification_preferences (
  user_id UUID REFERENCES auth.users(id) PRIMARY KEY,
  frequency notification_frequency_enum DEFAULT 'daily',
  subscribed_categories TEXT[] DEFAULT '{}'
);

CREATE TABLE certification_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operator_id UUID REFERENCES directory_listings(id),
  reminder_type TEXT, -- NPOP Renewal, etc.
  due_date DATE,
  is_sent BOOLEAN DEFAULT false
);
```

---

## 3. Implementation Phases

| Phase | Focus |
|-------|-------|
| **1** | **Schema Expansion**: Create new tables, relationships, and updated RLS for unclaimed vs. claimed. |
| **2** | **Data Import Workflow**: Scripts to import USDA/APEDA data as 'Unclaimed'. |
| **3** | **Claims Portal**: Create the UI/workflow for operators to claim profiles. |
| **4** | **Marketplace Expansion**: Implement `products` and `buyer_requirements` logic. |
| **5** | **Notification Engine**: Integrate with Supabase Edge Functions for email (e.g., SendGrid/Resend). |
| **6** | **Advisory Module**: Future farmer-centric content rollout. |

---

## 4. Security & Compliance Policies
*   **Privacy**: RLS policies ensure that fields like `phone` and `email` for "Unclaimed" profiles remain masked to the public until claimed or verified.
*   **Compliance**: Promotional emails only enabled via explicit opt-in in `notification_preferences`.
*   **Integrity**: `operator_sources` audit trail ensures we don't invent data.

**Do you approve this expanded architecture? If yes, I will prepare the complete 001_initial_schema.sql for Phase 1.**