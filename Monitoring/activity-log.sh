#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: activity-log.sh [--hours N] [--max-events N] [--resource-group NAME]
                       [--status STATUS] [--output table|json|tsv]

List recent Azure Activity Log events. The defaults are the last 6 hours and at most
100 events. Use --status Failed to focus on failed control-plane operations.
EOF
}

hours=6
max_events=100
resource_group=""
status=""
output=table
while (( $# > 0 )); do
  case "$1" in
    --hours) [[ $# -ge 2 ]] || die "--hours requires a value"; hours="$2"; shift 2 ;;
    --max-events) [[ $# -ge 2 ]] || die "--max-events requires a value"; max_events="$2"; shift 2 ;;
    --resource-group) [[ $# -ge 2 ]] || die "--resource-group requires a name"; resource_group="$2"; shift 2 ;;
    --status) [[ $# -ge 2 ]] || die "--status requires a value"; status="$2"; shift 2 ;;
    --output) [[ $# -ge 2 ]] || die "--output requires a value"; output="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

validate_positive_integer "--hours" "$hours"
validate_positive_integer "--max-events" "$max_events"
hours=$((10#$hours))
max_events=$((10#$max_events))
validate_output "$output"
require_az

args=(--offset "${hours}h" --max-events "$max_events")
if [[ -n "$resource_group" ]]; then
  args+=(--resource-group "$resource_group")
fi
if [[ -n "$status" ]]; then
  args+=(--status "$status")
fi

az monitor activity-log list "${args[@]}" \
  --query '[].{Time:eventTimestamp,Level:level,Status:status.value,Operation:operationName.localizedValue,ResourceGroup:resourceGroupName,ResourceId:resourceId,Caller:caller,CorrelationId:correlationId}' \
  --output "$output"
