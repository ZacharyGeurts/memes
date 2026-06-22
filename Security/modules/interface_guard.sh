#!/usr/bin/env bash
# interface_guard — nftables kill-switch (inet amouranth_shield)
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

AMMO_MODE_FILE="${AMMO_STATE}/net_mode"

cmd_nft_reset() {
  ammo_sudo nft delete table $AMMO_NFT_TABLE 2>/dev/null || true
  ammo_sudo nft delete table $AMMO_NFT_LEGACY 2>/dev/null || true
}

cmd_build_allowed() {
  local mode="$1"
  local -n _out=$2
  local iface
  _out=()
  case "$mode" in
    wifi)
      while IFS= read -r iface; do [[ -n "$iface" ]] && _out+=("$iface"); done < <(ammo_detect_wifi_ifaces)
      ;;
    ethernet)
      while IFS= read -r iface; do [[ -n "$iface" ]] && _out+=("$iface"); done < <(ammo_detect_eth_ifaces)
      ;;
    both)
      while IFS= read -r iface; do [[ -n "$iface" ]] && _out+=("$iface"); done < <(ammo_detect_wifi_ifaces)
      while IFS= read -r iface; do [[ -n "$iface" ]] && _out+=("$iface"); done < <(ammo_detect_eth_ifaces)
      ;;
    airgap) ;;
    *)
      ammo_log "unknown nft mode: $mode"
      return 1
      ;;
  esac
  _out+=("lo")
}

cmd_nft_rules() {
  local mode="$1" killswitch="$2" vpn_only="$3"
  local -a allowed=() vpn=()
  local set_elems="" vpn_elems="" policy_drop iface

  cmd_build_allowed "$mode" allowed || return 1

  if [[ "$vpn_only" == 1 ]]; then
    while IFS= read -r iface; do [[ -n "$iface" ]] && vpn+=("$iface"); done < <(ammo_detect_vpn_ifaces)
    vpn+=("lo")
    allowed=("${vpn[@]}")
  fi

  for iface in "${allowed[@]}"; do
    set_elems+="\"$iface\", "
  done
  set_elems="${set_elems%, }"

  policy_drop='policy accept;'
  [[ -n "$killswitch" ]] && policy_drop='policy drop;'

  cat <<EOF
table $AMMO_NFT_TABLE {
  set allowed_ifaces {
    type ifname
    elements = { $set_elems }
  }
  chain input {
    type filter hook input priority filter; policy drop;
    iifname lo accept
    iifname @allowed_ifaces ct state established,related accept
    counter drop comment "Amouranth Shield input"
  }
  chain forward {
    type filter hook forward priority filter; policy drop;
  }
  chain output {
    type filter hook output priority filter; $policy_drop
    oifname @allowed_ifaces accept
    ct state established,related accept
    counter drop comment "Amouranth Shield kill-switch"
  }
}
EOF
}

cmd_nft_apply_mode() {
  local mode="${1:-airgap}"
  local killswitch="" vpn_only=0
  shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --killswitch) killswitch=--killswitch ;;
      --vpn-only)   vpn_only=1 ;;
    esac
    shift
  done

  if ! ammo_nft_available; then
    ammo_log 'nft missing — install: sudo apt install nftables'
    return 1
  fi

  local rules
  rules="$(cmd_nft_rules "$mode" "$killswitch" "$vpn_only")" || return 1

  if [[ "$AMMO_DRY_RUN" == 1 ]]; then
    ammo_log "dry-run nft rules mode=$mode killswitch=${killswitch:-off} vpn_only=$vpn_only"
    printf '%s\n' "$rules"
    return 0
  fi

  cmd_nft_reset
  printf '%s\n' "$rules" | ammo_sudo nft -f -

  ammo_state_ensure
  echo "$mode" | ammo_sudo tee "$AMMO_MODE_FILE" >/dev/null 2>&1 \
    || echo "$mode" >"${HOME}/.local/share/ammosecurity/net_mode" 2>/dev/null || true
  ammo_log_mode_change "nft applied mode=$mode killswitch=${killswitch:-off} vpn_only=$vpn_only table=$AMMO_NFT_TABLE"
}

cmd_interface_guard_status() {
  if ammo_nft_available; then
    ammo_sudo nft list table $AMMO_NFT_TABLE 2>/dev/null \
      || ammo_sudo nft list table $AMMO_NFT_LEGACY 2>/dev/null \
      || ammo_log 'nft table not active'
  fi
  [[ -f "$AMMO_MODE_FILE" ]] && ammo_log "stored mode: $(cat "$AMMO_MODE_FILE")" || true
  ip -br link 2>/dev/null | head -10 || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ "${1:-}" == status ]]; then
    cmd_interface_guard_status
  elif [[ "${1:-}" == dry-run ]]; then
    AMMO_DRY_RUN=1
    cmd_nft_apply_mode "${2:-airgap}" "${@:3}"
  else
    cmd_nft_apply_mode "$@"
  fi
fi