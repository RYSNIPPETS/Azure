#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: tail-logs.sh --app NAME --resource-group NAME [--provider NAME]

Stream live logs from an Azure Function App until interrupted. App Service logging
must already be enabled. --provider can narrow the stream, for example to
"application" or "http".
EOF
}

app=""
resource_group=""
provider=""
while (( $# > 0 )); do
  case "$1" in
    --app) [[ $# -ge 2 ]] || die "--app requires a name"; app="$2"; shift 2 ;;
    --resource-group) [[ $# -ge 2 ]] || die "--resource-group requires a name"; resource_group="$2"; shift 2 ;;
    --provider) [[ $# -ge 2 ]] || die "--provider requires a name"; provider="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

[[ -n "$app" ]] || die "--app is required"
[[ -n "$resource_group" ]] || die "--resource-group is required"
require_az

args=(--name "$app" --resource-group "$resource_group")
if [[ -n "$provider" ]]; then
  args+=(--provider "$provider")
fi
az webapp log tail "${args[@]}"
