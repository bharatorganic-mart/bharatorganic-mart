-- =============================================================================
-- SECURITY HARDENING MIGRATION: 003_security_hardening.sql
-- Bharat Organic Mart — Critical RLS & Security Fixes
-- REVIEW ONLY — DO NOT EXECUTE WITHOUT APPROVAL
-- Depends on: 001_initial_schema.sql, 002_fixes.sql
-- Run AFTER 001_initial_schema.sql and 002_fixes.sql
-- =============================================================================

-- =============================================================================
-- 1. REVOKE DEFAULT PUBLIC PRIVILEGES ON ALL TABLES
-- =============================================================================
-- RLS does not grant privileges; must explicitly GRANT minimal SELECT

REVOKE ALL ON public.directory_listings FROM PUBLIC;
REVOKE ALL ON public.admin_users FROM PUBLIC;
REVOKE ALL ON public.products FROM PUBLIC;
REVOKE ALL ON public.profile_claims FROM PUBLIC;
REVOKE ALL ON public.buyer_requirements FROM PUBLIC;
REVOKE ALL ON public.supplier_responses FROM PUBLIC;
REVOKE ALL ON public.notification_profiles FROM PUBLIC;
REVOKE ALL ON public.notification_subscriptions FROM PUBLIC;
REVOKE ALL ON public.notification_channels FROM PUBLIC;
REVOKE ALL ON public.notification_events FROM PUBLIC;
REVOKE ALL ON public.notification_queue FROM PUBLIC;
REVOKE ALL ON public.notification_delivery_log FROM PUBLIC;
REVOKE ALL ON public.certification_reminders FROM PUBLIC;
REVOKE ALL ON public.farmer_advisories FROM PUBLIC;
REVOKE ALL ON public.farmer_advisory_subscriptions FROM PUBLIC;
REVOKE ALL ON public.audit_log FROM PUBLIC;
REVOKE ALL ON public.operator_categories FROM PUBLIC;
REVOKE ALL ON public.certification_programs FROM PUBLIC;
REVOKE ALL ON public.commodity_categories FROM PUBLIC;
REVOKE ALL ON public.quantity_units FROM PUBLIC;
REVOKE ALL ON public.membership_tiers FROM PUBLIC;
REVOKE ALL ON public.email_templates FROM PUBLIC;
REVOKE ALL ON public.operator_sources FROM PUBLIC;
REVOKE ALL ON public.excel_import_batches FROM PUBLIC;
REVOKE ALL ON public.farmer_advisories FROM PUBLIC;
REVOKE ALL ON public.farmer_advisory_subscriptions FROM PUBLIC;
REVOKE ALL ON public.admin_users FROM PUBLIC;

-- Grant minimal SELECT to authenticated role (RLS policies will filter rows)
GRANT SELECT ON public.directory_listings TO authenticated;
GRANT SELECT ON public.admin_users TO authenticated;
GRANT SELECT ON public.products TO authenticated;
GRANT SELECT ON public.profile_claims TO authenticated;
GRANT SELECT ON public.buyer_requirements TO authenticated;
GRANT SELECT ON public.supplier_responses TO authenticated;
GRANT SELECT ON public.operator_categories TO authenticated;
GRANT SELECT ON public.certification_programs TO authenticated;
GRANT SELECT ON public.commodity_categories TO authenticated;
GRANT SELECT ON public.quantity_units TO authenticated;
GRANT SELECT ON public.membership_tiers TO authenticated;
GRANT SELECT ON public.email_templates TO authenticated;
GRANT SELECT ON public.operator_sources TO authenticated;
GRANT SELECT ON public.excel_import_batches TO authenticated;
GRANT SELECT ON public.farmer_advisories TO authenticated;
GRANT SELECT ON public.farmer_advisory_subscriptions TO authenticated;

-- Service role needs access for SECURITY DEFINER functions
GRANT SELECT ON public.directory_listings TO service_role;
GRANT SELECT ON public.products TO service_role;
GRANT SELECT ON public.operator_categories TO service_role;
GRANT SELECT ON public.certification_reminders TO service_role;
GRANT SELECT ON public.certification_programs TO service_role;
GRANT SELECT ON public.profile_claims TO service_role;

-- Reference tables: allow anon read for reference data
GRANT SELECT ON public.operator_categories TO anon, authenticated;
GRANT SELECT ON public.certification_programs TO anon, authenticated;
GRANT SELECT ON public.commodity_categories TO anon, authenticated;
GRANT SELECT ON public.quantity_units TO anon, authenticated;
GRANT SELECT ON public.membership_tiers TO anon, authenticated;

-- View grants (views are SECURITY DEFINER)
GRANT SELECT ON public_directory_listings TO anon, authenticated;
GRANT SELECT ON public_products TO anon, authenticated;

-- Function grants
GRANT EXECUTE ON FUNCTION public.get_listing_for_claim(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_listing_claim(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_claim(uuid, text, text) TO authenticated;
-- NO GRANT to anon on any functions

-- =============================================================================
-- 2. DIRECTORY_LISTINGS: SECURE RLS POLICIES
-- =============================================================================

-- Drop existing insecure policies
DROP POLICY IF EXISTS "Public read directory_listings" ON public.directory_listings;
DROP POLICY IF EXISTS "Owner read own listings" ON public.directory_listings;
DROP POLICY IF EXISTS "Admin full directory_listings" ON public.directory_listings;

-- =============================================================================
-- RLS POLICIES: DIRECTORY LISTINGS (SECURED)
-- =============================================================================

-- NO anonymous access to table (no policy for anon)
-- No general authenticated read access to table

-- 1. Owner access: ONLY via approved profile_claims
CREATE POLICY "Owner read own listings" ON public.directory_listings
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profile_claims pc
      WHERE pc.listing_id = directory_listings.id
        AND pc.user_id = auth.uid()
        AND pc.status = 'approved'
    )
  );

-- 2. Admin: Full access
CREATE POLICY "Admin full directory_listings" ON directory_listings
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

-- =============================================================================
-- 3. SECURE CLAIM WORKFLOW FUNCTIONS
-- =============================================================================

-- 1. Get single listing for claim review (SECURITY DEFINER)
-- Returns ONLY safe columns for claim review
CREATE OR REPLACE FUNCTION public.get_listing_for_claim(p_listing_id uuid)
RETURNS TABLE (
  id uuid,
  operator_category_id uuid,
  operator_category text,
  name text,
  slug text,
  city text,
  state text,
  country text,
  postal_code text,
  certified_land_area text,
  organic_crops text,
  certified_area text,
  certifications jsonb,
  verification_status verification_status_enum,
  is_demo_data boolean,
  premium_visible boolean,
  website text,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT dl.id, dl.operator_category_id, oc.name AS operator_category,
         dl.name, dl.slug, dl.city, dl.state, dl.country, dl.postal_code,
         dl.certified_land_area, dl.organic_crops, dl.certified_area,
         dl.certifications, dl.verification_status, dl.is_demo_data,
         dl.premium_visible, dl.website, dl.created_at, dl.updated_at
  FROM public.directory_listings dl
  JOIN public.operator_categories oc ON oc.id = dl.operator_category_id
  WHERE dl.id = $1
    AND dl.verification_status = 'Unclaimed'
    AND dl.is_demo_data = false;
$$;

GRANT EXECUTE ON FUNCTION public.get_listing_for_claim(uuid) TO authenticated;
-- NO GRANT to anon

-- 2. Submit claim request for a specific listing
CREATE OR REPLACE FUNCTION public.request_listing_claim(p_listing_id uuid)
RETURNS public.profile_claims
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_claim public.profile_claims;
BEGIN
  -- Explicit auth.uid() check
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- Verify listing exists and is claimable
  IF NOT EXISTS (
    SELECT 1 FROM public.directory_listings dl
    WHERE dl.id = p_listing_id
      AND dl.verification_status = 'Unclaimed'
      AND dl.is_demo_data = false
  ) THEN
    RAISE EXCEPTION 'Listing not found or not claimable';
  END IF;

  -- Prevent duplicate claims - database-level protection with FOR SHARE lock
  IF EXISTS (
    SELECT 1 FROM public.profile_claims pc
    WHERE pc.listing_id = p_listing_id
      AND pc.user_id = auth.uid()
      AND pc.status IN ('pending', 'approved')
  ) THEN
    RAISE EXCEPTION 'Claim already exists for this listing';
  END IF;

  -- Create claim
  INSERT INTO public.profile_claims (listing_id, user_id, status, claimed_at)
  VALUES (p_listing_id, auth.uid(), 'pending', now())
  RETURNING * INTO v_claim;

  RETURN v_claim;
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_listing_claim(uuid) TO authenticated;

-- Admin approves/rejects claim
CREATE OR REPLACE FUNCTION public.process_claim(p_claim_id uuid, p_action text, p_review_notes text DEFAULT NULL)
RETURNS public.profile_claims
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_claim public.profile_claims;
  v_listing public.directory_listings;
BEGIN
  -- Explicit auth.uid() check
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- Admin authorization checked on EVERY invocation
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  -- Lock the claim row to prevent concurrent modifications
  SELECT * INTO v_claim FROM public.profile_claims WHERE id = p_claim_id FOR UPDATE;
  IF v_claim IS NULL THEN
    RAISE EXCEPTION 'Claim not found';
  END IF;

  -- Only allow action on pending claims
  IF v_claim.status <> 'pending' THEN
    RAISE EXCEPTION 'Can only process pending claims';
  END IF;

  -- Lock the listing row to prevent concurrent modifications
  SELECT * INTO v_listing FROM public.directory_listings WHERE id = v_claim.listing_id FOR UPDATE;
  IF v_listing IS NULL THEN
    RAISE EXCEPTION 'Listing not found';
  END IF;

  -- Verify listing is still unclaimed
  IF v_listing.verification_status <> 'Unclaimed' THEN
    RAISE EXCEPTION 'Listing is no longer unclaimed';
  END IF;

  IF p_action = 'approve' THEN
    UPDATE public.profile_claims
    SET status = 'approved', reviewed_by = auth.uid(), reviewed_at = now(), review_notes = p_review_notes
    WHERE id = p_claim_id
    RETURNING * INTO v_claim;

    UPDATE public.directory_listings
    SET verification_status = 'Claimed',
        internal_verification_status = 'verified',
        verification_date = now()
    WHERE id = v_claim.listing_id;

  ELSIF p_action = 'reject' THEN
    UPDATE public.profile_claims
    SET status = 'rejected', reviewed_by = auth.uid(), reviewed_at = now(), review_notes = p_review_notes
    WHERE id = p_claim_id
    RETURNING * INTO v_claim;
  ELSE
    RAISE EXCEPTION 'Invalid action';
  END IF;

  RETURN v_claim;
END;
$$;

GRANT EXECUTE ON FUNCTION public.process_claim(uuid, text, text) TO authenticated;

-- =============================================================================
-- 2. PUBLIC DIRECTORY LISTINGS VIEW: SECURITY DEFINER
-- =============================================================================

DROP VIEW IF EXISTS public_directory_listings;
CREATE VIEW public_directory_listings
WITH (security_invoker = false)  -- SECURITY DEFINER
AS
SELECT dl.id, dl.operator_category_id, oc.name AS operator_category,
       dl.name, dl.slug, dl.city, dl.state, dl.country,
       dl.certified_land_area, dl.organic_crops, dl.certified_area,
       dl.certifications, dl.verification_status, dl.is_demo_data,
       dl.premium_visible, dl.website, dl.created_at, dl.updated_at
FROM public.directory_listings dl
JOIN public.operator_categories oc ON oc.id = dl.operator_category_id
WHERE dl.publication_status = 'published' AND dl.approval_status = 'approved';

GRANT SELECT ON public_directory_listings TO anon, authenticated;

-- =============================================================================
-- 2. PUBLIC PRODUCTS VIEW: SECURITY DEFINER
-- =============================================================================

DROP VIEW IF EXISTS public_products;
CREATE VIEW public_products
WITH (security_invoker = false)  -- SECURITY DEFINER
AS
SELECT p.id, p.operator_id, p.commodity_category_id,
       cc.name AS commodity_category,
       p.product_name, p.variety,
       p.available_quantity, p.min_order_qty,
       qu.code AS unit,
       p.state, p.country,
       p.harvest_year, p.harvest_month,
       p.availability_status, p.is_premium_only
FROM public.products p
JOIN public.commodity_categories cc ON cc.id = p.commodity_category_id
JOIN public.quantity_units qu ON qu.id = p.quantity_unit_id
WHERE p.is_premium_only = false
  AND EXISTS (
    SELECT 1 FROM public.directory_listings dl
    WHERE dl.id = p.operator_id
      AND dl.publication_status = 'published'
      AND dl.approval_status = 'approved'
  );

GRANT SELECT ON public_products TO anon, authenticated;

-- =============================================================================
-- 2. ADMIN_USERS: EXPLICIT DENY FOR ANON
-- =============================================================================

DROP POLICY IF EXISTS "Admin read admin_users" ON admin_users;
DROP POLICY IF EXISTS "Admin write admin_users" ON admin_users;

CREATE POLICY "Deny anon admin_users" ON admin_users
  FOR ALL TO anon USING (false);

CREATE POLICY "Admin read admin_users" ON admin_users
  FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));

CREATE POLICY "Admin write admin_users" ON admin_users
  FOR ALL TO authenticated USING (public.is_super_admin(auth.uid())) WITH CHECK (public.is_super_admin(auth.uid()));

-- =============================================================================
-- 2. DIRECTORY_LISTINGS RLS: REPLACE EXISTING POLICIES
-- =============================================================================

DROP POLICY IF EXISTS "Public read directory_listings" ON directory_listings;
DROP POLICY IF EXISTS "Owner read own listings" ON public.directory_listings;
DROP POLICY IF EXISTS "Admin full directory_listings" ON public.directory_listings;

-- =============================================================================
-- RLS POLICIES: DIRECTORY LISTINGS (SECURED)
-- =============================================================================

-- NO anonymous access to table (no policy for anon)
-- No general authenticated read access to table

-- 1. Owner access: ONLY via approved profile_claims
CREATE POLICY "Owner read own listings" ON public.directory_listings
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profile_claims pc
      WHERE pc.listing_id = directory_listings.id
        AND pc.user_id = auth.uid()
        AND pc.status = 'approved'
    )
  );

-- 2. Admin: Full access
CREATE POLICY "Admin full directory_listings" ON directory_listings
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

-- =============================================================================
-- 3. PUBLIC PRODUCTS VIEW: SECURITY DEFINER
-- =============================================================================

DROP VIEW IF EXISTS public_products;
CREATE VIEW public_products
WITH (security_invoker = false)  -- SECURITY DEFINER
AS
SELECT p.id, p.operator_id, p.commodity_category_id,
       cc.name AS commodity_category,
       p.product_name, p.variety,
       p.available_quantity, p.min_order_qty,
       qu.code AS unit,
       p.state, p.country,
       p.harvest_year, p.harvest_month,
       p.availability_status, p.is_premium_only
FROM public.products p
JOIN public.commodity_categories cc ON cc.id = p.commodity_category_id
JOIN public.quantity_units qu ON qu.id = p.quantity_unit_id
WHERE p.is_premium_only = false
  AND EXISTS (
    SELECT 1 FROM public.directory_listings dl
    WHERE dl.id = p.operator_id
      AND dl.publication_status = 'published'
      AND dl.approval_status = 'approved'
  );

GRANT SELECT ON public_products TO anon, authenticated;

-- =============================================================================
-- 2. ADMIN_USERS: EXPLICIT DENY FOR ANON
-- =============================================================================

DROP POLICY IF EXISTS "Admin read admin_users" ON admin_users;
DROP POLICY IF EXISTS "Admin write admin_users" ON admin_users;

CREATE POLICY "Deny anon admin_users" ON admin_users
  FOR ALL TO anon USING (false);

CREATE POLICY "Admin read admin_users" ON admin_users
  FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));

CREATE POLICY "Admin write admin_users" ON admin_users
  FOR ALL TO authenticated USING (public.is_super_admin(auth.uid())) WITH CHECK (public.is_super_admin(auth.uid()));

-- =============================================================================
-- END OF MIGRATION
-- =============================================================================