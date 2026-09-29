-- Supabase SQL Editor'de çalıştırın.
-- Güvenlik: Admin dashboard zaten Flutter tarafında korunuyor.
-- RPC fonksiyonları sadece DB işlemini yapıyor.

CREATE OR REPLACE FUNCTION public.admin_verify_driver(driver_id UUID)
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.drivers
  SET is_verified = true, rejection_reason = NULL
  WHERE id = driver_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_reject_driver(driver_id UUID, reason TEXT)
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.drivers
  SET is_verified = false, rejection_reason = reason
  WHERE id = driver_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_toggle_user_block(target_user_id UUID, should_block BOOLEAN)
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.profiles
  SET is_suspended = should_block
  WHERE id = target_user_id;
END;
$$;
