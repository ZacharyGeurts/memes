#!/usr/bin/env bash
# interface_guard — nftables kill-switch per allowed interfaces (AmmoSecurity v2)
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

AMMO_NFT_TABLE='inet ammosecurity'
AMMO_MODE_FILE="${AMMO_STATE}/net_mode"

cmd_nft_reset() {
  ammo_sudo nft delete table $AMMO_NFT_TABLE 2>/dev/null || true
}

cmd_nft_apply_mode() {
  local mode="$1"
  shift
  local killswitch="${1:-}"
  local -a allowed=()
  local iface

  case "$mode" in
    wifi)
      while IFS= read -r iface; do [[ -n "$iface" ]] && allowed+=("$iface"); done < <(ammo_detect_wifi_ifaces)
      allowed+=("lo")
      ;;
    ethernet)
      while IFS= read -r iface; do [[ -n "$iface" ]] && allowed+=("$iface"); done < <(ammo_detect_eth_ifaces)
      allowed+=("lo")
      ;;
    both)
      while IFS= read -r iface; do [[ -n "$iface" ]] && allowed+=("$iface"); done < <(ammo_detect_wifi_ifaces)
      while IFS= read -r iface; do [[ -n "$iface" ]] && allowed+=("$iface"); done < <(ammo_detect_eth_ifaces)
      allowed+=("lo")
      ;;
    airgap)
      allowed=("lo")
      ;;
    *)
      ammo_log "unknown nft mode: $mode"
      return 1
      ;;
  esac

  if ! ammo_nft_available; then
    ammo_log 'nft missing — install: sudo apt install nftables'
    return 1
  fi

  cmd_nft_reset
  local set_elems=""
  for iface in "${allowed[@]}"; do
    set_elems+="\"$iface\", "
  done
  set_elems="${set_elems%, }"

  local policy_drop='policy accept;'
  [[ -n "$killswitch" || "$killswitch" == '--killswitch' ]] && policy_drop='policy drop;'

  ammo_sudo nft -f - <<EOF
table $AMMO_NFT_TABLE {
  set allowed_ifaces {
    type ifname
    elements = { $set_elems }
  }
  chain input {
    type filter hook input priority filter; policy drop;
    iifname lo accept
    iifname @allowed_ifaces ct state established,related accept
    counter drop comment "AmmoSecurity input kill-switch"
  }
  chain forward {
    type filter hook forward priority filter; policy drop;
  }
  chain output {
    type filter hook output priority filter; $policy_drop
    oifname @allowed_ifaces accept
    ct state established,related accept
    counter drop comment "AmmoSecurity output kill-switch"
  }
}
EOF

  ammo_state_ensure
  echo "$mode" | ammo_sudo tee "$AMMO_MODE_FILE" >/dev/null 2>&1 || echo "$mode" >"${HOME}/.local/share/ammosecurity/net_mode" 2>/dev/null || true
  ammo_log "nftables mode=$mode allowed={${allowed[*]}} killswitch=${killswitch:-off}"
}

cmd_interface_guard_status() {
  if ammo_nft_available; then
    ammo_sudo nft list table $AMMO_NFT_TABLE 2>/dev/null || ammo_log 'nft table not active'
  fi
  [[ -f "$AMMO_MODE_FILE" ]] && ammo_log "stored mode: $(cat "$AMMO_MODE_FILE")" || true
  ip -br link 2>/dev/null | head -10 || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ "${1:-}" == status ]]; then
    cmd_interface_guard_status
  else
    cmd_nft_apply_mode "${1:-both}" "${2:-}"
  fi
fi