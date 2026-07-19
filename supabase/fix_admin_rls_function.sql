-- 1. Create a helper function with SECURITY DEFINER to bypass RLS checks when verifying admin status
CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID)
RETURNS BOOLEAN
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = user_id AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql;

-- 2. Allow admins to update any profile
DROP POLICY IF EXISTS "Admins can update any profile" ON public.profiles;
CREATE POLICY "Admins can update any profile" ON public.profiles
  FOR UPDATE TO authenticated
  USING (public.is_admin(auth.uid()));

-- 3. Allow admins to update any driver profile
DROP POLICY IF EXISTS "Admins can update any driver profile" ON public.drivers;
CREATE POLICY "Admins can update any driver profile" ON public.drivers
  FOR UPDATE TO authenticated
  USING (public.is_admin(auth.uid()));
