#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: deallocate-by-tag.sh --tag KEY=VALUE [--resource-group NAME]
                            [--execute] [--yes]

Preview running Azure VMs selected by an exact tag, then optionally deallocate them.
Deallocation releases compute capacity and stops compute billing, but attached
storage and some networking resources can still incur charges. Nothing changes
without --execute; --yes skips the interactive confirmation.
EOF
}

tag=""
resource_group=""
execute=false
ASSUME_YES=false
while (( $# > 0 )); do
  case "$1" in
    --tag) [[ $# -ge 2 ]] || die "--tag requires KEY=VALUE"; tag="$2"; shift 2 ;;
    --resource-group) [[ $# -ge 2 ]] || die "--resource-group requires a name"; resource_group="$2"; shift 2 ;;
    --execute) execute=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

[[ "$tag" == *=* ]] || die "--tag KEY=VALUE is required"
tag_key="${tag%%=*}"
tag_value="${tag#*=}"
[[ -n "$tag_key" && -n "$tag_value" ]] || die "Both tag key and value must be non-empty"

require_az
require_jq
args=(--show-details --output json)
if [[ -n "$resource_group" ]]; then
  args+=(--resource-group "$resource_group")
fi

vms="$(az vm list "${args[@]}" | jq \
  --arg key "$tag_key" --arg value "$tag_value" \
  '[.[] | select(.tags[$key] == $value and .powerState == "VM running")
    | {id, name, resourceGroup, location,
       size: .hardwareProfile.vmSize, privateIps}]')"

count="$(jq 'length' <<<"$vms")"
if (( count == 0 )); then
  info "No running VMs matched ${tag_key}=${tag_value}."
  exit 0
fi

info "Matched ${count} running VM(s):"
jq -r '.[] | [.name, .resourceGroup, .location, .size, (.privateIps // "-")] | @tsv' \
  <<<"$vms" | awk 'BEGIN {print "NAME\tRESOURCE_GROUP\tLOCATION\tSIZE\tPRIVATE_IPS"} {print}'

if [[ "$execute" != "true" ]]; then
  warn "Preview only. Re-run with --execute to deallocate these VMs."
  exit 0
fi

confirm "Deallocate these ${count} VM(s)?"
vm_ids=()
while IFS= read -r vm_id; do
  vm_ids+=("$vm_id")
done < <(jq -r '.[].id' <<<"$vms")

az vm deallocate --ids "${vm_ids[@]}"
info "Deallocation request completed for ${count} VM(s)."
