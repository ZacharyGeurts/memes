#!/usr/bin/env bash
# antivirus — real on-disk scanning (ClamAV + rootkit checks), not vibes
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

cmd_antivirus_install() {
  if ! command -v apt-get >/dev/null 2>&1; then
    ammo_log 'apt-get missing — install clamav + rkhunter manually'
    return 0
  fi
  ammo_log 'installing ClamAV + rkhunter + chkrootkit'
  ammo_sudo apt-get update -qq
  ammo_sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    clamav clamav-daemon freshclam rkhunter chkrootkit 2>/dev/null || true
}

cmd_antivirus_update() {
  ammo_log 'updating malware signatures'
  if command -v freshclam >/dev/null 2>&1; then
    ammo_sudo freshclam 2>/dev/null || ammo_sudo freshclam --user=clamav 2>/dev/null || true
  fi
  if command -v rkhunter >/dev/null 2>&1; then
    ammo_sudo rkhunter --update 2>/dev/null || true
    ammo_sudo rkhunter --propupd 2>/dev/null || true
  fi
}

cmd_antivirus_scan() {
  local targets=("${HOME}" /tmp /var/tmp)
  local infected=0

  if command -v clamscan >/dev/null 2>&1; then
    ammo_log "ClamAV scan: ${targets[*]}"
    if ! clamscan -r --infected --bell "${targets[@]}" 2>/dev/null; then
      infected=1
      ammo_log 'ClamAV: infected files found — review output above'
    else
      ammo_log 'ClamAV: clean'
    fi
  else
    ammo_log 'clamscan not installed — run: ammo.sh -Action Antivirus -Install'
  fi

  if command -v rkhunter >/dev/null 2>&1; then
    ammo_log 'rkhunter check'
    ammo_sudo rkhunter --check --sk 2>/dev/null || infected=1
  fi

  if command -v chkrootkit >/dev/null 2>&1; then
    ammo_log 'chkrootkit'
    ammo_sudo chkrootkit 2>/dev/null | grep -i 'infected\|suspicious' && infected=1 || true
  fi

  # Quick process heuristics
  ammo_log 'heuristic process scan'
  ps aux 2>/dev/null | grep -iE 'keylog|rat\.|njrat|asyncrat|metasploit|mimikatz' \
    | grep -v grep && infected=1 || ammo_log 'no obvious RAT/keylog process names'

  return "$infected"
}

cmd_antivirus() {
  local install="${1:-}"
  if [[ "$install" == "-Install" ]]; then
    cmd_antivirus_install
  fi
  cmd_antivirus_update
  cmd_antivirus_scan
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd_antivirus "$@"
fi