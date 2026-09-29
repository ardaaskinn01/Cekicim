-- Migration: Rating & Block System
-- Run this in Supabase SQL Editor

-- 1. ratings tablosu
CREATE TABLE IF NOT EXISTS ratings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  request_id UUID NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
  rater_id UUID NOT NULL REFERENCES auth.users(id),
  rated_id UUID NOT NULL REFERENCES auth.users(id),
  score INTEGER NOT NULL CHECK (score BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Bir istek için tek puan (çift yön: müşteri→sürücü, sürücü→müşteri)
CREATE UNIQUE INDEX IF NOT EXISTS ratings_request_rater_unique
  ON ratings(request_id, rater_id);

-- RLS
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can insert ratings" ON ratings;
CREATE POLICY "Authenticated can insert ratings"
  ON ratings FOR INSERT TO authenticated WITH CHECK (auth.uid() = rater_id);

DROP POLICY IF EXISTS "Authenticated can read ratings" ON ratings;
CREATE POLICY "Authenticated can read ratings"
  ON ratings FOR SELECT TO authenticated USING (true);

-- 2. blocked_drivers tablosu
CREATE TABLE IF NOT EXISTS blocked_drivers (
  customer_id UUID NOT NULL REFERENCES auth.users(id),
  driver_id   UUID NOT NULL REFERENCES auth.users(id),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (customer_id, driver_id)
);

ALTER TABLE blocked_drivers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Customers manage their blocks" ON blocked_drivers;
CREATE POLICY "Customers manage their blocks"
  ON blocked_drivers FOR ALL TO authenticated USING (auth.uid() = customer_id);

-- 3. profiles tablosuna rating sütunları ekle (müşteri puanları için)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS rating FLOAT DEFAULT 5.0,
  ADD COLUMN IF NOT EXISTS total_ratings INTEGER DEFAULT 0;

-- 4. drivers tablosuna total_ratings sütunu ekle
ALTER TABLE drivers
  ADD COLUMN IF NOT EXISTS total_ratings INTEGER DEFAULT 0;
-- Not: drivers.rating sütunu zaten varsa bu satırı atlayın:
-- ALTER TABLE drivers ADD COLUMN IF NOT EXISTS rating FLOAT DEFAULT 5.0;
