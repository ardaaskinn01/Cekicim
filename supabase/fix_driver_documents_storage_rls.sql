-- Migration: Fix Supabase Storage Buckets and RLS Policies for Driver Documents & Registration
-- Run this SQL in Supabase Dashboard -> SQL Editor

-- 1. Create storage buckets if they do not exist and ensure they are public
INSERT INTO storage.buckets (id, name, public) 
VALUES 
  ('driver-documents', 'driver-documents', true),
  ('request-photos', 'request-photos', true),
  ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Storage policies for 'driver-documents' bucket
DROP POLICY IF EXISTS "Anyone can read driver documents" ON storage.objects;
CREATE POLICY "Anyone can read driver documents"
  ON storage.objects FOR SELECT 
  USING (bucket_id = 'driver-documents');

DROP POLICY IF EXISTS "Authenticated users can upload driver documents" ON storage.objects;
CREATE POLICY "Authenticated users can upload driver documents"
  ON storage.objects FOR INSERT TO authenticated 
  WITH CHECK (bucket_id = 'driver-documents');

DROP POLICY IF EXISTS "Authenticated users can update driver documents" ON storage.objects;
CREATE POLICY "Authenticated users can update driver documents"
  ON storage.objects FOR UPDATE TO authenticated 
  USING (bucket_id = 'driver-documents');

DROP POLICY IF EXISTS "Authenticated users can delete driver documents" ON storage.objects;
CREATE POLICY "Authenticated users can delete driver documents"
  ON storage.objects FOR DELETE TO authenticated 
  USING (bucket_id = 'driver-documents');

-- 3. Storage policies for 'request-photos' bucket
DROP POLICY IF EXISTS "Anyone can read request photos" ON storage.objects;
CREATE POLICY "Anyone can read request photos"
  ON storage.objects FOR SELECT 
  USING (bucket_id = 'request-photos');

DROP POLICY IF EXISTS "Authenticated users can upload request photos" ON storage.objects;
CREATE POLICY "Authenticated users can upload request photos"
  ON storage.objects FOR INSERT TO authenticated 
  WITH CHECK (bucket_id = 'request-photos');

-- 4. Storage policies for 'avatars' bucket
DROP POLICY IF EXISTS "Anyone can read avatars" ON storage.objects;
CREATE POLICY "Anyone can read avatars"
  ON storage.objects FOR SELECT 
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Authenticated users can upload avatars" ON storage.objects;
CREATE POLICY "Authenticated users can upload avatars"
  ON storage.objects FOR INSERT TO authenticated 
  WITH CHECK (bucket_id = 'avatars');
