-- Supabase SQL Editor'de bir kullanıcıyı (ve artı/eksi format varyasyonlarını) temizlemek için script.
-- target_phone alanına silmek istediğiniz numarayı yazın.

DO $$
DECLARE
  target_phone TEXT := '905528045457'; -- Buraya silmek istediğiniz numarayı yazın (Örn: '905528045457')
  phone_with_plus TEXT;
  phone_without_plus TEXT;
BEGIN
  -- Numara varyasyonlarını oluştur
  phone_without_plus := REPLACE(target_phone, '+', '');
  phone_with_plus := '+' || phone_without_plus;

  -- 1. Bağlı tablolardaki kayıtları temizle (Yabancı anahtar kısıtlamalarını aşmak için)
  DELETE FROM public.service_requests 
  WHERE customer_id IN (SELECT id FROM auth.users WHERE phone IN (phone_with_plus, phone_without_plus))
     OR driver_id IN (SELECT id FROM auth.users WHERE phone IN (phone_with_plus, phone_without_plus));

  DELETE FROM public.drivers 
  WHERE id IN (SELECT id FROM auth.users WHERE phone IN (phone_with_plus, phone_without_plus));

  DELETE FROM public.profiles 
  WHERE id IN (SELECT id FROM auth.users WHERE phone IN (phone_with_plus, phone_without_plus));
  
  -- 2. Ana auth tablosundan sil
  DELETE FROM auth.users WHERE phone IN (phone_with_plus, phone_without_plus);
  
  RAISE NOTICE 'Kullanıcı ve tüm verileri (% ve % formatları) silindi.', phone_with_plus, phone_without_plus;
END $$;
