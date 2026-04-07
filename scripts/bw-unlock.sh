# scripts/bw-unlock.sh
# SOURCE this file — do not execute it.
# Usage: source scripts/bw-unlock.sh
# Ensures BW_SESSION is set and valid. Prompts for master password if needed.

set -euo pipefail

# Validate API key credentials are available
if [[ -z "${BW_CLIENTID:-}" || -z "${BW_CLIENTSECRET:-}" ]]; then
  echo "ERROR: BW_CLIENTID and BW_CLIENTSECRET must be set in your environment." >&2
  echo "Add them to your shell rc file (~/.zshrc, ~/.bashrc, etc.):" >&2
  echo "  export BW_CLIENTID=\"user.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\"" >&2
  echo "  export BW_CLIENTSECRET=\"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\"" >&2
  echo "Obtain from: https://vault.local.fuku.cloud → Settings → Security → Keys" >&2
  return 1
fi

# Load cached session token if available
BW_SESSION_FILE="${HOME}/.bw-session"
if [[ -f "$BW_SESSION_FILE" ]]; then
  export BW_SESSION
  BW_SESSION=$(cat "$BW_SESSION_FILE")
fi

# Check current vault status
BW_STATUS=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unauthenticated")

if [[ "$BW_STATUS" == "unlocked" ]]; then
  echo "Vault already unlocked." >&2
  return 0
fi

if [[ "$BW_STATUS" == "unauthenticated" ]]; then
  echo "Logging in with API key..." >&2
  bw login --apikey
  BW_STATUS=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "locked")
fi

if [[ "$BW_STATUS" == "locked" ]]; then
  echo "Unlocking vault (enter master password)..." >&2
  export BW_SESSION
  BW_SESSION=$(bw unlock --raw)
  echo "$BW_SESSION" > "$BW_SESSION_FILE"
  chmod 600 "$BW_SESSION_FILE"
  echo "Vault unlocked. Session cached at ~/.bw-session" >&2
  return 0
fi

echo "ERROR: Unexpected vault status: $BW_STATUS" >&2
return 1
