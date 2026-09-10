#!/usr/bin/env bash
# Đọc .env và in ra các cờ --dart-define để truyền cho lệnh flutter.
#
# Cách dùng:
#   flutter run -d chrome $(bash local_env.sh)
#   flutter build web $(bash local_env.sh)
set -euo pipefail

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

ARGS=()
for var in OPENROUTER_API_KEY GEMINI_API_KEY TAVILY_API_KEY SUPABASE_URL SUPABASE_ANON_KEY; do
  ARGS+=(--dart-define="$var=${!var:-}")
done

printf '%s\n' "${ARGS[@]}"