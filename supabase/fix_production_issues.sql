-- Migration: Fix Production Issues & Atomic Ratings (Phase 2)
-- Run this in Supabase SQL Editor

-- 1. Add is_suspended column to profiles
ALTER TABLE profiles 
  ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE;

-- 2. Create trigger function to update rating statistics atomically on insert
CREATE OR REPLACE FUNCTION update_user_rating_stats()
RETURNS TRIGGER AS $$
DECLARE
  current_rating FLOAT;
  current_total INTEGER;
BEGIN
  -- Check if rated_id is in drivers table
  IF EXISTS (SELECT 1 FROM drivers WHERE id = NEW.rated_id) THEN
    SELECT COALESCE(rating, 0.0), COALESCE(total_ratings, 0)
    INTO current_rating, current_total
    FROM drivers
    WHERE id = NEW.rated_id;

    UPDATE drivers
    SET 
      rating = ((current_rating * current_total) + NEW.score) / (current_total + 1),
      total_ratings = current_total + 1
    WHERE id = NEW.rated_id;
  ELSE
    -- Otherwise it is a customer (profiles table)
    SELECT COALESCE(rating, 5.0), COALESCE(total_ratings, 0)
    INTO current_rating, current_total
    FROM profiles
    WHERE id = NEW.rated_id;

    UPDATE profiles
    SET 
      rating = ((current_rating * current_total) + NEW.score) / (current_total + 1),
      total_ratings = current_total + 1
    WHERE id = NEW.rated_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Bind the trigger to ratings table
DROP TRIGGER IF EXISTS on_rating_inserted ON ratings;
CREATE TRIGGER on_rating_inserted
  AFTER INSERT ON ratings
  FOR EACH ROW
  EXECUTE FUNCTION update_user_rating_stats();

-- 4. Create blocked_customers table (drivers blocking customers)
CREATE TABLE IF NOT EXISTS blocked_customers (
  driver_id   UUID NOT NULL REFERENCES auth.users(id),
  customer_id UUID NOT NULL REFERENCES auth.users(id),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (driver_id, customer_id)
);

-- Enable RLS for blocked_customers
ALTER TABLE blocked_customers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Drivers manage their blocked customers" ON blocked_customers;
CREATE POLICY "Drivers manage their blocked customers"
  ON blocked_customers FOR ALL TO authenticated USING (auth.uid() = driver_id);

-- 5. Create storage bucket for request photos
INSERT INTO storage.buckets (id, name, public) 
VALUES ('request-photos', 'request-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for request-photos bucket
DROP POLICY IF EXISTS "Anyone can read request photos" ON storage.objects;
CREATE POLICY "Anyone can read request photos"
  ON storage.objects FOR SELECT USING (bucket_id = 'request-photos');

DROP POLICY IF EXISTS "Authenticated users can upload request photos" ON storage.objects;
CREATE POLICY "Authenticated users can upload request photos"
  ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'request-photos');

-- 6. Add rejection_reason to pending_offers
ALTER TABLE pending_offers 
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
