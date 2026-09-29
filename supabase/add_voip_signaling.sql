-- Migration: Add VoIP signaling columns to service_requests table
-- Run this in your Supabase SQL Editor (https://supabase.com dashboard -> SQL Editor)

ALTER TABLE public.service_requests 
ADD COLUMN IF NOT EXISTS active_call_channel TEXT,
ADD COLUMN IF NOT EXISTS active_call_caller_id UUID;
