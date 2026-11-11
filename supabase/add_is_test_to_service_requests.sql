-- Supabase SQL Editor'de çalıştırarak:
-- 1. service_requests tablosuna is_test sütunu ekleyin
-- 2. Admin için RPC fonksiyonunu tanımlayın (RLS bypass ile anında test işaretleme)

ALTER TABLE public.service_requests 
ADD COLUMN IF NOT EXISTS is_test BOOLEAN DEFAULT false;

-- Admin RPC: Test durumunu değiştirme
CREATE OR REPLACE FUNCTION public.admin_set_request_test_status(target_request_id UUID, is_test_flag BOOLEAN)
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.service_requests
  SET is_test = is_test_flag
  WHERE id = target_request_id;
END;
$$;

