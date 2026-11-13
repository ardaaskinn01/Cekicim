-- Migration: Create feedbacks table and driver approval notifications RPC
-- Run this in your Supabase SQL Editor

-- 1. Create feedbacks table
CREATE TABLE IF NOT EXISTS public.feedbacks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  user_role TEXT NOT NULL DEFAULT 'customer', -- 'customer' or 'driver'
  category TEXT NOT NULL DEFAULT 'general', -- 'bug', 'suggestion', 'complaint', 'general'
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  attachment_url TEXT,
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'reviewed', 'resolved'
  admin_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.feedbacks ENABLE ROW LEVEL SECURITY;

-- RLS: Authenticated users can insert their own feedback
DROP POLICY IF EXISTS "Users can insert own feedback" ON public.feedbacks;
CREATE POLICY "Users can insert own feedback" ON public.feedbacks
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- RLS: Users can view their own feedbacks
DROP POLICY IF EXISTS "Users can view own feedback" ON public.feedbacks;
CREATE POLICY "Users can view own feedback" ON public.feedbacks
  FOR SELECT TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- RLS: Admins can update feedbacks (change status, add notes)
DROP POLICY IF EXISTS "Admins can update feedback" ON public.feedbacks;
CREATE POLICY "Admins can update feedback" ON public.feedbacks
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 2. Enhanced driver approval RPC with auto-notifications
CREATE OR REPLACE FUNCTION public.admin_verify_driver_with_notification(driver_id UUID)
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Mark verified
  UPDATE public.drivers
  SET is_verified = true, rejection_reason = NULL
  WHERE id = driver_id;

  -- Insert in-app notification for the driver
  INSERT INTO public.notifications (user_id, title, body, is_read, created_at)
  VALUES (
    driver_id,
    'Tebrikler! Belgeleriniz Onaylandı 🎉',
    'Başvurunuz ve evraklarınız yönetici tarafından onaylandı. Artık uygulamayı açıp çevrimiçi olarak kurtarma talepleri alabilirsiniz.',
    false,
    NOW()
  );
END;
$$;

-- 3. Enhanced driver reject RPC with auto-notifications
CREATE OR REPLACE FUNCTION public.admin_reject_driver_with_notification(driver_id UUID, reason TEXT)
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Mark unverified and set reason
  UPDATE public.drivers
  SET is_verified = false, is_available = false, rejection_reason = reason
  WHERE id = driver_id;

  -- Insert in-app notification for the driver
  INSERT INTO public.notifications (user_id, title, body, is_read, created_at)
  VALUES (
    driver_id,
    'Başvuru Durumu: Onaylanmadı ⚠️',
    COALESCE(reason, 'Belgeleriniz incelendi ancak onaylanamadı. Lütfen bilgilerinizi kontrol ediniz.'),
    false,
    NOW()
  );
END;
$$;

