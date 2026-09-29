-- Migration: Add created_at column to pending_offers if it doesn't exist
-- This is needed so the driver app can filter stale offers on startup.
ALTER TABLE public.pending_offers
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
