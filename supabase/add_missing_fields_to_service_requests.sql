-- Migration: Add missing fields to service_requests table
ALTER TABLE public.service_requests 
ADD COLUMN IF NOT EXISTS customer_phone TEXT,
ADD COLUMN IF NOT EXISTS vehicle_type TEXT,
ADD COLUMN IF NOT EXISTS vehicle_photo_url TEXT,
ADD COLUMN IF NOT EXISTS selected_driver_ids TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS destination_industry_zone TEXT;
