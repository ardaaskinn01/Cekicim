-- Automatic matching logic database triggers
-- Run this in your Supabase SQL Editor

CREATE OR REPLACE FUNCTION public.handle_request_accepted()
RETURNS TRIGGER AS $$
BEGIN
  -- If status transitioned from awaiting_acceptance to accepted and driver_id is assigned
  IF (OLD.status = 'awaiting_acceptance' AND NEW.status = 'accepted' AND NEW.driver_id IS NOT NULL) THEN
    -- Update all other pending offers status to 'taken' in the DB
    UPDATE public.pending_offers
    SET status = 'taken'
    WHERE request_id = NEW.id AND driver_id != NEW.driver_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger definition
DROP TRIGGER IF EXISTS on_service_request_accepted ON public.service_requests;
CREATE TRIGGER on_service_request_accepted
  AFTER UPDATE OF status, driver_id ON public.service_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_request_accepted();
