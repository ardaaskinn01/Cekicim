-- 1. Create city_pricing_settings table
CREATE TABLE IF NOT EXISTS public.city_pricing_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    city_name TEXT NOT NULL UNIQUE,
    base_price NUMERIC NOT NULL DEFAULT 1500.0,
    km_price_tier1 NUMERIC NOT NULL DEFAULT 200.0,
    km_price_tier2 NUMERIC NOT NULL DEFAULT 150.0,
    accident_multiplier NUMERIC NOT NULL DEFAULT 1.5,
    sort_order INT NOT NULL DEFAULT 99,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 2. Seed initial data for 10 Target Cities + Diğer İller
INSERT INTO public.city_pricing_settings (city_name, base_price, km_price_tier1, km_price_tier2, accident_multiplier, sort_order)
VALUES 
  ('İstanbul', 1500.0, 200.0, 150.0, 1.5, 1),
  ('Ankara', 1500.0, 200.0, 150.0, 1.5, 2),
  ('İzmir', 1500.0, 200.0, 150.0, 1.5, 3),
  ('Bursa', 1500.0, 200.0, 150.0, 1.5, 4),
  ('Antalya', 1500.0, 200.0, 150.0, 1.5, 5),
  ('Konya', 1500.0, 200.0, 150.0, 1.5, 6),
  ('Adana', 1500.0, 200.0, 150.0, 1.5, 7),
  ('Şanlıurfa', 1500.0, 200.0, 150.0, 1.5, 8),
  ('Gaziantep', 1500.0, 200.0, 150.0, 1.5, 9),
  ('Kocaeli', 1500.0, 200.0, 150.0, 1.5, 10),
  ('Diğer İller', 1500.0, 200.0, 150.0, 1.5, 11)
ON CONFLICT (city_name) DO UPDATE SET
  updated_at = timezone('utc'::text, now());

-- 3. Add incident_type and incident_reason to service_requests table
ALTER TABLE public.service_requests
  ADD COLUMN IF NOT EXISTS incident_type TEXT DEFAULT 'breakdown',
  ADD COLUMN IF NOT EXISTS incident_reason TEXT;

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.city_pricing_settings ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies
DROP POLICY IF EXISTS "Anyone can read city pricing" ON public.city_pricing_settings;
CREATE POLICY "Anyone can read city pricing" ON public.city_pricing_settings
  FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "Admins can update city pricing" ON public.city_pricing_settings;
CREATE POLICY "Admins can update city pricing" ON public.city_pricing_settings
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 6. Enable Realtime on city_pricing_settings table
ALTER PUBLICATION supabase_realtime ADD TABLE public.city_pricing_settings;
