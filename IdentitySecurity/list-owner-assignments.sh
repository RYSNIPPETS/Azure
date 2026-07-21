#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: list-owner-assignments.sh [--output table|json|tsv]

List Azure RBAC Owner assignments at or inherited into scopes under the active
subscription. Owner can manage resources and grant access to others.

This is a focused signal, not a complete effective-permissions or privilege-
escalation analysis. Custom roles and other highly privileged built-in roles are not
included.
EOF
}

output=table
while (( $# > 0 )); do
  case "$1" in
    --output) [[ $# -ge 2 ]] || die "--output requires a value"; output="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

validate_output "$output"
require_az

az role assignment list --all --include-inherited --role Owner \
  --query '[].{Principal:principalName,PrincipalType:principalType,PrincipalId:principalId,Role:roleDefinitionName,Scope:scope,Condition:condition}' \
  --output "$output"
