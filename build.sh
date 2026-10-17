#!/usr/bin/env bash
set -e
echo "[build.sh] Flutter version:"
/vercel/flutter/bin/flutter --version

/vercel/flutter/bin/flutter pub get

DEFINES=(
  --dart-define=SUPABASE_URL="$SUPABASE_URL"
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
)

# Build WASM-first (dual-mode: JS + wasm). Nếu fail (builder hết RAM, SDK regression...)
# thì fallback sang build JS thuần — app vẫn deploy được thay vì fail trắng.
if ! /vercel/flutter/bin/flutter build web --release --wasm --no-wasm-dry-run \
    --no-web-resources-cdn "${DEFINES[@]}"; then
  echo "[build.sh] WASM build FAILED — fallback sang build JS thường"
  /vercel/flutter/bin/flutter build web --release --no-web-resources-cdn "${DEFINES[@]}"
fi

# Generate offline-first service worker (precache toàn bộ asset + version cache).
node tool/generate_sw.cjs
