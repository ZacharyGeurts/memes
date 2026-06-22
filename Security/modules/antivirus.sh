#!/usr/bin/env bash
# antivirus — rkhunter/chkrootkit + heuristics. ClamAV explicitly NOT used.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

cmd_purge_clamav() {
  ammo_log 'purge ClamAV only (project policy — no clam)'
  for pkg in clamav clamav-daemon clamav-freshclam clamav-unofficial-sigs; do
    dpkg -l "$pkg" &>/dev/null 2>&1 || continue
    ammo_sudo apt-get remove --purge -y "$pkg" 2>/dev/null && ammo_log "removed $pkg" || true
  done
  ammo_service_off clamav-freshclam
  ammo_service_off clamav-daemon
}

cmd_antivirus_install() {
  if ! command -v apt-get >/dev/null 2>&1; then
    ammo_log 'apt-get missing — install rkhunter/chkrootkit manually'
    return 0
  fi
  cmd_purge_clamav
  ammo_log 'installing rkhunter + chkrootkit (no ClamAV)'
  ammo_sudo apt-get update -qq
  ammo_sudo DEBIAN_FRONTEND=noninteractive apt-get install -y rkhunter chkrootkit 2>/dev/null || true
}

cmd_antivirus_update() {
  if command -v rkhunter >/dev/null 2>&1; then
    ammo_sudo rkhunter --update 2>/dev/null || true
    ammo_sudo rkhunter --propupd 2>/dev/null || true
  fi
}

cmd_antivirus_scan() {
  local infected=0
  cmd_purge_clamav

  if command -v rkhunter >/dev/null 2>&1; then
    ammo_log 'rkhunter check'
    ammo_sudo rkhunter --check --sk 2>/dev/null || infected=1
  fi

  if command -v chkrootkit >/dev/null 2>&1; then
    ammo_log 'chkrootkit'
    ammo_sudo chkrootkit 2>/dev/null | grep -iE 'infected|suspicious' && infected=1 || true
  fi

  ammo_log 'heuristic process scan'
  ps aux 2>/dev/null | grep -iE 'keylog|rat\.|njrat|asyncrat|metasploit|mimikatz' \
    | grep -v grep && infected=1 || ammo_log 'no obvious RAT/keylog process names'

  return "$infected"
}

cmd_antivirus() {
  local opt="${1:-}"
  [[ "$opt" == '-PurgeClam' ]] && cmd_purge_clamav && return 0
  [[ "$opt" == '-Install' ]] && cmd_antivirus_install
  cmd_antivirus_update
  cmd_antivirus_scan
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd_antivirus "$@"
fi