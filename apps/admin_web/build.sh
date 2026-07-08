#!/bin/bash
# Kök dizinde (monorepo root) Flutter SDK indir ve kur
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

# Sürüm doğrula
flutter doctor

# admin_web klasörünün içine girip derlemeyi yap
cd apps/admin_web
flutter build web --release

# Vercel'in okuyacağı public klasörünü oluştur ve dosyaları kopyala
mkdir -p public
cp -r build/web/* public/