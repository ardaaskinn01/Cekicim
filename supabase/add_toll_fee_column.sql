-- Migration: Add toll_fee column to service_requests table
ALTER TABLE public.service_requests 
ADD COLUMN IF NOT EXISTS toll_fee NUMERIC DEFAULT 0;
