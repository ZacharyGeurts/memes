# Amouranth Shield v2 Design Document
## Hardened Network Isolation & Screen Capture Control

**Version:** 0.9 (Draft for Review)  
**Date:** June 22, 2026  
**Author:** Grok (built by xAI) — for ZacharyGeurts  
**Intended Audience:** ZacharyGeurts + Elon Musk / xAI team (shared for feedback)

## Executive Summary

This document outlines a major hardening extension to the existing AmmoSecurity toolkit (`Security/` directory). It adds defense-in-depth controls for:

- **Network mode enforcement:** WiFi-only, Ethernet-only, Both, or Air-gapped (none), with strict kill-switch logic.
- **Screen capture prevention/resistance:** Block unauthorized screen/window capture while preserving full desktop visibility and full OBS Studio compatibility (PipeWire capture).

The design is hardcore (least privilege, monitoring, fail-closed defaults, multi-layer) yet pragmatic for daily use. It builds directly on existing modules (`net_harden.sh`, `ingress_clasp.sh`, `common.sh`, `secure_clipboard.sh`, etc.) and integrates into `ammo.sh`.

**Goal:** Turn AmmoSecurity into one of the strongest practical desktop privacy toolkits available in 2026.

## Threat Model

**Assumed adversaries:**
- Malware / spyware attempting screen scraping or network exfiltration.
- Local physical/logical attackers with user-level access.
- Remote attackers via compromised apps or network.

**Key assets to protect:**
- Screen content (visual data).
- Network traffic (prevent leaks on wrong interface or when VPN drops).
- Clipboard, processes, and system state (existing strengths).

**Non-goals (for v2):**
- Perfect prevention against kernel-level rootkits or hardware implants.
- Breaking legitimate tools like OBS.

## Goals & Non-Goals

**Primary Goals:**
- Allow user to select WiFi / Ethernet / Both / None with one command and enforce it hard.
- Make unauthorized screen capture extremely difficult for most apps while keeping the desktop visually normal.
- Guarantee OBS Studio continues to work via PipeWire screen capture.
- Integrate cleanly with existing AmmoSecurity stack.
- Add monitoring, logging, and alerts for violations/attempts.

**Non-Goals:**
- GUI-heavy solution (CLI-first).
- Qubes-like VM isolation (optional future layer).
- Breaking X11 apps unnecessarily.

## Architecture

| Component | Purpose | New/Extend | Integration |
|-----------|---------|------------|-------------|
| `net_mode.sh` | WiFi/Ethernet selector + enforcement | New | `ammo.sh -Action NetMode` |
| `screen_guard.sh` | Screen capture hardening + OBS whitelist | New | `ammo.sh -Action ScreenHard` |
| `interface_guard.sh` | nftables interface firewall | New | Called by `net_mode.sh` |
| `obs_compat.sh` | OBS PipeWire setup & permissions | New | `ammo.sh -Action OBSSetup` |
| `ammo_watch.sh` | Background re-enforcement | New (Phase 2) | `ammo.sh -Action Watch` |
| `common.sh` | Logging, nft, portal helpers | Extend | All modules |
| `ammo.sh` | New actions + status | Extend | Main orchestrator |

**Core principles:** fail-closed defaults, defense in depth, observability, reversibility.

## 1. Network Isolation

### Modes

| Mode | Behavior |
|------|----------|
| `wifi` | WiFi only — Ethernet down + rfkill block if needed |
| `ethernet` | Ethernet only — WiFi down + rfkill block |
| `both` | Normal dual-homed (still hardened via `net_harden.sh`) |
| `airgap` | All external interfaces down + local-only nft rules |

### Enforcement layers

1. **Interface control** — `nmcli disconnect`, `ip link set down`, `rfkill block/unblock`
2. **nftables kill-switch** — `inet ammosecurity` table with `allowed_ifaces` set
3. **Watcher** — `ammo_watch.sh` timer re-applies mode if interfaces come back up

### nftables skeleton

```nft
table inet ammosecurity {
    set allowed_ifaces {
        type ifname
        elements = { "wlan0", "lo" }
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
        type filter hook output priority filter; policy drop;
        oifname @allowed_ifaces accept
        ct state established,related accept
        counter drop comment "AmmoSecurity output kill-switch"
    }
}
```

Without `--killswitch`, output policy is `accept` (interface restriction only on input side + set-based output allow list still active but permissive policy).

### Commands

```bash
./amouranth.sh lock
./amouranth.sh net wifi --killswitch
./amouranth.sh screen on
./amouranth.sh obs
./amouranth.sh watch on
./amouranth.sh status
```

## 2. Screen Capture Hardening

**Primary layer (Wayland):** xdg-desktop-portal + PipeWire permissions.

- Revoke screen-capture for all Flatpak apps by default (`ammo_portal_revoke_flatpak_capture`).
- Whitelist OBS (`com.obsproject.Studio`) via `obs_compat.sh`.
- Kill common CLI capture tools; watch for rogue `ffmpeg x11grab`.

**OBS compatibility:** `OBSSetup` installs portal backends, sets `QT_QPA_PLATFORM=wayland`, grants Flatpak screen-capture permission. User adds "Screen Capture (PipeWire)" source in OBS normally.

**No visual degradation** — restrictions are at the capture API / permission level only.

## 3. Integration

```bash
./amouranth.sh lock
./amouranth.sh unlock
./amouranth.sh net <wifi|ethernet|both|airgap> [--killswitch]
./amouranth.sh screen on|off
./amouranth.sh obs
./amouranth.sh watch on|off
./amouranth.sh status
```

`lock` = `net both --killswitch` + `screen on` + core hardening + watcher.  
`all` = full original stack unchanged.  
`ammo.sh` and legacy `-Action` still forward to `amouranth.sh`.

## Implementation Status

| Phase | Status |
|-------|--------|
| **Phase 1** | `net_mode.sh`, `interface_guard.sh`, `screen_guard.sh`, `obs_compat.sh`, `ammo.sh` v2 actions — **done** |
| **Phase 2** | `ammo_watch.sh` timer, `net_mode watch`, Flatpak portal revoke, `violations.log` — **done** |
| **Phase 3** | Multi-DE/OBS testing matrix, shellcheck pass — pending |
| **Phase 4** | README, public release — README done |

## Policy Note

**ClamAV removed** from `antivirus.sh` per project policy. rkhunter, chkrootkit, and process heuristics **retained**. All other modules retained.

## Security Trade-offs

**Strengths:** Multi-layer, fail-closed, OBS functional, reversible.

**Risks:** X11 is fundamentally leaky; some apps need manual whitelisting; nftables misconfig can lock out network.

**Mitigations:** `--killswitch` is explicit; `status` and rollback commands; violations logged.

## Future (post-v2)

- AI-assisted anomaly detection on violation log.
- VPN-only egress (`tun*` / `wg*`) option in `interface_guard.sh`.
- AppArmor profiles for untrusted capture syscalls.
- Qubes-style disposable VMs for high-risk tasks.

## References

- PipeWire + xdg-desktop-portal (2026 Wayland screen sharing path)
- nftables kill-switch patterns (VPN-style)
- OBS Wayland/PipeWire compatibility requirements
- privsec.dev, Kicksecure hardening guides