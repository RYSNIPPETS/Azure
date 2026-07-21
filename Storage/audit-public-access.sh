#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: audit-public-access.sh [--resource-group NAME]

Review storage-account public network and anonymous blob-access settings, then use
the active Entra identity to discover containers configured for Blob or Container
anonymous access. Output is TSV.

UNKNOWN means container ACLs could not be read. This is a configuration audit, not
proof of effective network access; policy, firewall, and private endpoint behavior
can alter the result.
EOF
}

resource_group=""
while (( $# > 0 )); do
  case "$1" in
    --resource-group) [[ $# -ge 2 ]] || die "--resource-group requires a name"; resource_group="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

require_az
require_jq
args=(--output json)
if [[ -n "$resource_group" ]]; then
  args+=(--resource-group "$resource_group")
fi
accounts="$(az storage account list "${args[@]}")"

printf 'ACCOUNT\tRESOURCE_GROUP\tBLOB_PUBLIC_ALLOWED\tPUBLIC_NETWORK\tNETWORK_DEFAULT\tPUBLIC_CONTAINERS\tASSESSMENT\n'
while IFS=$'\t' read -r account group blob_public public_network network_default; do
  [[ -n "$account" ]] || continue
  public_containers="UNKNOWN"
  if containers="$(az storage container list --account-name "$account" \
    --auth-mode login --output json 2>/dev/null)"; then
    public_containers="$(jq -r \
      '[.[] | select(.properties.publicAccess != null and .properties.publicAccess != "None")
        | (.name + "=" + .properties.publicAccess)] | join(",")' <<<"$containers")"
    [[ -n "$public_containers" ]] || public_containers="NONE_FOUND"
  fi

  assessment="NO_PUBLIC_CONTAINERS_FOUND"
  if [[ "$public_containers" == "UNKNOWN" ]]; then
    assessment="INCOMPLETE_DATA"
  elif [[ "$public_containers" != "NONE_FOUND" ]]; then
    if [[ "$blob_public" == "false" ]]; then
      assessment="PUBLIC_CONTAINER_CONFIGURATION_BLOCKED_AT_ACCOUNT"
    else
      assessment="REVIEW_ANONYMOUS_BLOB_ACCESS"
    fi
  elif [[ "$blob_public" != "false" || "$public_network" != "Disabled" || "$network_default" != "Deny" ]]; then
    assessment="REVIEW_ACCOUNT_EXPOSURE"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$account" "$group" "$blob_public" "$public_network" "$network_default" \
    "$public_containers" "$assessment"
done < <(jq -r '.[] | [.name, .resourceGroup,
  (if .allowBlobPublicAccess == null then "UNKNOWN" else (.allowBlobPublicAccess | tostring) end),
  (.publicNetworkAccess // "UNKNOWN"), (.networkRuleSet.defaultAction // "UNKNOWN")] | @tsv' \
  <<<"$accounts")
