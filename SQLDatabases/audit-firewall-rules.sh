#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: audit-firewall-rules.sh [--resource-group NAME]

List server-level firewall rules on Azure SQL logical servers. Rules spanning every
IPv4 address are marked OPEN_TO_INTERNET; 0.0.0.0-to-0.0.0.0 rules are marked as
ALLOW_AZURE_SERVICES. Output is TSV.

This does not evaluate database-level firewall rules, private endpoints, service
endpoints, Azure Policy, or effective connectivity.
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
servers="$(az sql server list "${args[@]}")"

printf 'SERVER\tRESOURCE_GROUP\tRULE\tSTART_IP\tEND_IP\tASSESSMENT\n'
while IFS=$'\t' read -r server group; do
  [[ -n "$server" ]] || continue
  rules="$(az sql server firewall-rule list --server "$server" \
    --resource-group "$group" --output json)"
  jq -r --arg server "$server" --arg group "$group" '
    .[]
    | [.name, .startIpAddress, .endIpAddress,
       (if .startIpAddress == "0.0.0.0" and .endIpAddress == "0.0.0.0"
        then "ALLOW_AZURE_SERVICES"
        elif .startIpAddress == "0.0.0.0" and .endIpAddress == "255.255.255.255"
        then "OPEN_TO_INTERNET"
        else "REVIEW_RANGE" end)]
    | [$server, $group] + .
    | @tsv
  ' <<<"$rules"
done < <(jq -r '.[] | [.name, .resourceGroup] | @tsv' <<<"$servers")
