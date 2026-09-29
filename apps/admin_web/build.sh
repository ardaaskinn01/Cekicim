#!/bin/bash
set -e

# Dart/Flutter bellek ve performans optimizasyonu
export DART_VM_OPTIONS="--old_gen_heap_size=2048"

# Kök dizinde miyiz yoksa alt dizinde miyiz kontrol edelim
if [ -d "apps/admin_web" ]; then
  # Kök dizindeyiz (monorepo root)
  if [ ! -d "flutter" ]; then
    git clone https://github.com/flutter/flutter.git -b stable --depth 1
  fi
  export PATH="$PATH:$(pwd)/flutter/bin"
  cd apps/admin_web
else
  # Zaten apps/admin_web alt dizindeyiz
  if [ ! -d "flutter" ]; then
    git clone https://github.com/flutter/flutter.git -b stable --depth 1
  fi
  export PATH="$PATH:$(pwd)/flutter/bin"
fi

# pubspec_overrides.yaml ayarları
cat > pubspec_overrides.yaml << 'EOF'
dependency_overrides:
  shared_models:
    path: ../../packages/shared_models
  shared_services:
    path: ../../packages/shared_services
  shared_ui:
    path: ../../packages/shared_ui
EOF

# Bağımlılıkları yükle
flutter pub get

# Derlemeyi yap
flutter build web --release --no-pub --no-tree-shake-icons


# Vercel'in okuyacağı public klasörünü oluştur ve dosyaları kopyala
mkdir -p public
cp -r build/web/* public/
