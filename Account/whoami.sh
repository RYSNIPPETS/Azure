#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: whoami.sh

Show the active Azure identity, tenant, subscription, cloud, and configured default
location. This is a read-only preflight check to run before operating on Azure.
EOF
}

case "${1:-}" in
  -h | --help) usage; exit 0 ;;
  '') ;;
  *) usage >&2; die "Unknown argument: $1" ;;
esac

require_az
require_jq

account="$(az account show --output json)"
location="$(configured_location)"

jq -n \
  --argjson account "$account" \
  --arg location "$location" \
  '{
    subscription_id: $account.id,
    subscription_name: $account.name,
    tenant_id: $account.tenantId,
    principal: $account.user.name,
    principal_type: $account.user.type,
    cloud: $account.environmentName,
    state: $account.state,
    default_location: (if $location == "" then null else $location end)
  }'
