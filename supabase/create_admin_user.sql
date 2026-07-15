-- Supabase SQL Editor'de çalıştırmak için Admin Kullanıcısı Oluşturma Scripti (Telefon Numarası ile)
-- Telefon numarasını kendinize göre değiştirebilirsiniz.

DO $$
DECLARE
  new_user_id UUID := gen_random_uuid();
  admin_phone TEXT := '+905001234567'; -- Buraya kendi telefon numaranızı girebilirsiniz
  admin_email TEXT := 'admin@cekicim.com'; -- Opsiyonel fallback email
BEGIN
  -- 1. auth.users tablosuna telefon numarası ile kullanıcıyı ekle
  INSERT INTO auth.users (
    id,
    instance_id,
    phone,
    phone_confirmed_at,
    email,
    email_confirmed_at,
    created_at,
    updated_at,
    role,
    aud,
    confirmation_token
  ) VALUES (
    new_user_id,
    '00000000-0000-0000-0000-000000000000',
    admin_phone,
    now(),
    admin_email,
    now(),
    now(),
    now(),
    'authenticated',
    'authenticated',
    ''
  ) ON CONFLICT (phone) DO NOTHING;

  -- Eğer kullanıcı zaten varsa id'sini alıp profili oluştur/güncelle
  SELECT id INTO new_user_id FROM auth.users WHERE phone = admin_phone;

  -- 2. public.profiles tablosuna admin rolüyle ekle
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    phone,
    role,
    is_verified
  ) VALUES (
    new_user_id,
    admin_email,
    'Sistem Yöneticisi',
    admin_phone,
    'admin',
    true
  ) ON CONFLICT (id) DO UPDATE 
  SET role = 'admin', phone = admin_phone, is_verified = true;

  RAISE NOTICE 'Admin kullanıcısı başarıyla oluşturuldu. Telefon: %', admin_phone;
END $$;
