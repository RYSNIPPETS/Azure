#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: month-to-date.sh

Show month-to-date Azure usage cost grouped by service name. Cost Management data can
lag behind current usage. Output is TSV, sorted from highest to lowest amount.
EOF
}

case "${1:-}" in
  -h | --help) usage; exit 0 ;;
  '') ;;
  *) usage >&2; die "Unknown argument: $1" ;;
esac

require_az
require_jq
start="$(utc_first_day_of_month)"
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
      granularity: "None",
      aggregation: {
        totalCost: {name: "PreTaxCost", function: "Sum"}
      },
      grouping: [
        {type: "Dimension", name: "ServiceName"}
      ]
    }
  }')"

costs="$(az rest --method post \
  --url "${arm_endpoint%/}/subscriptions/${subscription_id}/providers/Microsoft.CostManagement/query?api-version=2025-03-01" \
  --body "$request" --output json)"

printf 'SERVICE\tAMOUNT\tCURRENCY\tPERIOD_START\tPERIOD_END\n'
jq -r --arg start "$start" --arg end "$end" '
  .properties as $result
  | ($result.columns | map(.name) | index("PreTaxCost")) as $amount
  | ($result.columns | map(.name) | index("ServiceName")) as $service
  | ($result.columns | map(.name) | index("Currency")) as $currency
  | if $amount == null or $service == null or $currency == null
    then error("Cost Management response did not contain the expected columns")
    else $result.rows
    end
  | sort_by(.[ $amount ]) | reverse[]
  | [.[ $service ], (.[ $amount ] | tostring), .[ $currency ], $start, $end]
  | @tsv
' <<<"$costs"
