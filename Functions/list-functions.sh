#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: list-functions.sh --app NAME --resource-group NAME
                         [--output table|json|tsv]

List the functions, binding count, disabled state, and invoke URL template for one
Function App. The command does not retrieve function keys or invoke a trigger.
EOF
}

app=""
resource_group=""
output=table
while (( $# > 0 )); do
  case "$1" in
    --app) [[ $# -ge 2 ]] || die "--app requires a name"; app="$2"; shift 2 ;;
    --resource-group) [[ $# -ge 2 ]] || die "--resource-group requires a name"; resource_group="$2"; shift 2 ;;
    --output) [[ $# -ge 2 ]] || die "--output requires a value"; output="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

[[ -n "$app" ]] || die "--app is required"
[[ -n "$resource_group" ]] || die "--resource-group is required"
validate_output "$output"
require_az

az functionapp function list --name "$app" --resource-group "$resource_group" \
  --query '[].{Function:name,Language:config.language,Disabled:config.disabled,Bindings:length(config.bindings || `[]`),InvokeURL:invokeUrlTemplate}' \
  --output "$output"
