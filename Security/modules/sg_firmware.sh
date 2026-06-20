#!/usr/bin/env bash
# sg_firmware — WE are the firmware layer. Drop every third-party security overhead.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

# Third-party security bloat — not welcome. sg_build covers it.
PURGE_PKGS=(
  clamav clamav-daemon clamav-freshclam clamav-unofficial-sigs
  rkhunter chkrootkit aide aide-common tiger lynis
  fail2ban fail2ban-server
  ufw gufw
  snort suricata crowdsec
  maldet linux-malware-detect
  sophos-av sophosav
  eset nod32
  bitdefender
  lmd
  apparmor-profiles apparmor-utils
  unattended-upgrades
)

PURGE_SERVICES=(
  clamav-freshclam clamav-daemon clamav-daemon.socket
  fail2ban ufw
  rkhunter chkrootkit
  snort suricata crowdsec
  apparmor apparmor_parser
)

cmd_drop_third_party_pkgs() {
  sg_log 'firmware: purge third-party security packages'
  if ! command -v dpkg >/dev/null 2>&1; then
    sg_log 'no dpkg — skip package purge'
    return 0
  fi
  local pkg
  for pkg in "${PURGE_PKGS[@]}"; do
    dpkg -l "$pkg" &>/dev/null || continue
    sg_sudo apt-get remove --purge -y "$pkg" 2>/dev/null && sg_log "purged $pkg" || true
  done
  sg_sudo apt-get autoremove -y 2>/dev/null || true
}

cmd_mask_foreign_services() {
  sg_log 'firmware: mask foreign security daemons'
  local svc
  for svc in "${PURGE_SERVICES[@]}"; do
    sg_service_off "$svc"
  done
}

cmd_assert_sg_owns_firewall() {
  sg_log 'firmware: sg_build owns net policy — raw iptables, no ufw middleman'
  sg_sudo systemctl stop ufw 2>/dev/null || true
  sg_sudo systemctl mask ufw 2>/dev/null || true
  if command -v iptables >/dev/null 2>&1; then
    sg_sudo iptables -P INPUT DROP 2>/dev/null || true
    sg_sudo iptables -P FORWARD DROP 2>/dev/null || true
    sg_sudo iptables -P OUTPUT ACCEPT 2>/dev/null || true
    sg_sudo iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
      sg_sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
    sg_sudo iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || \
      sg_sudo iptables -A INPUT -i lo -j ACCEPT 2>/dev/null || true
  fi
}

cmd_local_heuristics() {
  sg_log 'firmware: local heuristics (ours only)'
  ps aux 2>/dev/null | grep -iE 'keylog|rat\.|njrat|metasploit|mimikatz|xmrig|kinsing' | grep -v grep || true
  pgrep -af 'LD_PRELOAD|/tmp/\./|/dev/shm/\.' 2>/dev/null | head -10 || true
  find /tmp /var/tmp /dev/shm -maxdepth 2 -type f -executable -mtime -1 2>/dev/null | head -10 || true
}

cmd_firmware_stamp() {
  local stamp='/var/lib/sg_build/firmware-layer'
  sg_sudo mkdir -p /var/lib/sg_build 2>/dev/null || true
  date -Is 2>/dev/null | sg_sudo tee "$stamp" >/dev/null || sg_sudo sh -c "date > $stamp"
  sg_log 'sg_build is the firmware layer — no foreign security stack'
}

cmd_sg_firmware() {
  sg_log '=== SG FIRMWARE LAYER — drop everyone, we own the stack ==='
  cmd_drop_third_party_pkgs
  cmd_mask_foreign_services
  cmd_assert_sg_owns_firewall
  cmd_local_heuristics
  cmd_firmware_stamp
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd_sg_firmware "$@"
fi