#!/usr/bin/env bash
# ammo.sh — SG ammosecurity stack (replaces memes/Security/michigan.sh)
# Grok Build & the World — phi/thermo/flow desktop clean + full ammosecurity stack
set -euo pipefail

AMMO_VERSION=6
AMMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$AMMO_ROOT/lib/common.sh"

usage() {
  cat <<EOF
ammo.sh v${AMMO_VERSION} — SG ammosecurity (Linux)

  ./ammo.sh -Action All              full stack
  ./ammo.sh -Action Net              firewall + kernel + no SMB
  ./ammo.sh -Action Services         service cleaner (mask junk daemons)
  ./ammo.sh -Action Antivirus        ClamAV + rkhunter scan
  ./ammo.sh -Action Antivirus -Install   install AV packages first
  ./ammo.sh -Action Surveillance     kill keyloggers + HID/mouse guard
  ./ammo.sh -Action FCC              Part 15: conducted voltage + radiated + modulation caps
  ./ammo.sh -Action FCCEmissions     voltage escape + EIRP + outlaw modulator kill only
  ./ammo.sh -Action DeadAir          no rapid encoded fluctuation; silence out-of-function
  ./ammo.sh -Action HumanContact     5V/500mA cap on mice, keyboards, headsets, touch
  ./ammo.sh -Action Clasp            extra lock: USB + Bluetooth + WiFi + NFC + WWAN
  ./ammo.sh -Action Clasp -Unlock    release ingress clasp (admin)
  ./ammo.sh -Action Clipboard        secure clipboard (bash vault)
  ./ammo.sh -Action Clipboard -Daemon   build + run sclipd C daemon
  ./ammo.sh -Action Scrub            remove location metadata leaks
  ./ammo.sh -Action Status           quick status
  ./ammo.sh -Action Help

Daily clipboard:
  source ~/.bashrc   # after install_clipboard.sh
  scopy 'secret' | spaste | sclear
EOF
}

cmd_clipboard() {
  local daemon="${1:-}"
  if [[ "$daemon" == "-Daemon" ]]; then
    local bin="${HOME}/.local/bin/sclipd"
    local svc="${HOME}/.config/systemd/user/sclipd.service"
    ammo_log 'building sclipd daemon'
    ammo_sudo apt-get install -y libssl-dev libargon2-dev gcc libseccomp-dev 2>/dev/null || true
    gcc -O3 -fstack-protector-strong -fPIE -pie -D_FORTIFY_SOURCE=2 -s \
      -o "$bin" "$AMMO_ROOT/sclipd.c" -lcrypto -largon2 -lseccomp -pthread 2>/dev/null || \
    gcc -O3 -o "$bin" "$AMMO_ROOT/sclipd.c" -lcrypto -largon2 -lseccomp
    chmod 700 "$bin"
    mkdir -p "$(dirname "$svc")"
    cat > "$svc" <<EOF
[Unit]
Description=ammosecurity sclipd vault daemon
After=graphical-session.target

[Service]
ExecStart=$bin
Restart=on-failure
NoNewPrivs=yes
PrivateTmp=yes
ProtectSystem=strict
MemoryDenyWriteExecute=yes
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now sclipd.service
    ammo_log "sclipd → $bin"
  else
    bash "$AMMO_ROOT/install_clipboard.sh"
  fi
}

cmd_status() {
  ammo_log '--- SMB ---'
  systemctl is-active smbd nmbd 2>/dev/null || true
  ammo_log '--- firewall ---'
  command -v ufw >/dev/null && ufw status 2>/dev/null | head -5 || true
  ammo_log '--- ingress clasp ---'
  bash "$AMMO_ROOT/modules/ingress_clasp.sh" status 2>/dev/null || true
  ammo_log '--- rfkill ---'
  command -v rfkill >/dev/null && rfkill list 2>/dev/null | head -20 || true
  ammo_log '--- human-contact USB ---'
  lsusb 2>/dev/null | grep -iE 'keyboard|mouse|headset|audio|touch|controller' | head -8 || true
  ammo_log '--- clipboard ---'
  bash "$AMMO_ROOT/secure_clipboard.sh" status 2>/dev/null || true
}

ACTION='Help'
EXTRA=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    -Action) ACTION="${2:-Help}"; shift 2 ;;
    -Install|-Daemon|-Unlock) EXTRA="$1"; shift ;;
    -N) EXTRA="-N"; WORLD_N="${2:-}"; shift 2 ;;
    -h|--help) ACTION='Help'; shift ;;
    *) shift ;;
  esac
done

case "$ACTION" in
  All)
    bash "$AMMO_ROOT/modules/net_harden.sh"
    bash "$AMMO_ROOT/modules/service_cleaner.sh"
    bash "$AMMO_ROOT/modules/antivirus.sh" $EXTRA
    bash "$AMMO_ROOT/modules/anti_surveillance.sh"
    bash "$AMMO_ROOT/modules/fcc_guard.sh"
    bash "$AMMO_ROOT/modules/dead_air_regulator.sh"
    bash "$AMMO_ROOT/modules/human_contact_regulator.sh"
    bash "$AMMO_ROOT/modules/ingress_clasp.sh"
    bash "$AMMO_ROOT/modules/scrub_location.sh"
    cmd_clipboard "$EXTRA"
    ammo_log 'All complete — reload shell for scopy/spaste/sclear'
    ;;
  Net)        bash "$AMMO_ROOT/modules/net_harden.sh" ;;
  Services)   bash "$AMMO_ROOT/modules/service_cleaner.sh" ;;
  Antivirus)  bash "$AMMO_ROOT/modules/antivirus.sh" $EXTRA ;;
  Surveillance) bash "$AMMO_ROOT/modules/anti_surveillance.sh" ;;
  FCC)        bash "$AMMO_ROOT/modules/fcc_guard.sh" ;;
  FCCEmissions) bash "$AMMO_ROOT/modules/fcc_emissions_regulator.sh" ;;
  DeadAir)    bash "$AMMO_ROOT/modules/dead_air_regulator.sh" ;;
  HumanContact) bash "$AMMO_ROOT/modules/human_contact_regulator.sh" ;;
  Clasp)      bash "$AMMO_ROOT/modules/ingress_clasp.sh" "${EXTRA:--lock}" ;;
  Clipboard)  cmd_clipboard "$EXTRA" ;;
  Scrub)      bash "$AMMO_ROOT/modules/scrub_location.sh" ;;
  Status)     cmd_status ;;
  Help|*)     usage ;;
esac