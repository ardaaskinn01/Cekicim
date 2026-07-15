-- Supabase SQL Editor'de çalıştırmak için Admin Kullanıcısı Oluşturma Scripti
-- E-posta ve şifreyi kendinize göre değiştirebilirsiniz.

DO $$
DECLARE
  new_user_id UUID := gen_random_uuid();
  admin_email TEXT := 'admin@cekici.com';
  admin_password TEXT := 'Admin123!';
  encrypted_pw TEXT;
BEGIN
  -- Şifreyi bcrypt ile şifrele (Supabase varsayılanı)
  encrypted_pw := crypt(admin_password, gen_salt('bf', 10));

  -- 1. auth.users tablosuna kullanıcıyı ekle
  INSERT INTO auth.users (
    id,
    instance_id,
    email,
    encrypted_password,
    email_confirmed_at,
    created_at,
    updated_at,
    role,
    aud,
    confirmation_token
  ) VALUES (
    new_user_id,
    '00000000-0000-0000-0000-000000000000',
    admin_email,
    encrypted_pw,
    now(),
    now(),
    now(),
    'authenticated',
    'authenticated',
    ''
  ) ON CONFLICT (email) DO NOTHING;

  -- Eğer kullanıcı başarıyla auth.users'a eklendiyse (veya zaten varsa id'sini alıp profili oluştur)
  SELECT id INTO new_user_id FROM auth.users WHERE email = admin_email;

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
    '+905000000000',
    'admin',
    true
  ) ON CONFLICT (id) DO UPDATE 
  SET role = 'admin', is_verified = true;

  RAISE NOTICE 'Admin kullanıcısı başarıyla oluşturuldu. E-posta: %, Şifre: %', admin_email, admin_password;
END $$;
