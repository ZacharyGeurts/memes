#!/usr/bin/env bash
# sg_trust_nobody_scan — no ClamAV, no cloud AV, no third-party trust. Local heuristics only.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

cmd_process_heuristics() {
  sg_log 'trust nobody: process/cmdline heuristics'
  local hit=0
  ps aux 2>/dev/null | grep -iE 'keylog|rat\.|njrat|asyncrat|metasploit|mimikatz|cryptominer|xmrig|kinsing' \
    | grep -v grep && hit=1 || sg_log 'no obvious hostile process names'

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    sg_log "SUSPICIOUS: $line"
    hit=1
  done < <(pgrep -af 'LD_PRELOAD|/tmp/\./|/dev/shm/\.' 2>/dev/null || true)
  return "$hit"
}

cmd_setuid_audit() {
  sg_log 'trust nobody: unexpected setuid binaries (last 24h)'
  find /usr /bin /sbin -perm -4000 -mtime -1 2>/dev/null | head -20 || true
}

cmd_auth_audit() {
  sg_log 'trust nobody: auth surface audit'
  [[ -f "${HOME}/.ssh/authorized_keys" ]] && {
    sg_log 'authorized_keys present — review:'
    wc -l "${HOME}/.ssh/authorized_keys"
  }
  sg_sudo awk -F: '($3==0){print}' /etc/passwd 2>/dev/null || true
}

cmd_shm_tmp_sweep() {
  sg_log 'trust nobody: hot writable paths'
  find /tmp /var/tmp /dev/shm -maxdepth 2 -type f -executable -mtime -1 2>/dev/null | head -15 || true
}

cmd_purge_clam_junk() {
  sg_log 'purge bogus ClamAV if some distro shoved it on'
  for pkg in clamav clamav-daemon clamav-freshclam; do
    dpkg -l "$pkg" &>/dev/null && sg_sudo apt-get remove --purge -y "$pkg" 2>/dev/null && sg_log "removed $pkg" || true
  done
  sg_sudo systemctl stop clamav-freshclam clamav-daemon 2>/dev/null || true
  sg_sudo systemctl mask clamav-freshclam clamav-daemon 2>/dev/null || true
}

cmd_trust_nobody_scan() {
  local purge="${1:-}"
  [[ "$purge" == '-PurgeClam' ]] && cmd_purge_clam_junk
  local bad=0
  cmd_process_heuristics || bad=1
  cmd_setuid_audit
  cmd_auth_audit
  cmd_shm_tmp_sweep
  sg_log 'trust nobody scan done — zero third-party AV trust'
  return "$bad"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd_trust_nobody_scan "$@"
fi