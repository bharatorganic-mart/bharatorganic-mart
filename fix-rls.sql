-- Fix RLS policies for directory_listings and user_profiles

-- Enable RLS (if not already)
ALTER TABLE directory_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Public read access" ON directory_listings;
DROP POLICY IF EXISTS "Public read access" ON user_profiles;
DROP POLICY IF EXISTS "Public read access" ON admin_users;
DROP POLICY IF EXISTS "Admin write access" ON directory_listings;
DROP POLICY IF EXISTS "Admin write access" ON user_profiles;
DROP POLICY IF EXISTS "Admin write access" ON admin_users;

-- Create public read policies
CREATE POLICY "Public read access" ON directory_listings
  FOR SELECT USING (true);

CREATE POLICY "Public read access" ON user_profiles
  FOR SELECT USING (true);

CREATE POLICY "Public read access" ON admin_users
  FOR SELECT USING (true);

-- Admin write policies (using auth.uid() check)
CREATE POLICY "Admin write access" ON directory_listings
  FOR ALL USING (
    auth.role() = 'authenticated'
    AND EXISTS (
      SELECT 1 FROM admin_users WHERE id = auth.uid()
    )
  );

CREATE POLICY "Admin write access" ON user_profiles
  FOR ALL USING (
    auth.role() = 'authenticated'
    AND EXISTS (
      SELECT 1 FROM admin_users WHERE id = auth.uid()
    )
  );

CREATE POLICY "Admin write access" ON admin_users
  FOR ALL USING (
    auth.role() = 'authenticated'
    AND EXISTS (
      SELECT 1 FROM admin_users WHERE id = auth.uid() AND role = 'super_admin'
    )
  );

-- Users can read/update their own profile
CREATE POLICY "User read own profile" ON user_profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "User update own profile" ON user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- Grant necessary permissions to anon role
GRANT SELECT ON directory_listings TO anon;
GRANT SELECT ON user_profiles TO anon;
GRANT SELECT ON admin_users TO anon;

-- Grant authenticated role permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON directory_listings TO authenticated;
GRANT SELECT, UPDATE ON user_profiles TO authenticated;
GRANT SELECT ON admin_users TO authenticated;

-- Verify policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('directory_listings', 'user_profiles', 'admin_users')
ORDER BY tablename, policyname;
