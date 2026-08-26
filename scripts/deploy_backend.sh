#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "Missing .env — copy .env.example and fill in secrets."
  exit 1
fi

set -a
source .env
set +a

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  echo "TELEGRAM_BOT_TOKEN is missing from .env"
  exit 1
fi

npx --yes supabase login
npx --yes supabase link --project-ref wjkoykwxemprfujbcozr
npx --yes supabase secrets set "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN"
npx --yes supabase functions deploy telegram-auth --no-verify-jwt
npx --yes supabase functions deploy spin
npx --yes supabase functions deploy submit-deposit
npx --yes supabase functions deploy submit-withdrawal

echo "Backend functions deployed."
