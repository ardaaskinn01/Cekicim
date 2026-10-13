-- Onaysız (is_verified = false) sürücülerin çevrimiçi/müsait kalmasını engelleyen SQL komutu.
-- Supabase SQL Editor'da çalıştırabilirsiniz.

-- 1. Onaysız olup çevrimiçi/müsait kalmış tüm sürücüleri derhal müsaitlikten çıkar:
UPDATE public.drivers
SET 
  is_available = false,
  current_request_id = NULL
WHERE is_verified = false;

-- 2. İleride onaysız sürücülerin yanlışlıkla müsait yapılmasını engelleyen trigger:
CREATE OR REPLACE FUNCTION public.check_driver_verification_before_online()
RETURNS TRIGGER AS $$
BEGIN
  -- Eğer sürücü onaylanmamışsa ve is_available true yapılmak isteniyorsa engelle ve false'a çek
  IF NEW.is_verified = false AND NEW.is_available = true THEN
    NEW.is_available := false;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_driver_verification ON public.drivers;

CREATE TRIGGER trg_check_driver_verification
BEFORE INSERT OR UPDATE OF is_available, is_verified ON public.drivers
FOR EACH ROW
EXECUTE FUNCTION public.check_driver_verification_before_online();
