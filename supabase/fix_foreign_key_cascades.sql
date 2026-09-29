-- Drop the existing foreign key constraints on service_requests
ALTER TABLE public.service_requests 
  DROP CONSTRAINT IF EXISTS service_requests_customer_id_fkey,
  DROP CONSTRAINT IF EXISTS service_requests_driver_id_fkey;

-- Re-create the foreign key constraints with ON DELETE CASCADE
ALTER TABLE public.service_requests
  ADD CONSTRAINT service_requests_customer_id_fkey 
    FOREIGN KEY (customer_id) 
    REFERENCES public.profiles(id) 
    ON DELETE CASCADE;

ALTER TABLE public.service_requests
  ADD CONSTRAINT service_requests_driver_id_fkey 
    FOREIGN KEY (driver_id) 
    REFERENCES public.profiles(id) 
    ON DELETE CASCADE;
