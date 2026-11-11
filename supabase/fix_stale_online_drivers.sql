-- Supabase SQL Editor'de çalıştırılacak komut:
-- 1. 10 dakikadan daha eski konum güncellemesi olan veya hiç güncelleme yapmamış müsait sürücüleri otomatik olarak çevrimdışı (is_available = false) yapar.
UPDATE public.drivers
SET is_available = false
WHERE is_available = true 
  AND (location_updated_at IS NULL OR location_updated_at < NOW() - INTERVAL '10 minutes');

-- 2. Her 5 dakikada bir çalışarak hayalet çevrimiçi sürücüleri temizleyen cron fonksiyonu:
CREATE OR REPLACE FUNCTION public.cleanup_stale_online_drivers()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.drivers
  SET is_available = false
  WHERE is_available = true
    AND (location_updated_at IS NULL OR location_updated_at < NOW() - INTERVAL '10 minutes');
END;
$$;

