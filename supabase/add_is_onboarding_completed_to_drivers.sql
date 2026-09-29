-- drivers tablosuna is_onboarding_completed kolonu ekle (yoksa)
ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS is_onboarding_completed BOOLEAN NOT NULL DEFAULT false;

-- Supabase schema cache'i yenile
NOTIFY pgrst, 'reload schema';
