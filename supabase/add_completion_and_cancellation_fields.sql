-- Migration: Add missing completion and cancellation fields to service_requests table
ALTER TABLE public.service_requests 
ADD COLUMN IF NOT EXISTS completion_code TEXT,
ADD COLUMN IF NOT EXISTS cancellation_reason TEXT,
ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP WITH TIME ZONE;
