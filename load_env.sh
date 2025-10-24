#!/usr/bin/env bash
# Usage: source ./load_env.sh

# Stop on errors in this script while keeping nice messages
set -euo pipefail

# --- helpers ---
err() { printf >&2 "❌ %s\n" "$*"; }

# --- check prerequisites ---
command -v jq >/dev/null 2>&1 || { err "jq not found. Install jq first."; return 1; }

# --- load swim.env ---
if [[ -f "swim.env" ]]; then
  # Export every assignment inside swim.env (supports lines like KEY=VALUE)
  set -a
  # shellcheck disable=SC1091
  source "swim.env"
  set +a
else
  err "swim.env not found in $(pwd)"
fi

# --- load credentials.json into env vars ---
if [[ -f "credentials.json" ]]; then
  # Expecting JSON like: {"clientId":"...","clientSecret":"..."}
  # Print as two VAR=value lines to be robust against spaces
  mapfile -t kvs < <(jq -r '"OPENSKY_CLIENT_ID=\(.clientId)", "OPENSKY_CLIENT_SECRET=\(.clientSecret)"' credentials.json)

  # Validate keys exist (jq would print "null" if missing)
  for kv in "${kvs[@]}"; do
    if [[ "$kv" == *=null ]]; then
      err "Missing clientId/clientSecret in credentials.json"; return 1
    fi
  done

  # Export them in this shell
  export "${kvs[@]}"
else
  err "credentials.json not found in $(pwd)"
fi

# Optional: show what was set (comment out if you don’t want output)
# echo "OPENSKY_CLIENT_ID=${OPENSKY_CLIENT_ID:-<unset>}"
# echo "OPENSKY_CLIENT_SECRET=${OPENSKY_CLIENT_SECRET:+<set>}"