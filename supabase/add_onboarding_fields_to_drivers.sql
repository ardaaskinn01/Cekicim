-- Migration: Add missing onboarding and verification fields to drivers table
ALTER TABLE public.drivers 
ADD COLUMN IF NOT EXISTS driver_license_url TEXT,
ADD COLUMN IF NOT EXISTS src_certificate_url TEXT,
ADD COLUMN IF NOT EXISTS psychotechnic_url TEXT,
ADD COLUMN IF NOT EXISTS vehicle_registration_url TEXT,
ADD COLUMN IF NOT EXISTS tax_plate_url TEXT,
ADD COLUMN IF NOT EXISTS criminal_record_url TEXT,
ADD COLUMN IF NOT EXISTS vehicle_photos TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS equipments TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS supported_vehicle_types TEXT[] DEFAULT '{}';
