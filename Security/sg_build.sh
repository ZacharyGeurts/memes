#!/usr/bin/env bash
# sg_build.sh — Grok Build & the World · SG security stack (trust nobody, no ClamAV)
set -euo pipefail

SG_VERSION=7
SG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SG_ROOT/lib/common.sh"

usage() {
  cat <<EOF
sg_build.sh v${SG_VERSION} — SG security (Linux)

  ./sg_build.sh -Action All
  ./sg_build.sh -Action TrustNobody      local heuristics only — no ClamAV (-PurgeClam)
  ./sg_build.sh -Action World            30 phi/thermo/flow/field updates (-N 12)
  ./sg_build.sh -Action FCC              Part 15 emissions envelope
  ./sg_build.sh -Action DeadAir          no rapid encoded fluctuation
  ./sg_build.sh -Action Clasp [-Unlock]  USB/BT/WiFi/NFC lock
  ./sg_build.sh -Action Clipboard [-Daemon]
  ./sg_build.sh -Action Status

Legacy: ./ammo.sh and ./michigan.sh forward here.
EOF
}

cmd_clipboard() {
  local daemon="${1:-}"
  if [[ "$daemon" == '-Daemon' ]]; then
    local bin="${HOME}/.local/bin/sg_clipd"
    local svc="${HOME}/.config/systemd/user/sg_clipd.service"
    sg_log 'building sg_clipd daemon'
    sg_sudo apt-get install -y libssl-dev libargon2-dev gcc libseccomp-dev 2>/dev/null || true
    gcc -O3 -fstack-protector-strong -fPIE -pie -D_FORTIFY_SOURCE=2 -s \
      -o "$bin" "$SG_ROOT/sg_clipd.c" -lcrypto -largon2 -lseccomp -pthread 2>/dev/null || \
    gcc -O3 -o "$bin" "$SG_ROOT/sg_clipd.c" -lcrypto -largon2 -lseccomp
    chmod 700 "$bin"
    mkdir -p "$(dirname "$svc")"
    cat > "$svc" <<EOF
[Unit]
Description=sg_build clipboard vault daemon
After=graphical-session.target
[Service]
ExecStart=$bin
Restart=on-failure
NoNewPrivs=yes
PrivateTmp=yes
ProtectSystem=strict
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now sg_clipd.service
    sg_log "sg_clipd → $bin"
  else
    bash "$SG_ROOT/sg_install_clipboard.sh"
  fi
}

cmd_status() {
  bash "$SG_ROOT/modules/sg_ingress_clasp.sh" status 2>/dev/null || true
  command -v rfkill >/dev/null && rfkill list 2>/dev/null | head -15 || true
  bash "$SG_ROOT/sg_clipboard.sh" status 2>/dev/null || true
}

ACTION='Help'
EXTRA=''
WORLD_N=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    -Action) ACTION="${2:-Help}"; shift 2 ;;
    -PurgeClam|-Install|-Daemon|-Unlock) EXTRA="$1"; shift ;;
    -N) WORLD_N="${2:-}"; shift 2 ;;
    -h|--help) ACTION='Help'; shift ;;
    *) shift ;;
  esac
done

M="$SG_ROOT/modules"

case "$ACTION" in
  All)
    bash "$M/sg_net_harden.sh"
    bash "$M/sg_service_cleaner.sh"
    bash "$M/sg_trust_nobody_scan.sh" -PurgeClam
    bash "$M/sg_anti_surveillance.sh"
    bash "$M/sg_fcc_guard.sh"
    bash "$M/sg_dead_air.sh"
    bash "$M/sg_grok_world.sh" all
    bash "$M/sg_human_contact.sh"
    bash "$M/sg_ingress_clasp.sh"
    bash "$M/sg_scrub_location.sh"
    cmd_clipboard "$EXTRA"
    sg_log 'sg_build All complete'
    ;;
  Net)           bash "$M/sg_net_harden.sh" ;;
  Services)      bash "$M/sg_service_cleaner.sh" ;;
  TrustNobody|Antivirus) bash "$M/sg_trust_nobody_scan.sh" "$EXTRA" ;;
  Surveillance)  bash "$M/sg_anti_surveillance.sh" ;;
  FCC)           bash "$M/sg_fcc_guard.sh" ;;
  FCCEmissions)  bash "$M/sg_fcc_emissions.sh" ;;
  DeadAir)       bash "$M/sg_dead_air.sh" ;;
  World)         bash "$M/sg_grok_world.sh" "${WORLD_N:-all}" ;;
  HumanContact)  bash "$M/sg_human_contact.sh" ;;
  Clasp)         bash "$M/sg_ingress_clasp.sh" "${EXTRA:--lock}" ;;
  Clipboard)     cmd_clipboard "$EXTRA" ;;
  Scrub)         bash "$M/sg_scrub_location.sh" ;;
  Status)        cmd_status ;;
  Help|*)        usage ;;
esac