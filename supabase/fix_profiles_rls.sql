-- Migration: Fix Row Level Security on profiles table to allow reading profile details
-- Run this in your Supabase SQL Editor (https://supabase.com dashboard -> SQL Editor)

-- 1. Enable RLS on profiles table (in case it wasn't explicitly enabled)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 2. Allow authenticated users (including admins) to read profiles
-- This is required so that the Admin Panel can fetch driver/customer name, phone, email, etc.
DROP POLICY IF EXISTS "Allow read access to all profiles for authenticated users" ON public.profiles;
CREATE POLICY "Allow read access to all profiles for authenticated users" ON public.profiles
  FOR SELECT TO authenticated
  USING (true);
