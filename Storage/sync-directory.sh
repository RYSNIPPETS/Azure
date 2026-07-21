#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/azure.sh
source "$SCRIPT_DIR/../Shared/azure.sh"

usage() {
  cat <<'EOF'
Usage: sync-directory.sh --source DIR --account NAME --container NAME
                         [--destination PATH] [--delete] [--execute] [--yes]

Preview an upload from a local directory with AzCopy's dry-run mode through Azure
CLI. Re-run with --execute to perform the sync. --delete also removes destination
blobs absent from the source and therefore deserves extra care. Entra login is used
instead of storage keys; --yes skips interactive confirmation.
EOF
}

source_dir=""
account=""
container=""
destination=""
delete=false
execute=false
ASSUME_YES=false
while (( $# > 0 )); do
  case "$1" in
    --source) [[ $# -ge 2 ]] || die "--source requires a directory"; source_dir="$2"; shift 2 ;;
    --account) [[ $# -ge 2 ]] || die "--account requires a name"; account="$2"; shift 2 ;;
    --container) [[ $# -ge 2 ]] || die "--container requires a name"; container="$2"; shift 2 ;;
    --destination) [[ $# -ge 2 ]] || die "--destination requires a path"; destination="$2"; shift 2 ;;
    --delete) delete=true; shift ;;
    --execute) execute=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

[[ -d "$source_dir" ]] || die "Source directory does not exist: $source_dir"
[[ -n "$account" ]] || die "--account is required"
[[ -n "$container" ]] || die "--container is required"
require_az

delete_destination=false
if [[ "$delete" == "true" ]]; then
  delete_destination=true
fi
sync_args=(--source "$source_dir" --account-name "$account" --container "$container"
  --auth-mode login --delete-destination "$delete_destination")
if [[ -n "$destination" ]]; then
  sync_args+=(--destination "$destination")
fi

info "Previewing sync: ${source_dir} -> ${account}/${container}/${destination}"
az storage blob sync "${sync_args[@]}" -- --dry-run

if [[ "$execute" != "true" ]]; then
  warn "Preview only. Re-run with --execute to perform this sync."
  exit 0
fi

if [[ "$delete" == "true" ]]; then
  confirm "Sync now and delete destination blobs not present in the source?"
else
  confirm "Sync this directory now?"
fi
az storage blob sync "${sync_args[@]}"
