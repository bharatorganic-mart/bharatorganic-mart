-- =============================================================================
-- BHARAT ORGANIC MART — AUTH TABLES SETUP
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/syxrvkiqrvbecqdkyphs
-- =============================================================================

-- 1. Create user_profiles table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT,
  role TEXT DEFAULT 'operator' CHECK (role IN ('operator', 'buyer', 'admin', 'super_admin')),
  phone TEXT,
  company_name TEXT,
  is_verified BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Create admin_users table
CREATE TABLE IF NOT EXISTS public.admin_users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  role TEXT DEFAULT 'admin' CHECK (role IN ('admin', 'super_admin')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Create profile_claims table
CREATE TABLE IF NOT EXISTS public.profile_claims (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  listing_id UUID REFERENCES public.directory_listings(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  claimant_name TEXT,
  claimant_email TEXT,
  claim_reason TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'superseded')),
  reviewed_by UUID REFERENCES public.admin_users(id),
  reviewed_at TIMESTAMPTZ,
  review_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_claims ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies for user_profiles
DROP POLICY IF EXISTS "User read own profile" ON public.user_profiles;
CREATE POLICY "User read own profile" ON public.user_profiles
  FOR SELECT TO authenticated USING (id = auth.uid());

DROP POLICY IF EXISTS "User update own profile" ON public.user_profiles;
CREATE POLICY "User update own profile" ON public.user_profiles
  FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "User insert own profile" ON public.user_profiles;
CREATE POLICY "User insert own profile" ON public.user_profiles
  FOR INSERT TO authenticated WITH CHECK (id = auth.uid());

-- 6. RLS Policies for profile_claims
DROP POLICY IF EXISTS "User read own claims" ON public.profile_claims;
CREATE POLICY "User read own claims" ON public.profile_claims
  FOR SELECT TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS "User insert claim" ON public.profile_claims;
CREATE POLICY "User insert claim" ON public.profile_claims
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Public insert claim" ON public.profile_claims;
CREATE POLICY "Public insert claim" ON public.profile_claims
  FOR INSERT TO anon WITH CHECK (true);

-- 7. Trigger to auto-create user_profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.user_profiles (id, full_name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'operator')
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- END OF SCRIPT
-- =============================================================================
