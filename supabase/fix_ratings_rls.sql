-- SQL Migration: Fix Ratings Table constraints and RLS policies
-- Run this in your Supabase SQL Editor if you see RLS or insertion errors when rating customers

-- 1. Ensure ratings table exists (safety check)
CREATE TABLE IF NOT EXISTS public.ratings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  request_id UUID NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
  rater_id UUID NOT NULL REFERENCES auth.users(id),
  rated_id UUID NOT NULL REFERENCES auth.users(id),
  score INTEGER NOT NULL CHECK (score BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Ensure unique index on (request_id, rater_id) is enforced
-- (Each user can only rate once per service request)
DROP INDEX IF EXISTS public.ratings_request_rater_unique;
CREATE UNIQUE INDEX IF NOT EXISTS ratings_request_rater_unique
  ON public.ratings(request_id, rater_id);

-- 3. Enable RLS
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;

-- 4. Re-create SELECT policy
DROP POLICY IF EXISTS "Authenticated can read ratings" ON public.ratings;
CREATE POLICY "Authenticated can read ratings"
  ON public.ratings FOR SELECT TO authenticated USING (true);

-- 5. Re-create INSERT policy
DROP POLICY IF EXISTS "Authenticated can insert ratings" ON public.ratings;
CREATE POLICY "Authenticated can insert ratings"
  ON public.ratings FOR INSERT TO authenticated WITH CHECK (auth.uid() = rater_id);

-- 6. Grant appropriate permissions
GRANT ALL ON public.ratings TO authenticated;
GRANT ALL ON public.ratings TO service_role;
