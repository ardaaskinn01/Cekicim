-- Migration: Fix Row Level Security on public.messages table to allow admin users to read chat logs
-- Run this in your Supabase SQL Editor (https://supabase.com dashboard -> SQL Editor)

DROP POLICY IF EXISTS "Users can view messages for their service requests" ON public.messages;
CREATE POLICY "Users can view messages for their service requests"
  ON public.messages FOR SELECT
  USING (
    auth.uid() IN (
      SELECT customer_id FROM public.service_requests WHERE id = request_id
      UNION
      SELECT driver_id FROM public.service_requests WHERE id = request_id
    ) OR
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
