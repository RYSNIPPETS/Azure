#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: find-unattached-disks.sh [--resource-group NAME]
                                [--output table|json|tsv]

List managed disks in the Unattached state. An unattached disk may still be an
intentional backup or recovery asset, and it continues to incur storage charges.
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

az disk list "${args[@]}" \
  --query '[?diskState==`Unattached`].{Name:name,ResourceGroup:resourceGroup,Location:location,SizeGiB:diskSizeGb,SKU:sku.name,OSType:osType,Created:timeCreated,DeleteOption:deleteOption}' \
  --output "$output"
