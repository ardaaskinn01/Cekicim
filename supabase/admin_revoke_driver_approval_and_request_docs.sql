-- 1. Ensure columns exist on drivers table
ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_available BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS is_onboarding_completed BOOLEAN NOT NULL DEFAULT false;

-- 2. Enhanced RPC to reject / revoke approval / request documents with in-app notification
CREATE OR REPLACE FUNCTION public.admin_reject_driver_with_notification(driver_id UUID, reason TEXT)
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  -- 1. Reset verification, force offline, set reason, reset onboarding completed flag
  UPDATE public.drivers
  SET 
    is_verified = false,
    is_available = false,
    rejection_reason = reason,
    is_onboarding_completed = false
  WHERE id = driver_id;

  -- 2. Insert high-priority in-app notification for the driver
  INSERT INTO public.notifications (user_id, title, body, type, is_read, created_at)
  VALUES (
    driver_id,
    '⚠️ Eksik Evrak / Belge Güncelleme Talebi',
    COALESCE(reason, 'Yönetici tarafından belgelerinizin güncellenmesi talep edildi. Lütfen sürücü başvuru ekranından belgelerinizi güncelleyerek tekrar onaya iletiniz.'),
    'document_rejected',
    false,
    NOW()
  );
END;
$$;

-- 3. Grant execute permissions to authenticated and service_role
GRANT EXECUTE ON FUNCTION public.admin_reject_driver_with_notification(UUID, TEXT) TO authenticated, service_role;
