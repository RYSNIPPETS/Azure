#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: audit-app-credentials.sh [--days N]

List password and certificate credentials on Microsoft Entra application
registrations. Expired credentials are marked EXPIRED; credentials expiring within N
days are marked EXPIRING_SOON. The default threshold is 30 days. Output is TSV.

The active identity needs permission to read applications through Microsoft Graph.
Credential secret values are never returned by this script.
EOF
}

days=30
while (( $# > 0 )); do
  case "$1" in
    --days) [[ $# -ge 2 ]] || die "--days requires a value"; days="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

validate_positive_integer "--days" "$days"
days=$((10#$days))
require_az
require_jq

apps="$(az ad app list --all --output json)"
printf 'APPLICATION\tAPP_ID\tCREDENTIAL_TYPE\tCREDENTIAL_ID\tDISPLAY_NAME\tEXPIRES\tDAYS_REMAINING\tASSESSMENT\n'
jq -r --argjson threshold "$days" '
  def epoch:
    try (sub("\\.[0-9]+Z$"; "Z")
      | sub("\\.[0-9]+\\+00:00$"; "Z")
      | sub("\\+00:00$"; "Z")
      | fromdateiso8601) catch null;
  [.[] as $app
    | (($app.passwordCredentials[]?
        | {type: "PASSWORD", id: .keyId, label: (.displayName // "-") , end: .endDateTime}),
       ($app.keyCredentials[]?
        | {type: "CERTIFICATE", id: .keyId, label: (.displayName // "-"), end: .endDateTime}))
    | . + {application: $app.displayName, appId: $app.appId}]
  | sort_by(.end)[]
  | (.end | epoch) as $expires
  | (if $expires == null then null
     else (($expires - now) / 86400 | floor) end) as $remaining
  | [
      .application,
      .appId,
      .type,
      .id,
      .label,
      .end,
      ($remaining // "-"),
      (if $remaining == null then "UNKNOWN_EXPIRY"
       elif $remaining < 0 then "EXPIRED"
       elif $remaining <= $threshold then "EXPIRING_SOON"
       else "OK" end)
    ]
  | @tsv
' <<<"$apps"
