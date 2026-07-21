#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: list-workspaces.sh [--resource-group NAME] [--output table|json|tsv]

List Log Analytics workspaces, retention periods, quotas, and public network access
settings. The default output is a table.
EOF
}

resource_group=""
output=table
while (( $# > 0 )); do
  case "$1" in
    --resource-group) [[ $# -ge 2 ]] || die "--resource-group requires a name"; resource_group="$2"; shift 2 ;;
    --output) [[ $# -ge 2 ]] || die "--output requires a value"; output="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

validate_output "$output"
require_az
args=()
if [[ -n "$resource_group" ]]; then
  args+=(--resource-group "$resource_group")
fi

az monitor log-analytics workspace list "${args[@]}" \
  --query '[].{Name:name,ResourceGroup:resourceGroup,Location:location,SKU:sku.name,RetentionDays:retentionInDays,DailyQuotaGiB:workspaceCapping.dailyQuotaGb,PublicIngestion:publicNetworkAccessForIngestion,PublicQuery:publicNetworkAccessForQuery,Provisioning:provisioningState}' \
  --output "$output"
