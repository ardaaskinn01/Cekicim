-- Onaysız (is_verified = false) sürücülerin çevrimiçi/müsait kalmasını engelleyen SQL komutu.
-- Supabase SQL Editor'da çalıştırabilirsiniz.

-- 1. Onaysız olup çevrimiçi/müsait kalmış tüm sürücüleri derhal çevrimdışı yap:
UPDATE public.drivers
SET 
  is_available = false,
  is_online = false,
  current_request_id = NULL
WHERE is_verified = false;

-- 2. İleride onaysız sürücülerin yanlışlıkla müsait yapılmasını engellemek için trigger (opsiyonel ancak önerilen koruma):
CREATE OR REPLACE FUNCTION public.check_driver_verification_before_online()
RETURNS TRIGGER AS $$
BEGIN
  -- Eğer sürücü onaylanmamışsa ve is_available veya is_online true yapılmak isteniyorsa engelle ve false'a çek
  IF NEW.is_verified = false AND (NEW.is_available = true OR NEW.is_online = true) THEN
    NEW.is_available := false;
    NEW.is_online := false;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_driver_verification ON public.drivers;

CREATE TRIGGER trg_check_driver_verification
BEFORE INSERT OR UPDATE OF is_available, is_online, is_verified ON public.drivers
FOR EACH ROW
EXECUTE FUNCTION public.check_driver_verification_before_online();
