#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: inventory-databases.sh --server NAME --resource-group NAME
                              [--output table|json|tsv]

List databases on one Azure SQL logical server, including service objective,
maximum size, zone redundancy, and status. The default output is a table.
EOF
}

server=""
resource_group=""
output=table
while (( $# > 0 )); do
  case "$1" in
    --server) [[ $# -ge 2 ]] || die "--server requires a name"; server="$2"; shift 2 ;;
    --resource-group) [[ $# -ge 2 ]] || die "--resource-group requires a name"; resource_group="$2"; shift 2 ;;
    --output) [[ $# -ge 2 ]] || die "--output requires a value"; output="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

[[ -n "$server" ]] || die "--server is required"
[[ -n "$resource_group" ]] || die "--resource-group is required"
validate_output "$output"
require_az

az sql db list --server "$server" --resource-group "$resource_group" \
  --query '[].{Name:name,Location:location,Status:status,Edition:edition,ServiceObjective:currentServiceObjectiveName,SKU:sku.name,Capacity:sku.capacity,MaxSizeBytes:maxSizeBytes,ZoneRedundant:zoneRedundant,ReadScale:readScale,CreationDate:creationDate}' \
  --output "$output"
