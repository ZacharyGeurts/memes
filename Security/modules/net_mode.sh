#!/usr/bin/env bash
# net_mode — WiFi / Ethernet / Both / Airgap enforcement
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
MOD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cmd_iface_down() {
  local iface="$1"
  [[ "$AMMO_DRY_RUN" == 1 ]] && { ammo_log "dry-run: down $iface"; return 0; }
  ammo_sudo ip link set "$iface" down 2>/dev/null || true
  command -v nmcli >/dev/null && ammo_sudo nmcli device disconnect "$iface" 2>/dev/null || true
  ammo_log "down: $iface"
}

cmd_iface_up() {
  local iface="$1"
  [[ "$AMMO_DRY_RUN" == 1 ]] && { ammo_log "dry-run: up $iface"; return 0; }
  ammo_sudo ip link set "$iface" up 2>/dev/null || true
  command -v nmcli >/dev/null && ammo_sudo nmcli device connect "$iface" 2>/dev/null || true
  ammo_log "up: $iface"
}

cmd_rfkill_wifi() {
  local state="$1"
  command -v rfkill >/dev/null 2>&1 || return 0
  if [[ "$state" == block ]]; then
    rfkill list wifi 2>/dev/null | awk '/^[0-9]+:/{print $1}' | tr -d ':' | while read -r idx; do
      [[ -n "$idx" ]] && ammo_sudo rfkill block "$idx" 2>/dev/null || true
    done
  else
    rfkill list wifi 2>/dev/null | awk '/^[0-9]+:/{print $1}' | tr -d ':' | while read -r idx; do
      [[ -n "$idx" ]] && ammo_sudo rfkill unblock "$idx" 2>/dev/null || true
    done
  fi
}

cmd_apply_nft() {
  local mode="$1" killswitch="$2"
  local -a nft_args=("$mode")
  [[ -n "$killswitch" ]] && nft_args+=(--killswitch)
  [[ "$AMMO_VPN_ONLY" == 1 ]] && nft_args+=(--vpn-only)
  ammo_run_module "interface_guard" bash "$MOD/interface_guard.sh" "${nft_args[@]}"
}

cmd_apply_mode() {
  local mode="$1"
  local killswitch="${2:-}"
  local w e

  ammo_log "net_mode: applying $mode dry_run=$AMMO_DRY_RUN vpn_only=$AMMO_VPN_ONLY"
  [[ "$AMMO_DRY_RUN" != 1 ]] && bash "$MOD/net_harden.sh"

  case "$mode" in
    wifi)
      cmd_rfkill_wifi unblock
      while IFS= read -r w; do [[ -n "$w" ]] && cmd_iface_up "$w"; done < <(ammo_detect_wifi_ifaces)
      while IFS= read -r e; do [[ -n "$e" ]] && cmd_iface_down "$e"; done < <(ammo_detect_eth_ifaces)
      ammo_wifi_mac_randomize
      ;;
    ethernet)
      cmd_rfkill_wifi block
      while IFS= read -r e; do [[ -n "$e" ]] && cmd_iface_up "$e"; done < <(ammo_detect_eth_ifaces)
      while IFS= read -r w; do [[ -n "$w" ]] && cmd_iface_down "$w"; done < <(ammo_detect_wifi_ifaces)
      ;;
    both)
      cmd_rfkill_wifi unblock
      while IFS= read -r w; do [[ -n "$w" ]] && cmd_iface_up "$w"; done < <(ammo_detect_wifi_ifaces)
      while IFS= read -r e; do [[ -n "$e" ]] && cmd_iface_up "$e"; done < <(ammo_detect_eth_ifaces)
      ammo_wifi_mac_randomize
      ;;
    airgap)
      cmd_rfkill_wifi block
      while IFS= read -r w; do [[ -n "$w" ]] && cmd_iface_down "$w"; done < <(ammo_detect_wifi_ifaces)
      while IFS= read -r e; do [[ -n "$e" ]] && cmd_iface_down "$e"; done < <(ammo_detect_eth_ifaces)
      ;;
    *)
      ammo_log 'usage: wifi | ethernet | both | airgap | status | watch | dry-run <mode>'
      return 1
      ;;
  esac

  cmd_apply_nft "$mode" "$killswitch"
  ammo_log_mode_change "net_mode=$mode killswitch=${killswitch:-off}"
}

cmd_net_watch() {
  local mode w e
  mode="$(ammo_state_read net_mode 2>/dev/null || true)"
  [[ -z "$mode" || "$mode" == status ]] && return 0

  case "$mode" in
    wifi)
      while IFS= read -r e; do
        [[ -z "$e" ]] && continue
        if ammo_iface_is_up "$e"; then
          cmd_iface_down "$e"
          ammo_log_violation "wifi-only: forced down $e"
        fi
      done < <(ammo_detect_eth_ifaces)
      ;;
    ethernet)
      cmd_rfkill_wifi block
      while IFS= read -r w; do
        [[ -z "$w" ]] && continue
        if ammo_iface_is_up "$w"; then
          cmd_iface_down "$w"
          ammo_log_violation "ethernet-only: forced down $w"
        fi
      done < <(ammo_detect_wifi_ifaces)
      ;;
    airgap)
      cmd_rfkill_wifi block
      while IFS= read -r w; do
        [[ -n "$w" ]] && ammo_iface_is_up "$w" && cmd_iface_down "$w" && ammo_log_violation "airgap: down $w"
      done < <(ammo_detect_wifi_ifaces)
      while IFS= read -r e; do
        [[ -n "$e" ]] && ammo_iface_is_up "$e" && cmd_iface_down "$e" && ammo_log_violation "airgap: down $e"
      done < <(ammo_detect_eth_ifaces)
      ;;
    both) ;;
    *) return 0 ;;
  esac

  if ammo_nft_available && ! ammo_sudo nft list table $AMMO_NFT_TABLE &>/dev/null; then
    bash "$MOD/interface_guard.sh" "$mode" --killswitch
    ammo_log_violation "nft table missing — re-applied mode=$mode"
  fi
}

cmd_net_mode() {
  local mode="${1:-status}"
  local flag="${2:-}"
  case "$mode" in
    watch) cmd_net_watch; return 0 ;;
    dry-run)
      AMMO_DRY_RUN=1
      cmd_apply_mode "${2:-airgap}" "${3:-}"
      return 0
      ;;
    status)
      bash "$MOD/interface_guard.sh" status 2>/dev/null || true
      ammo_log "prefs net: $(ammo_prefs_net_mode 2>/dev/null || echo n/a)"
      ip -br addr 2>/dev/null | head -12 || true
      rfkill list 2>/dev/null | head -12 || true
      return 0
      ;;
  esac
  cmd_apply_mode "$mode" "$flag"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd_net_mode "$@"
fi