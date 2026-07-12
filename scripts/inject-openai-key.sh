#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${FRIDGECHEF_ENV_FILE:-$HOME/Desktop/llm-ai-projects/youtube_pdf_reporter/.env}"
INFO_PLIST="$BUILT_PRODUCTS_DIR/$INFOPLIST_PATH"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "error: $ENV_FILE not found — cannot inject OPENAI_API_KEY" >&2
  echo "hint: set FRIDGECHEF_ENV_FILE to point at a .env containing OPENAI_API_KEY=..." >&2
  exit 1
fi

KEY=$(grep -E '^OPENAI_API_KEY=' "$ENV_FILE" | head -1 | cut -d'=' -f2- | tr -d '"'"'")

if [[ -z "$KEY" ]]; then
  echo "error: OPENAI_API_KEY missing or empty in $ENV_FILE" >&2
  exit 1
fi

/usr/libexec/PlistBuddy -c "Delete :OPENAI_API_KEY" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :OPENAI_API_KEY string $KEY" "$INFO_PLIST"

echo "✓ injected OPENAI_API_KEY"
