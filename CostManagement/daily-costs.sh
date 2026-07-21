#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: daily-costs.sh [--days N]

Show daily Azure usage cost for the last N UTC dates, including today. The default
is 14 days. Cost Management data can lag, and the current day is normally incomplete.
Output is TSV.
EOF
}

days=14
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
start="$(utc_days_ago "$((days - 1))")"
end="$(utc_date)"
subscription_id="$(active_subscription_id)"
arm_endpoint="$(resource_manager_endpoint)"
request="$(jq -nc \
  --arg from "${start}T00:00:00Z" \
  --arg to "${end}T23:59:59Z" \
  '{
    type: "Usage",
    timeframe: "Custom",
    timePeriod: {from: $from, to: $to},
    dataset: {
      granularity: "Daily",
      aggregation: {
        totalCost: {name: "PreTaxCost", function: "Sum"}
      }
    }
  }')"

costs="$(az rest --method post \
  --url "${arm_endpoint%/}/subscriptions/${subscription_id}/providers/Microsoft.CostManagement/query?api-version=2025-03-01" \
  --body "$request" --output json)"

printf 'DATE\tAMOUNT\tCURRENCY\n'
jq -r '
  .properties as $result
  | ($result.columns | map(.name) | index("PreTaxCost")) as $amount
  | ($result.columns | map(.name) | index("UsageDate")) as $date
  | ($result.columns | map(.name) | index("Currency")) as $currency
  | if $amount == null or $date == null or $currency == null
    then error("Cost Management response did not contain the expected columns")
    else $result.rows[]
    end
  | (.[ $date ] | tostring) as $yyyymmdd
  | [($yyyymmdd[0:4] + "-" + $yyyymmdd[4:6] + "-" + $yyyymmdd[6:8]),
     (.[ $amount ] | tostring), .[ $currency ]]
  | @tsv
' <<<"$costs"
