#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: inventory-load-balancers.sh [--resource-group NAME]
                                   [--output table|json|tsv]

List Azure Load Balancer resources in the active subscription. Application Gateway,
Front Door, and Traffic Manager are not included. The default output is a table.
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

az network lb list "${args[@]}" \
  --query '[].{Name:name,ResourceGroup:resourceGroup,Location:location,SKU:sku.name,Tier:sku.tier,Frontends:length(frontendIPConfigurations || `[]`),BackendPools:length(backendAddressPools || `[]`),Rules:length(loadBalancingRules || `[]`),Provisioning:provisioningState}' \
  --output "$output"
