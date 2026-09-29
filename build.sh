#!/usr/bin/env bash
set -e
/vercel/flutter/bin/flutter pub get
/vercel/flutter/bin/flutter build web --release --wasm --no-wasm-dry-run --no-web-resources-cdn \
  --dart-define=OPENROUTER_API_KEY="$OPENROUTER_API_KEY" \
  --dart-define=GEMINI_API_KEY="$GEMINI_API_KEY" \
  --dart-define=TAVILY_API_KEY="$TAVILY_API_KEY" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=FIREBASE_API_KEY="$FIREBASE_API_KEY" \
  --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_STORAGE_BUCKET="$FIREBASE_STORAGE_BUCKET" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_APP_ID="$FIREBASE_APP_ID"

# Generate offline-first service worker (precache toàn bộ asset + version cache).
node tool/generate_sw.cjs
