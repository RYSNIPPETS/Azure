#!/usr/bin/env bash

# Shared helpers for the Azure CLI scripts. This file is sourced, not executed.

export AZURE_CORE_ONLY_SHOW_ERRORS=true
export AZURE_CORE_NO_COLOR=true

info() {
  printf 'INFO: %s\n' "$*" >&2
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_az() {
  local version
  require_command az
  version="$(az version --query '"azure-cli"' --output tsv 2>/dev/null)" \
    || die "Azure CLI version check failed."
  case "$version" in
    2.*) ;;
    *) die "Azure CLI 2.x is required (found: ${version:-unknown})" ;;
  esac
  az account show --output none \
    || die "Azure identity check failed. Run 'az login' and select a subscription."
}

require_jq() {
  require_command jq
}

active_subscription_id() {
  az account show --query id --output tsv
}

resource_manager_endpoint() {
  az cloud show --query endpoints.resourceManager --output tsv
}

configured_location() {
  local location
  location="${AZURE_DEFAULTS_LOCATION:-}"
  if [[ -z "$location" ]]; then
    location="$(az config get defaults.location --query value --output tsv 2>/dev/null || true)"
  fi
  [[ "$location" != "null" ]] || location=""
  printf '%s\n' "$location"
}

validate_output() {
  case "$1" in
    table | json | tsv) ;;
    *) die "Unsupported output format '$1' (expected table, json, or tsv)" ;;
  esac
}

validate_positive_integer() {
  case "$2" in
    '' | *[!0-9]*) die "$1 must be a positive integer" ;;
  esac
  (( 10#$2 > 0 )) || die "$1 must be greater than zero"
}

confirm() {
  local prompt="$1"
  local answer
  if [[ "${ASSUME_YES:-false}" == "true" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    die "Confirmation requires a terminal. Re-run with --yes after reviewing the preview."
  fi
  read -r -p "$prompt [y/N] " answer
  case "$answer" in
    y | Y | yes | YES | Yes) return 0 ;;
    *) die "Cancelled" ;;
  esac
}

utc_date() {
  date -u '+%Y-%m-%d'
}

utc_first_day_of_month() {
  date -u '+%Y-%m-01'
}

utc_days_ago() {
  local days="$1"
  if date -u -d "$days days ago" '+%Y-%m-%d' >/dev/null 2>&1; then
    date -u -d "$days days ago" '+%Y-%m-%d'
  else
    date -u -v-"${days}"d '+%Y-%m-%d'
  fi
}
