-- Migration: Fix Row Level Security policies for service_requests table (Fixing Infinite Recursion)
-- Run this in your Supabase SQL Editor (https://supabase.com dashboard -> SQL Editor)

-- 1. Enable RLS on service_requests table (in case it wasn't explicitly enabled)
ALTER TABLE public.service_requests ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing SELECT policy if exists
DROP POLICY IF EXISTS "Users can read service requests" ON public.service_requests;
DROP POLICY IF EXISTS "Users can view service requests" ON public.service_requests;
DROP POLICY IF EXISTS "Customers can view their own requests" ON public.service_requests;
DROP POLICY IF EXISTS "Drivers can view their requests" ON public.service_requests;

-- Create SELECT policy (No subqueries to prevent infinite recursion loop with pending_offers)
CREATE POLICY "Users can read service requests" ON public.service_requests
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = customer_id 
    OR auth.uid() = driver_id
    OR auth.uid()::text = ANY(selected_driver_ids)
  );

-- 3. Drop existing UPDATE policy if exists
DROP POLICY IF EXISTS "Users can update service requests" ON public.service_requests;
DROP POLICY IF EXISTS "Users can edit service requests" ON public.service_requests;
DROP POLICY IF EXISTS "Customers can update their own requests" ON public.service_requests;
DROP POLICY IF EXISTS "Drivers can update their requests" ON public.service_requests;

-- Create UPDATE policy (No subqueries to prevent infinite recursion loop with pending_offers)
CREATE POLICY "Users can update service requests" ON public.service_requests
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = customer_id 
    OR auth.uid() = driver_id
    OR auth.uid()::text = ANY(selected_driver_ids)
  )
  WITH CHECK (
    auth.uid() = customer_id 
    OR auth.uid() = driver_id
    OR auth.uid()::text = ANY(selected_driver_ids)
  );

-- 4. Drop existing INSERT policy if exists
DROP POLICY IF EXISTS "Users can insert service requests" ON public.service_requests;
DROP POLICY IF EXISTS "Customers can insert service requests" ON public.service_requests;

-- Create INSERT policy allowing customers to insert requests
CREATE POLICY "Customers can insert service requests" ON public.service_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = customer_id
  );
