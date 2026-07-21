#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: find-unattached-public-ips.sh [--resource-group NAME]
                                     [--output table|json|tsv]

List Public IP resources that are not associated with an IP configuration or NAT
gateway. Review their intended use and current Azure pricing before deleting them.
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

az network public-ip list "${args[@]}" \
  --query '[?ipConfiguration==`null` && natGateway==`null`].{Name:name,ResourceGroup:resourceGroup,Location:location,IPAddress:ipAddress,SKU:sku.name,Allocation:publicIPAllocationMethod,Version:publicIPAddressVersion,Zones:join(`,`,zones || `[]`)}' \
  --output "$output"
