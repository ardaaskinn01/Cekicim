-- Supabase SQL Editor'de çalıştırarak tetikleyiciyi güncelleyin.
-- role kolonundaki tip uyuşmazlığı hatasını (user_role enum cast) giderir.

-- 1. profiles tablosundaki email kolonunun zorunluluğunu (NOT NULL kısıtlamasını) kaldırın
ALTER TABLE public.profiles ALTER COLUMN email DROP NOT NULL;

-- 2. public.handle_new_user fonksiyonunu role sütunu için explicit enum cast ekleyerek güncelleyin
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.profiles (
    id, 
    email, 
    phone, 
    full_name, 
    role, 
    is_verified
  )
  VALUES (
    new.id,
    new.email, -- E-posta artık boş (NULL) olabilir
    new.phone,
    COALESCE(new.raw_user_meta_data->>'full_name', ''),
    COALESCE(new.raw_user_meta_data->>'role', 'customer')::public.user_role, -- Text tipini user_role enum tipine cast ediyoruz
    false
  ) 
  ON CONFLICT (id) DO UPDATE
  SET 
    phone = COALESCE(new.phone, public.profiles.phone),
    email = COALESCE(new.email, public.profiles.email);
    
  RETURN new;
END;
$$;

-- 3. Tetikleyiciyi public fonksiyona bağlayarak yeniden oluşturun
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
