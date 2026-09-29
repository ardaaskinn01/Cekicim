-- profiles tablosuna is_verified kolonu ekle (yoksa)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT false;

-- Mevcut sürücülerin durumunu koruma
-- (Zaten is_verified olmayan kayıtlar false olarak kalacak)

-- Supabase schema cache'i yenile (PostgREST otomatik yeniler ama
-- eğer sorun olursa Dashboard > API > Reload Schema yapılabilir)
NOTIFY pgrst, 'reload schema';
