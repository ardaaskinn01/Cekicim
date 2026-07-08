#!/bin/bash
# Flutter SDK indir ve kur
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"
# Sürüm doğrula ve bağımlılıkları yükle
flutter doctor
# Web derlemesini yap
flutter build web --release
# Çıktıyı Vercel'in okuyacağı klasöre taşı
mkdir -p public
cp -r build/web/* public/