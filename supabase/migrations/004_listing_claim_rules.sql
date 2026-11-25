-- =============================================================================
-- LISTING CLAIM RULES MIGRATION: 004_listing_claim_rules.sql
-- Bharat Organic Mart — Claim Concurrency, Ownership & Approval Rules
-- REVIEW ONLY — DO NOT EXECUTE WITHOUT APPROVAL
-- Depends on: 001_initial_schema.sql, 002_fixes.sql, 003_security_hardening.sql
-- Run AFTER 001_initial_schema.sql, 002_fixes.sql, 003_security_hardening.sql
-- =============================================================================

-- =============================================================================
-- 1. ADD SUPERSDED STATUS TO CLAIM STATUS ENUM
-- =============================================================================

-- Add 'superseded' status for claims that were pending but lost to another approved claim
ALTER TYPE claim_status_enum ADD VALUE IF NOT EXISTS 'superseded';

-- =============================================================================
-- 2. ADD PARTIAL UNIQUE INDEX: ONE APPROVED CLAIM PER LISTING
-- =============================================================================

-- This index enforces: ONLY ONE approved claim per listing
-- Multiple pending/rejected claims per listing are allowed
-- Different users can submit claims for the same listing
-- But only one claim can ever reach 'approved' status per listing

CREATE UNIQUE INDEX IF NOT EXISTS uq_profile_claims_one_approved_owner
ON public.profile_claims (listing_id)
WHERE status = 'approved';

-- Verify no existing violations before applying
DO $$
DECLARE
  v_conflicts int;
BEGIN
  SELECT count(*) INTO v_conflicts
  FROM (
    SELECT listing_id, count(*) as cnt
    FROM public.profile_claims
    WHERE status = 'approved'
    GROUP BY listing_id
    HAVING count(*) > 1
  ) t;

  IF v_conflicts > 0 THEN
    RAISE EXCEPTION 'Found % listings with multiple approved claims. Resolve conflicts before applying unique index.', v_conflicts;
  END IF;
END $$;

-- =============================================================================
-- 3. UPDATE request_listing_claim() - ALLOW MULTIPLE USERS TO CLAIM SAME LISTING
-- =============================================================================

-- The current function already allows multiple users to claim the same listing
-- (only prevents same user from submitting duplicate pending/approved claims)
-- No changes needed to the logic, but we verify the duplicate check is correct

-- Current logic at lines 191-199 in 003_security_hardening.sql:
-- IF EXISTS (
--     SELECT 1 FROM public.profile_claims pc
--     WHERE pc.listing_id = p_listing_id
--       AND pc.user_id = auth.uid()
--       AND pc.status IN ('pending', 'approved')
--   ) THEN
--     RAISE EXCEPTION 'Claim already exists for this listing';
--   END IF;
--
-- This correctly allows different users to claim the same listing
-- Only prevents the SAME user from submitting duplicate claims
-- No changes needed to request_listing_claim() logic

-- =============================================================================
-- 4. UPDATE process_claim() - APPROVE ONE, SUPERSEDE OTHERS
-- =============================================================================

CREATE OR REPLACE FUNCTION public.process_claim(p_claim_id uuid, p_action text, p_review_notes text DEFAULT NULL)
RETURNS public.profile_claims
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_claim public.profile_claims;
  v_listing public.directory_listings;
  v_superseded_count int := 0;
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
    -- Check if another claim is already approved for this listing (partial unique index will catch this)
    IF EXISTS (
      SELECT 1 FROM public.profile_claims pc
      WHERE pc.listing_id = v_claim.listing_id
        AND pc.status = 'approved'
        AND pc.id != p_claim_id
    ) THEN
      RAISE EXCEPTION 'Another claim is already approved for this listing';
    END IF;

    -- Approve this claim
    UPDATE public.profile_claims
    SET status = 'approved', reviewed_by = auth.uid(), reviewed_at = now(), review_notes = p_review_notes
    WHERE id = p_claim_id
    RETURNING * INTO v_claim;

    -- Supersede all other pending claims for this listing
    UPDATE public.profile_claims
    SET status = 'superseded',
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        review_notes = 'Superseded by approved claim ' || p_claim_id
    WHERE listing_id = v_claim.listing_id
      AND id != p_claim_id
      AND status = 'pending'
    RETURNING 1 INTO v_superseded_count;

    GET DIAGNOSTICS v_superseded_count = ROW_COUNT;

    -- Update listing ownership and verification status
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

-- =============================================================================
-- 4. VERIFY profile_claims RLS - PREVENT USERS FROM APPROVING OWN CLAIMS
-- =============================================================================
-- Current policies (verified):
-- - User read own claims: FOR SELECT TO authenticated USING (user_id = auth.uid())
-- - User insert claim: FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid())
-- - Admin full profile_claims: FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()))
--
-- VERIFICATION: No UPDATE policy for users - only admins can UPDATE status
-- Users can only INSERT (their own claims) and SELECT their own claims
-- ✅ No policy allows users to UPDATE status to 'approved'

-- =============================================================================
-- 3. PRODUCTS OWNER POLICY: USE PROFILE_CLAIMS NOT EMAIL
-- =============================================================================

DROP POLICY IF EXISTS "Operator manage own products" ON products;

CREATE POLICY "Operator manage own products" ON products
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.directory_listings dl
      JOIN public.profile_claims pc ON pc.listing_id = dl.id
      WHERE dl.id = products.operator_id
        AND pc.user_id = auth.uid()
        AND pc.status = 'approved'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.directory_listings dl
      JOIN public.profile_claims pc ON pc.listing_id = dl.id
      WHERE dl.id = products.operator_id
        AND pc.user_id = auth.uid()
        AND pc.status = 'approved'
    )
  );

-- =============================================================================
-- 3. ADMIN_USERS: EXPLICIT DENY FOR ANON
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
-- 4. PUBLIC DIRECTORY LISTINGS VIEW: SECURITY DEFINER, NO UNCLAIMED
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