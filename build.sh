#!/usr/bin/env bash
set -e
/vercel/flutter/bin/flutter pub get
/vercel/flutter/bin/flutter build web --release --no-wasm-dry-run --pwa-strategy=offline-first \
  --dart-define=OPENROUTER_API_KEY="$OPENROUTER_API_KEY" \
  --dart-define=GEMINI_API_KEY="$GEMINI_API_KEY" \
  --dart-define=TAVILY_API_KEY="$TAVILY_API_KEY" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
