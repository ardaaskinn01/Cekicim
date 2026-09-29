-- Migration: Create function to auto-expire stuck accepted service requests
CREATE OR REPLACE FUNCTION public.expire_stuck_requests()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 1. Reset availability for drivers whose requests are being auto-cancelled
  UPDATE public.drivers
  SET 
    current_request_id = NULL,
    is_available = TRUE
  WHERE id IN (
    SELECT driver_id 
    FROM public.service_requests 
    WHERE status = 'accepted' 
      AND accepted_at < NOW() - INTERVAL '20 minutes'
      AND driver_id IS NOT NULL
  );

  -- 2. Mark stuck requests as cancelled
  UPDATE public.service_requests
  SET 
    status = 'cancelled',
    cancellation_reason = 'Sürücü hareketsizliği nedeniyle sistem tarafından otomatik iptal edildi',
    cancelled_at = NOW()
  WHERE status = 'accepted' 
    AND accepted_at < NOW() - INTERVAL '20 minutes';
END;
$$;
