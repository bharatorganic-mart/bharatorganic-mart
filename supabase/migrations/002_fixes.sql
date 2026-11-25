-- =============================================================================
-- CORRECTION MIGRATION: 002_fixes.sql (CORRECTED)
-- Bharat Organic Mart — Minimal Fixes for 001_initial_schema.sql
-- REVIEW ONLY — DO NOT EXECUTE WITHOUT APPROVAL
-- =============================================================================

-- =============================================================================
-- FIX 2 (CORRECTED): Add CHECK constraint with NOT VALID
-- =============================================================================
-- Business rule: reminder_scheduled_at cannot be scheduled before source_date
-- reminder_scheduled_at is TIMESTAMPTZ NOT NULL, source_date is DATE (nullable)
-- Cast reminder_scheduled_at to DATE for comparison
-- NOT VALID skips existing rows; validate after cleanup
ALTER TABLE public.certification_reminders
ADD CONSTRAINT chk_cert_reminder_after_source
CHECK (reminder_scheduled_at::date >= source_date) NOT VALID;

-- Post-deployment cleanup & validation:
-- 1. Optionally populate NULL source_date from certificate_issue_date:
--    UPDATE public.certification_reminders
--    SET source_date = certificate_issue_date
--    WHERE source_date IS NULL AND certificate_issue_date IS NOT NULL;
-- 2. Fix any rows where reminder_scheduled_at::date < source_date
-- 3. Validate:
--    ALTER TABLE public.certification_reminders VALIDATE CONSTRAINT chk_cert_reminder_after_source;

-- =============================================================================
-- FIX 3: Fix incorrect comment on buyer_requirements.required_harvest_year
-- =============================================================================
-- Current (incorrect): 'Validated in application layer (no time-dependent CHECK)'
-- Correct: validated by DB trigger
COMMENT ON COLUMN public.buyer_requirements.required_harvest_year IS 'Validated via trigger public.validate_harvest_year() (2000 to current_year+5)';

-- =============================================================================
-- FIX 4: Fix incorrect comment on products.harvest_year
-- =============================================================================
-- Current (incorrect): 'No time-dependent CHECK; validated in application layer'
-- Correct: validated by DB trigger
COMMENT ON COLUMN public.products.harvest_year IS 'Validated via trigger public.validate_harvest_year() (2000 to current_year+5)';

-- =============================================================================
-- FIX 6 REMOVED: Redundant with existing column CHECK
-- =============================================================================
-- The column verification_status already has: CHECK (verification_status IN ('verified', 'pending', 'unverified'))
-- Adding another identical CHECK constraint is redundant.

-- =============================================================================
-- END OF CORRECTION MIGRATION
-- =============================================================================