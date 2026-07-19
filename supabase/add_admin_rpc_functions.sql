-- Supabase SQL Editor'de çalıştırın.
-- Admin onay/ret işlemlerini güvenli şekilde yapan SECURITY DEFINER fonksiyonları.

-- 1. Sürücü onaylama fonksiyonu
CREATE OR REPLACE FUNCTION public.admin_verify_driver(driver_id UUID)
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Sadece admin rolündeki kullanıcılar çağırabilir
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  UPDATE public.drivers
  SET is_verified = true, rejection_reason = NULL
  WHERE id = driver_id;
END;
$$;

-- 2. Sürücü reddetme fonksiyonu
CREATE OR REPLACE FUNCTION public.admin_reject_driver(driver_id UUID, reason TEXT)
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  UPDATE public.drivers
  SET is_verified = false, rejection_reason = reason
  WHERE id = driver_id;
END;
$$;

-- 3. Kullanıcı engelleme/engel kaldırma fonksiyonu
CREATE OR REPLACE FUNCTION public.admin_toggle_user_block(target_user_id UUID, should_block BOOLEAN)
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  UPDATE public.profiles
  SET is_suspended = should_block
  WHERE id = target_user_id;
END;
$$;
