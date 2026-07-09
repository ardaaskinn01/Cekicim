-- Migration: Fix Row Level Security on drivers table
-- Run this in your Supabase SQL Editor (https://supabase.com dashboard -> SQL Editor)

-- 1. Enable RLS on drivers table (in case it wasn't explicitly enabled)
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;

-- 2. Allow authenticated users to INSERT their own driver details
DROP POLICY IF EXISTS "Users can insert their own driver profile" ON public.drivers;
CREATE POLICY "Users can insert their own driver profile" ON public.drivers
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

-- 3. Allow authenticated users to UPDATE their own driver details
DROP POLICY IF EXISTS "Users can update their own driver profile" ON public.drivers;
CREATE POLICY "Users can update their own driver profile" ON public.drivers
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- 4. Allow authenticated users to SELECT driver details
DROP POLICY IF EXISTS "Users can select driver profiles" ON public.drivers;
CREATE POLICY "Users can select driver profiles" ON public.drivers
  FOR SELECT TO authenticated
  USING (true);
