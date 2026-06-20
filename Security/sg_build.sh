#!/usr/bin/env bash
# sg_build.sh — SG firmware layer. Grok Build & the World. We cover our own shit.
set -euo pipefail

SG_VERSION=8
SG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SG_ROOT/lib/common.sh"

usage() {
  cat <<EOF
sg_build.sh v${SG_VERSION} — SG firmware layer (Linux)

No ClamAV. No ufw. No fail2ban. No third-party AV. sg_build IS the firmware.

  ./sg_build.sh -Action Firmware     drop foreign security + assert our layer
  ./sg_build.sh -Action All          firmware + full stack
  ./sg_build.sh -Action World [-N N] phi/thermo/flow/field (30 updates)
  ./sg_build.sh -Action FCC | DeadAir | Clasp [-Unlock] | Clipboard
  ./sg_build.sh -Action Status

Legacy: ammo.sh / michigan.sh forward here.
EOF
}

cmd_clipboard() {
  local daemon="${1:-}"
  if [[ "$daemon" == '-Daemon' ]]; then
    local bin="${HOME}/.local/bin/sg_clipd"
    local svc="${HOME}/.config/systemd/user/sg_clipd.service"
    command -v gcc >/dev/null || { sg_log 'need gcc for sg_clipd'; return 1; }
    for lib in libssl libargon2 libseccomp; do
      ldconfig -p 2>/dev/null | grep -q "$lib" || sg_log "warn: $lib dev headers may be missing"
    done
    gcc -O3 -fstack-protector-strong -o "$bin" "$SG_ROOT/sg_clipd.c" -lcrypto -largon2 -lseccomp 2>/dev/null || \
      gcc -O3 -o "$bin" "$SG_ROOT/sg_clipd.c" -lcrypto -largon2
    chmod 700 "$bin"
    mkdir -p "$(dirname "$svc")"
    cat > "$svc" <<EOF
[Unit]
Description=sg_build clipboard vault
[Service]
ExecStart=$bin
Restart=on-failure
NoNewPrivs=yes
PrivateTmp=yes
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now sg_clipd.service
  else
    bash "$SG_ROOT/sg_install_clipboard.sh"
  fi
}

cmd_status() {
  [[ -f /var/lib/sg_build/firmware-layer ]] && sg_log "firmware stamped: $(cat /var/lib/sg_build/firmware-layer 2>/dev/null)"
  bash "$SG_ROOT/modules/sg_ingress_clasp.sh" status 2>/dev/null || true
  bash "$SG_ROOT/sg_clipboard.sh" status 2>/dev/null || true
}

ACTION='Help'
EXTRA=''
WORLD_N=''
M="$SG_ROOT/modules"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -Action) ACTION="${2:-Help}"; shift 2 ;;
    -Daemon|-Unlock) EXTRA="$1"; shift ;;
    -N) WORLD_N="${2:-}"; shift 2 ;;
    -h|--help) ACTION='Help'; shift ;;
    *) shift ;;
  esac
done

case "$ACTION" in
  Firmware|TrustNobody|Antivirus)
    bash "$M/sg_firmware.sh"
    ;;
  All)
    bash "$M/sg_firmware.sh"
    bash "$M/sg_net_harden.sh"
    bash "$M/sg_service_cleaner.sh"
    bash "$M/sg_anti_surveillance.sh"
    bash "$M/sg_fcc_guard.sh"
    bash "$M/sg_dead_air.sh"
    bash "$M/sg_grok_world.sh" all
    bash "$M/sg_human_contact.sh"
    bash "$M/sg_ingress_clasp.sh"
    bash "$M/sg_scrub_location.sh"
    cmd_clipboard "$EXTRA"
    sg_log 'firmware layer complete'
    ;;
  Net)           bash "$M/sg_net_harden.sh" ;;
  Services)      bash "$M/sg_service_cleaner.sh" ;;
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