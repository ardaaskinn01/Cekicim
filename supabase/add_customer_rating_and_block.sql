-- Migration: Add customer rating fields to profiles and create blocked_drivers table
-- Run this in Supabase SQL Editor

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 5.0,
  ADD COLUMN IF NOT EXISTS total_ratings INT DEFAULT 0;

CREATE TABLE IF NOT EXISTS blocked_drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(customer_id, driver_id)
);

-- Enable RLS
ALTER TABLE blocked_drivers ENABLE ROW LEVEL SECURITY;

-- Blocked drivers policies
CREATE POLICY "Users can manage their own blocked drivers" 
  ON blocked_drivers FOR ALL 
  TO authenticated
  USING (auth.uid() = customer_id);

GRANT ALL ON blocked_drivers TO authenticated;
GRANT ALL ON blocked_drivers TO service_role;
