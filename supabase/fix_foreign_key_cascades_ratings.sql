-- Re-create profiles id foreign key with ON DELETE CASCADE referencing auth.users
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_id_fkey;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_id_fkey 
    FOREIGN KEY (id) 
    REFERENCES auth.users(id) 
    ON DELETE CASCADE;

-- Re-create drivers id foreign key with ON DELETE CASCADE referencing profiles
ALTER TABLE public.drivers
  DROP CONSTRAINT IF EXISTS drivers_id_fkey;

ALTER TABLE public.drivers
  ADD CONSTRAINT drivers_id_fkey 
    FOREIGN KEY (id) 
    REFERENCES public.profiles(id) 
    ON DELETE CASCADE;

-- Re-create ratings foreign keys with ON DELETE CASCADE referencing auth.users
ALTER TABLE public.ratings 
  DROP CONSTRAINT IF EXISTS ratings_rater_id_fkey,
  DROP CONSTRAINT IF EXISTS ratings_rated_id_fkey;

ALTER TABLE public.ratings
  ADD CONSTRAINT ratings_rater_id_fkey 
    FOREIGN KEY (rater_id) 
    REFERENCES auth.users(id) 
    ON DELETE CASCADE;

ALTER TABLE public.ratings
  ADD CONSTRAINT ratings_rated_id_fkey 
    FOREIGN KEY (rated_id) 
    REFERENCES auth.users(id) 
    ON DELETE CASCADE;

-- Re-create blocked_drivers foreign keys with ON DELETE CASCADE referencing auth.users
ALTER TABLE public.blocked_drivers 
  DROP CONSTRAINT IF EXISTS blocked_drivers_customer_id_fkey,
  DROP CONSTRAINT IF EXISTS blocked_drivers_driver_id_fkey;

ALTER TABLE public.blocked_drivers
  ADD CONSTRAINT blocked_drivers_customer_id_fkey 
    FOREIGN KEY (customer_id) 
    REFERENCES auth.users(id) 
    ON DELETE CASCADE;

ALTER TABLE public.blocked_drivers
  ADD CONSTRAINT blocked_drivers_driver_id_fkey 
    FOREIGN KEY (driver_id) 
    REFERENCES auth.users(id) 
    ON DELETE CASCADE;

-- Re-create blocked_customers foreign keys with ON DELETE CASCADE referencing auth.users
ALTER TABLE public.blocked_customers 
  DROP CONSTRAINT IF EXISTS blocked_customers_driver_id_fkey,
  DROP CONSTRAINT IF EXISTS blocked_customers_customer_id_fkey;

ALTER TABLE public.blocked_customers
  ADD CONSTRAINT blocked_customers_driver_id_fkey 
    FOREIGN KEY (driver_id) 
    REFERENCES auth.users(id) 
    ON DELETE CASCADE;

ALTER TABLE public.blocked_customers
  ADD CONSTRAINT blocked_customers_customer_id_fkey 
    FOREIGN KEY (customer_id) 
    REFERENCES auth.users(id) 
    ON DELETE CASCADE;
