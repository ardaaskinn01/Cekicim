-- Migration: Fix Row Level Security policies for pending_offers table
-- Run this in Supabase SQL Editor

ALTER TABLE pending_offers ENABLE ROW LEVEL SECURITY;

-- 1. Allow authenticated users to view pending offers if they are the driver or the customer who created the request
DROP POLICY IF EXISTS "Users can read pending offers" ON pending_offers;
CREATE POLICY "Users can read pending offers"
  ON pending_offers FOR SELECT
  TO authenticated
  USING (
    auth.uid() = driver_id 
    OR EXISTS (
      SELECT 1 FROM service_requests 
      WHERE service_requests.id = pending_offers.request_id 
        AND service_requests.customer_id = auth.uid()
    )
  );

-- 2. Allow customers to insert pending offers for their service requests
DROP POLICY IF EXISTS "Customers can insert pending offers" ON pending_offers;
CREATE POLICY "Customers can insert pending offers"
  ON pending_offers FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM service_requests 
      WHERE service_requests.id = request_id 
        AND service_requests.customer_id = auth.uid()
    )
  );

-- 3. Allow drivers to update their own pending offers (e.g. accept, reject, expire)
DROP POLICY IF EXISTS "Drivers can update pending offers" ON pending_offers;
CREATE POLICY "Drivers can update pending offers"
  ON pending_offers FOR UPDATE
  TO authenticated
  USING (auth.uid() = driver_id)
  WITH CHECK (auth.uid() = driver_id);
