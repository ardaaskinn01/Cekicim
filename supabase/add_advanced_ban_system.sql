-- Migration: Advanced Ban & Suspension Mechanism (Permanent & Temporary)
-- Run this in Supabase SQL Editor

-- 1. Add ban duration and reason columns to profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS suspended_until TIMESTAMPTZ DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS suspension_reason TEXT DEFAULT NULL;

-- 2. Create or replace SECURITY DEFINER RPC to handle permanent or temporary ban
CREATE OR REPLACE FUNCTION public.admin_set_user_ban(
  target_user_id UUID,
  should_ban BOOLEAN,
  ban_type TEXT DEFAULT 'permanent', -- 'permanent', 'one_week', 'indefinite' (tekrar açana kadar)
  reason TEXT DEFAULT NULL
)
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  until_ts TIMESTAMPTZ := NULL;
BEGIN
  IF should_ban THEN
    IF ban_type = 'one_week' THEN
      until_ts := NOW() + INTERVAL '7 days';
    ELSE
      -- 'permanent' or 'indefinite'
      until_ts := NULL;
    END IF;

    UPDATE public.profiles
    SET 
      is_suspended = TRUE,
      suspended_until = until_ts,
      suspension_reason = reason
    WHERE id = target_user_id;

    -- Sürücü ise saha durumunu hemen çevrimdışı yap
    UPDATE public.drivers
    SET is_available = FALSE
    WHERE id = target_user_id;

  ELSE
    -- Engeli kaldır
    UPDATE public.profiles
    SET 
      is_suspended = FALSE,
      suspended_until = NULL,
      suspension_reason = NULL
    WHERE id = target_user_id;
  END IF;
END;
$$;

-- 3. Maintain backward compatibility for existing admin_toggle_user_block RPC
CREATE OR REPLACE FUNCTION public.admin_toggle_user_block(
  target_user_id UUID, 
  should_block BOOLEAN
)
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM public.admin_set_user_ban(target_user_id, should_block, 'permanent', NULL);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_user_ban(UUID, BOOLEAN, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_toggle_user_block(UUID, BOOLEAN) TO authenticated, service_role;

