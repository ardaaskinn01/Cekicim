-- Supabase SQL Editor'de çalıştırarak Admin kullanıcılarının tüm talepleri görmesini sağlayın.

ALTER TABLE public.service_requests ENABLE ROW LEVEL SECURITY;

-- 1. SELECT politikası (Adminler veya talep sahibi/sürücüsü okuyabilir)
DROP POLICY IF EXISTS "Users can read service requests" ON public.service_requests;
DROP POLICY IF EXISTS "Admins and participants can read service requests" ON public.service_requests;

CREATE POLICY "Admins and participants can read service requests" ON public.service_requests
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = customer_id 
    OR auth.uid() = driver_id
    OR auth.uid()::text = ANY(selected_driver_ids)
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 2. UPDATE politikası (Adminler veya talep sahibi/sürücüsü güncelleyebilir)
DROP POLICY IF EXISTS "Users can update service requests" ON public.service_requests;
DROP POLICY IF EXISTS "Admins and participants can update service requests" ON public.service_requests;

CREATE POLICY "Admins and participants can update service requests" ON public.service_requests
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = customer_id 
    OR auth.uid() = driver_id
    OR auth.uid()::text = ANY(selected_driver_ids)
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    auth.uid() = customer_id 
    OR auth.uid() = driver_id
    OR auth.uid()::text = ANY(selected_driver_ids)
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
