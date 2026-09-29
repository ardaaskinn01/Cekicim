-- Migration: Disputes System & Driver Rejection Reason
-- Run this in Supabase SQL Editor

-- 1. Add rejection_reason column to drivers table
ALTER TABLE drivers
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- 2. Create disputes table
CREATE TABLE IF NOT EXISTS disputes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  request_id UUID NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, investigating, resolved, dismissed
  admin_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own disputes" ON disputes;
CREATE POLICY "Users can view their own disputes"
  ON disputes FOR SELECT TO authenticated
  USING (
    auth.uid() = reporter_id OR 
    auth.uid() = reported_id OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Users can file a dispute" ON disputes;
CREATE POLICY "Users can file a dispute"
  ON disputes FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = reporter_id);

DROP POLICY IF EXISTS "Admins can update disputes" ON disputes;
CREATE POLICY "Admins can update disputes"
  ON disputes FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can delete disputes" ON disputes;
CREATE POLICY "Admins can delete disputes"
  ON disputes FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
