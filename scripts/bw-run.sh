#!/usr/bin/env bash
# scripts/bw-run.sh
# Usage: bw-run.sh <command> [args...]
# Injects secrets from Vaultwarden as env vars, then runs the command.
#
# Examples:
#   bw-run.sh terraform -chdir=terraform/hel plan
#   bw-run.sh terraform -chdir=terraform/brain apply
#   bw-run.sh ansible-playbook ansible/playbooks/provision-vm.yml -l vaultwarden

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure vault is unlocked
# shellcheck source=scripts/bw-unlock.sh
source "${SCRIPT_DIR}/bw-unlock.sh"

# Helper: retrieve a custom field from a Vaultwarden item
bw_get_field() {
  local item_name="$1"
  local field_name="$2"
  local value
  value=$(bw get item "$item_name" --session "$BW_SESSION" 2>/dev/null \
    | jq -r ".fields[]? | select(.name == \"$field_name\") | .value")
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "ERROR: Field '$field_name' not found in Vaultwarden item '$item_name'" >&2
    exit 1
  fi
  echo "$value"
}

# Detect Terraform workspace from -chdir= arg or current directory
WORKSPACE=""
for arg in "$@"; do
  if [[ "$arg" == -chdir=* ]]; then
    CHDIR="${arg#-chdir=}"
    WORKSPACE=$(basename "$CHDIR")
    break
  fi
done
if [[ -z "$WORKSPACE" ]]; then
  WORKSPACE=$(basename "$PWD")
fi

# Detect command type
COMMAND="${1:-}"

if [[ "$COMMAND" == "terraform" ]]; then
  # Validate workspace
  if [[ "$WORKSPACE" != "hel" && "$WORKSPACE" != "brain" ]]; then
    echo "ERROR: Cannot determine Terraform workspace. Use -chdir=terraform/<workspace>" >&2
    echo "       Detected workspace: '$WORKSPACE' (not 'hel' or 'brain')" >&2
    exit 1
  fi

  echo "Retrieving Terraform secrets for workspace: $WORKSPACE" >&2
  bw sync --session "$BW_SESSION" > /dev/null

  # Shared secrets
  export AWS_ACCESS_KEY_ID
  AWS_ACCESS_KEY_ID=$(bw_get_field "rustfs-s3" "access_key")
  export AWS_SECRET_ACCESS_KEY
  AWS_SECRET_ACCESS_KEY=$(bw_get_field "rustfs-s3" "secret_key")
  export TF_VAR_proxmox_insecure="true"

  # Workspace-specific secrets
  VW_ITEM="${WORKSPACE}-proxmox"
  export TF_VAR_proxmox_endpoint
  TF_VAR_proxmox_endpoint=$(bw_get_field "$VW_ITEM" "endpoint")
  export TF_VAR_proxmox_api_token
  TF_VAR_proxmox_api_token=$(bw_get_field "$VW_ITEM" "api_token")
  export TF_VAR_ssh_public_key
  TF_VAR_ssh_public_key=$(bw_get_field "$VW_ITEM" "ssh_public_key")
  export TF_VAR_gateway
  TF_VAR_gateway=$(bw_get_field "$VW_ITEM" "gateway")

  if [[ "$WORKSPACE" == "hel" ]]; then
    export TF_VAR_vm_password
    TF_VAR_vm_password=$(bw_get_field "$VW_ITEM" "vm_password")
  fi

  echo "Secrets injected. Running: $*" >&2

elif [[ "$COMMAND" == "ansible-playbook" || "$COMMAND" == "ansible" ]]; then
  # BW_SESSION is already exported by bw-unlock.sh — ansible lookup plugin uses it
  echo "BW_SESSION available for Ansible bitwarden lookup plugin." >&2
  echo "Running: $*" >&2

else
  # For any other command, still ensure BW_SESSION is exported
  echo "Running: $*" >&2
fi

exec "$@"
