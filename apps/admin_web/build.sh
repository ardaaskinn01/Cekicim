#!/bin/bash
set -e

# Kök dizinde miyiz yoksa alt dizinde miyiz kontrol edelim
if [ -d "apps/admin_web" ]; then
  # Kök dizindeyiz (monorepo root)
  REPO_ROOT=$(pwd)
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
  export PATH="$PATH:$(pwd)/flutter/bin"
  cd apps/admin_web
else
  # Zaten apps/admin_web alt dizindeyiz
  REPO_ROOT=$(pwd)/../..
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
  export PATH="$PATH:$(pwd)/flutter/bin"
fi

# pubspec_overrides.yaml içindeki Windows backslash'larını Linux forward slash ile düzelt
cat > pubspec_overrides.yaml << 'EOF'
# melos_managed_dependency_overrides: shared_models,shared_services,shared_ui
dependency_overrides:
  shared_models:
    path: ../../packages/shared_models
  shared_services:
    path: ../../packages/shared_services
  shared_ui:
    path: ../../packages/shared_ui
EOF

# Sürüm doğrula
flutter doctor

# Derlemeyi yap
flutter build web --release

# Vercel'in okuyacağı public klasörünü oluştur ve dosyaları kopyala
mkdir -p public
cp -r build/web/* public/
