-- Migration: Add IBAN fields to drivers table
-- Run this in Supabase SQL Editor

ALTER TABLE drivers
  ADD COLUMN IF NOT EXISTS iban TEXT,
  ADD COLUMN IF NOT EXISTS iban_owner_name TEXT;

-- Update RLS: Müşteriler sadece KABUL edilmiş taleplerde sürücünün IBAN bilgisini görebilir.
-- Drivers tablosuna mevcut politikalar korunuyor; iban alanı zaten select ile açık.
-- Sadece müşterinin eşleştiği sürücünün ibanını görmesi için bir view oluşturuyoruz.

CREATE OR REPLACE VIEW driver_iban_for_customer AS
SELECT
  d.id AS driver_id,
  d.iban,
  d.iban_owner_name,
  sr.id AS request_id,
  sr.customer_id
FROM drivers d
INNER JOIN service_requests sr
  ON sr.driver_id = d.id
WHERE
  sr.status IN ('accepted', 'in_progress', 'completed');

-- RLS for this view: müşteri yalnızca kendi talebini görsün
ALTER VIEW driver_iban_for_customer OWNER TO authenticated;

GRANT SELECT ON driver_iban_for_customer TO authenticated;
