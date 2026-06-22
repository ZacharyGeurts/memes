# Amouranth Shield v2.0
## Technical Consultancy Report — Desktop Defense Stack

**Classification:** Internal · Sole authoritative documentation for `SG/Security/`  
**Engagement scope:** `SG/Security/` exclusively — no sibling directories  
**Primary control plane:** `./ammo.sh`  
**Report date:** June 2026  
**System version:** 2.0

---

## Document control

| Field | Value |
|-------|-------|
| Canonical deployment path | `SG/Security/` |
| Documentation repository | `SG/BarbieGirl/readme.md` (this document) |
| Supplementary in-tree reference | `SG/Security/AMMOSECURITY_V2_DESIGN.md` |
| License | MIT — Zachary Robert Geurts (`SG/Security/LICENSE`) |

This report constitutes the **only long-form information artefact** commissioned for the Security folder. Operators, reviewers, and integrators should treat it as the single source of truth for system behaviour, policy, and operational procedure.

---

## Table of contents

1. [Executive summary](#1-executive-summary)
2. [Engagement scope and deliverables](#2-engagement-scope-and-deliverables)
3. [Governance model: mandatory controls versus discretionary exposure](#3-governance-model-mandatory-controls-versus-discretionary-exposure)
4. [Repository structure](#4-repository-structure)
5. [Operational onboarding](#5-operational-onboarding)
6. [Human–machine interface: tick-box control surface](#6-humanmachine-interface-tick-box-control-surface)
7. [Command interface specification (`ammo.sh`)](#7-command-interface-specification-ammosh)
8. [System architecture](#8-system-architecture)
9. [Shared runtime library (`lib/common.sh`)](#9-shared-runtime-library-libcommonsh)
10. [Network segmentation and egress control](#10-network-segmentation-and-egress-control)
11. [Visual data protection and authorised capture exception](#11-visual-data-protection-and-authorised-capture-exception)
12. [Clipboard confidentiality subsystem](#12-clipboard-confidentiality-subsystem)
13. [Physical and logical ingress control](#13-physical-and-logical-ingress-control)
14. [Module catalogue](#14-module-catalogue)
15. [Grok World environmental hygiene programme](#15-grok-world-environmental-hygiene-programme)
16. [State persistence, preference storage, and audit logging](#16-state-persistence-preference-storage-and-audit-logging)
17. [Cross-platform artefacts (Windows / PowerShell)](#17-cross-platform-artefacts-windows--powershell)
18. [Risk assessment and residual exposure](#18-risk-assessment-and-residual-exposure)
19. [Incident response and diagnostic protocol](#19-incident-response-and-diagnostic-protocol)
20. [Maturity roadmap](#20-maturity-roadmap)
21. [Legal and licensing](#21-legal-and-licensing)

---

## 1. Executive summary

**Amouranth Shield** (successor branding to AmmoSecurity) is a bash-orchestrated desktop hardening platform for Linux environments. The engagement consolidates disparate shell modules into a unified **defence-in-depth** posture administrable through a single command router (`ammo.sh`) and an optional pure-shell tick-box interface (`modules/ammo_gui.sh`).

The system implements a **fail-closed governance principle**: protective controls are applied by default; network connectivity, screen-capture exceptions, ingress release, and optional egress policies require explicit operator opt-in. This design reduces ambient attack surface while preserving reversibility and observability.

### Core capability domains

| Domain | Mechanism | Primary modules |
|--------|-----------|-----------------|
| Network segmentation | Interface state + nftables kill-switch + periodic re-enforcement | `net_mode.sh`, `interface_guard.sh`, `ammo_watch.sh` |
| Visual data protection | Portal permission revocation + process interdiction; OBS whitelist | `screen_guard.sh`, `obs_compat.sh` |
| Ingress control | udev/modprobe clasp over USB, BT, WiFi, NFC, WWAN, Thunderbolt | `ingress_clasp.sh` |
| Host hardening | Kernel sysctl, firewall, SMB elimination, service masking | `net_harden.sh`, `service_cleaner.sh` |
| Surveillance resistance | Keylogger interdiction, HID hot-plug guard | `anti_surveillance.sh` |
| RF and conducted emissions policy | rfkill, rogue AP suppression, SDR sweep, Part 15–inspired ceilings | `fcc_guard.sh`, `fcc_emissions_regulator.sh` |
| Power-rail stability | Anti-encoding dead-air regulation | `dead_air_regulator.sh` |
| Human-interface electrical bounds | USB 5 V / 500 mA ceiling on body-contact classes | `human_contact_regulator.sh` |
| Clipboard confidentiality | RAM-resident encrypted vault; manager suppression | `secure_clipboard.sh`, `install_clipboard.sh` |
| Malware posture | ClamAV **excluded by policy**; rkhunter/chkrootkit retained | `antivirus.sh` |

### Principal finding

The platform is architecturally sound for operator-controlled workstations requiring **graduated exposure**: maximum lockdown at idle, selective capability restoration under informed consent. Residual risk concentrates in environments lacking root privilege, Wayland portal infrastructure, or nftables — each mitigable through documented fallback paths.

---

## 2. Engagement scope and deliverables

### In scope

- All artefacts under `SG/Security/`
- Behavioural specification of `ammo.sh` and dependent modules
- Policy interpretation (mandatory versus discretionary controls)
- State paths, audit logs, and operational procedures

### Explicitly out of scope

- `SG/memes/`, `SG/AMOURANTHRTX/`, and all directories external to `Security/`
- Third-party distribution packaging beyond in-tree scripts
- Formal certification (Common Criteria, FIPS, etc.)

### Entry-point hierarchy

| Artefact | Consultant recommendation |
|----------|----------------------------|
| `ammo.sh` | **Primary** — all new integrations |
| `amouranth.sh` | Legacy alias; forwards to `ammo.sh` |
| `michigan.sh` | Legacy alias; forwards to `ammo.sh` |

---

## 3. Governance model: mandatory controls versus discretionary exposure

The system's control philosophy separates **non-negotiable baseline protections** from **discretionary exposure toggles**. This bifurcation is enforced programmatically in `ammo_gui.sh` and mirrored in `cmd_lock` / `cmd_secure` within `ammo.sh`.

### 3.1 Mandatory control set (baseline posture)

The following modules execute on: menu startup, toggle application (`gui_apply`), `./ammo.sh secure`, and `./ammo.sh lock`.

| Control objective | Implementing module |
|-------------------|---------------------|
| Kernel and perimeter hardening | `net_harden.sh` |
| Hostile/leaky service suppression | `service_cleaner.sh` |
| Antivirus policy enforcement (ClamAV removal) | `antivirus.sh -PurgeClam` |
| Input-capture and HID threat reduction | `anti_surveillance.sh` |
| RF and rogue infrastructure suppression | `fcc_guard.sh` |
| Power-rail encoding prevention | `dead_air_regulator.sh` |
| Human-contact electrical bounding | `human_contact_regulator.sh` |
| Unauthorised screen capture interdiction | `screen_guard.sh enable` |
| Continuous policy re-enforcement (30 s cadence) | `ammo_watch.sh install` |
| Clipboard confidentiality stack deployment | `install_clipboard.sh` |
| Ingress clasp — **locked** default | `ingress_clasp.sh` |

**Consultant note:** Secure clipboard is **not** exposed as a discretionary toggle. Confidentiality of clipboard data is treated as a baseline requirement commensurate with firewall and ingress controls.

### 3.2 Discretionary exposure toggles

Stored in `~/.config/ammo-shield/prefs`. Initial factory state: **all zero (disabled)**.

| Toggle key | Menu key | Exposure granted |
|------------|----------|------------------|
| `WIFI=1` | `1` | WiFi interface activation; Ethernet suppressed |
| `ETHERNET=1` | `2` | Ethernet activation; WiFi suppressed |
| `OBS=1` | `3` | OBS PipeWire / portal whitelist configuration |
| `VPN_ONLY=1` | `4` | Egress restricted to `tun*` / `wg*` interfaces |
| `CLASP_UNLOCK=1` | `5` | Ingress clasp release — **elevated risk**; requires confirmation |

### 3.3 Derived network posture matrix

| WiFi toggle | Ethernet toggle | Computed mode |
|-------------|-----------------|---------------|
| 0 | 0 | `airgap` |
| 1 | 0 | `wifi` |
| 0 | 1 | `ethernet` |
| 1 | 1 | `both` |

Menu-driven network applications invariably include `--killswitch`, implementing VPN-style fail-closed egress at the nftables layer.

### 3.4 Antivirus policy position

ClamAV is **deliberately excluded** from the defensive stack. Each scan invocation purges ClamAV packages and services. Rootkit and integrity assessment relies upon `rkhunter` and `chkrootkit`. This represents an explicit architectural decision favouring heuristic/rootkit tooling over signature-based AV — documented here for audit traceability.

---

## 4. Repository structure

```
Security/
├── ammo.sh                      Command router and legacy normalisation layer
├── amouranth.sh, michigan.sh    Compatibility forwarders
├── ammo.ps1, amouranth.ps1, michigan.ps1
├── lib/common.sh                Shared runtime primitives
├── modules/                     Domain-specific enforcement units (see §14)
├── secure_clipboard.sh          Clipboard CLI
├── secure_clipboard.ps1
├── install_clipboard.sh         Clipboard provisioning and alias injection
├── sclipd.c                     Hardened optional daemon (Argon2, AES-GCM, seccomp)
├── AMMOSECURITY_V2_DESIGN.md    In-tree architecture memorandum
├── README.md                    Abbreviated pointer; superseded by this report
└── LICENSE                      MIT
```

---

## 5. Operational onboarding

### 5.1 Prerequisites

- Bash 4+ environment
- Elevated privilege availability (`sudo`, with credential cache recommended)
- Optional: `nftables`, `nmcli`, `flatpak` (capability-dependent features degrade gracefully)

### 5.2 Provisioning sequence

```bash
cd SG/Security
chmod +x ammo.sh amouranth.sh michigan.sh modules/*.sh install_clipboard.sh secure_clipboard.sh

sudo -v

./ammo.sh help
./ammo.sh status
./ammo.sh                  # initiates tick-box control surface (default)
```

### 5.3 Recommended operating procedure

1. Initialise control surface; verify mandatory indicators display `[x]` state.
2. Execute live validation (`t` key) prior to granting discretionary exposure.
3. Enable network toggles only upon operational necessity.
4. Enable OBS toggle solely when authorised recording is required.
5. Terminate session (`0`) to persist preferences and re-apply posture.

### 5.4 Posture presets

| Operator intent | Command |
|-----------------|---------|
| Maximum containment | `./ammo.sh lock` |
| Controlled relaxation | `./ammo.sh unlock` |
| Boot-time restoration | `./ammo.sh install-gui` then `./ammo.sh secure` via autostart |

---

## 6. Human–machine interface: tick-box control surface

**Implementation:** `modules/ammo_gui.sh`  
**Design constraint:** Pure shell; 56-column fixed-width presentation; no GUI toolkit dependencies.

### 6.1 Presentation specification

Border geometry: 54 rule characters between corners; 52-character inner text field. Rendering delegated to `ammo_box_*` primitives in `common.sh`.

```
╔══════════════════════════════════════════════════════╗
║              AMOURANTH SHIELD                        ║
║         glamorous defense, ruthless logic            ║
╚══════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════╗
║ net: airgap  vpn-only: 0                             ║
╟──────────────────────────────────────────────────────╢
║ MANDATORY  always on                                 ║
║ [x]  firewall  kernel  SMB  ClamAV purge             ║
║ [x]  screen guard  watcher  surveillance             ║
║ [x]  FCC  dead-air  human-contact  kill-switch       ║
║ [x]  secure clipboard  ingress clasp LOCKED          ║
╟──────────────────────────────────────────────────────╢
║ YOUR TOGGLES  press number to flip                   ║
║ [ ]  1  WiFi                                         ║
║ [ ]  2  Ethernet                                     ║
║ [ ]  3  OBS PipeWire (optional)                      ║
║ [ ]  4  VPN-only egress                              ║
║ [ ]  5  Ingress unlock (danger)                      ║
╟──────────────────────────────────────────────────────╢
║ a apply  t test  s status  r refresh  0 quit         ║
╚══════════════════════════════════════════════════════╝
```

### 6.2 Input mapping

| Input | Functional outcome |
|-------|-------------------|
| `1`–`5` | Toggle mutation with immediate full-stack application |
| `a` | Idempotent re-application |
| `t` | Apply, present telemetry panel, await operator acknowledgment |
| `s` | Delegate to `./ammo.sh status` |
| `r` | Mandatory module refresh |
| `0` / `q` | Persist, apply, terminate session |

Ingress unlock (`5`): de-assertion requires no confirmation; assertion demands affirmative `y` response to scripted risk prompt.

### 6.3 Application sequencing

1. Mandatory module orchestration (`gui_mandatory`)
2. Network posture derivation and enforcement (`gui_apply_network`)
3. Discretionary module activation (`gui_apply_optional`)

Failures are absorbed by `ammo_run_module`; the control surface remains operable — a deliberate resilience requirement for interactive administration.

---

## 7. Command interface specification (`ammo.sh`)

`ammo.sh` functions as the **single command router**, normalising legacy `-Action` invocations, shortcut aliases, and flag propagation (`--killswitch`, `--vpn-only`, `--dry-run`).

### 7.1 Primary invocation catalogue

```bash
./ammo.sh                  # default → gui
./ammo.sh help | status | lock | unlock | secure | install-gui

./ammo.sh net {wifi|ethernet|both|airgap|status}
./ammo.sh net dry-run {mode} [--killswitch]

./ammo.sh screen {on|off|status}
./ammo.sh obs
./ammo.sh watch {on|off|status}

./ammo.sh scan | purge-clam
./ammo.sh clasp [unlock]
./ammo.sh clip [daemon]

./ammo.sh scrub | services | surveillance | fcc | fcc-emissions
./ammo.sh deadair | human | world [N] | net-harden | all
```

### 7.2 Shortcut normalisation

| Shortcut | Resolved command |
|----------|------------------|
| `wifi` | `net wifi` |
| `eth` | `net ethernet` |
| `airgap` | `net airgap` |

### 7.3 Legacy `-Action` compatibility matrix

Maintained for backward integration with prior AmmoSecurity deployments and Windows operator habits.

| Legacy `-Action` | Normalised target |
|------------------|-------------------|
| `HardAll` | `lock` |
| `NetMode` | `net` |
| `ScreenHard` | `screen` |
| `OBSSetup` | `obs` |
| `Watch` | `watch` |
| `All` | `all` |
| `Antivirus` | `scan` |
| `Clasp` / `-Unlock` | `clasp` / `clasp unlock` |
| `Clipboard` | `clip` |
| `World` | `world` |
| *(remaining actions)* | See `map_legacy_action()` in `ammo.sh` |

---

## 8. System architecture

### 8.1 Layered defence model

```
                    ┌─────────────────────────────────┐
                    │         ammo.sh (router)        │
                    └───────────────┬─────────────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              ▼                     ▼                     ▼
       ammo_gui.sh           lib/common.sh          modules/*
       (control surface)     (shared primitives)    (enforcement)
```

### 8.2 Network enforcement stack

| Layer | Responsibility | Module |
|-------|----------------|--------|
| L1 — Physical/logical interface | `ip`, `nmcli`, `rfkill` state machine | `net_mode.sh` |
| L2 — Stateful packet filter | Dedicated nftables table | `interface_guard.sh` |
| L3 — Temporal re-enforcement | systemd user timer (30 s) | `ammo_watch.sh` |

### 8.3 nftables specification: `inet amouranth_shield`

Legacy table `inet ammosecurity` is removed upon application to prevent rule conflict.

```nft
table inet amouranth_shield {
  set allowed_ifaces {
    type ifname
    elements = { "wlan0", "lo" }    # illustrative; populated per mode
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
    type filter hook output priority filter; policy drop;   # under --killswitch
    oifname @allowed_ifaces accept
    ct state established,related accept
    counter drop comment "Amouranth Shield kill-switch"
  }
}
```

**Behavioural note:** Absent `--killswitch`, output chain policy defaults to `accept` while interface set restriction remains operative. If `nft` binary is unavailable, the module logs advisory, persists mode to state, and defers to ufw/iptables provisions from `net_harden.sh`.

Pre-deployment rule inspection:

```bash
./ammo.sh net dry-run airgap --killswitch
```

---

## 9. Shared runtime library (`lib/common.sh`)

All modules source this library. It constitutes the **contract layer** between orchestration and enforcement.

### 9.1 Configuration parameters

| Symbol | Default | Semantics |
|--------|---------|-----------|
| `AMMO_STATE` | `/var/lib/ammosecurity` | Privileged runtime state |
| `AMMO_PREFS` | `~/.config/ammo-shield/prefs` | Discretionary toggle persistence |
| `AMMO_NFT_TABLE` | `inet amouranth_shield` | nftables identifier |
| `AMMO_DRY_RUN` | `0` | Non-destructive simulation |
| `AMMO_VPN_ONLY` | `0` | VPN-scoped egress |
| `SUDO_PW` | *(empty)* | Optional non-interactive elevation — use with caution |

### 9.2 Critical primitives

| Primitive | Consultant assessment |
|-----------|----------------------|
| `ammo_sudo` | Tiered elevation: EUID 0 → `sudo -n` → optional `SUDO_PW` → interactive `sudo` |
| `ammo_state_write` | Corrected implementation; avoids prior class of credential contamination in state files |
| `ammo_state_read` | Validates `net_mode` enumeration; rejects corrupt persisted values |
| `ammo_run_module` | Fault isolation for interactive sessions |
| `ammo_log_violation` | Append-only audit trail for policy deviations |
| `ammo_prefs_net_mode` | Deterministic mode derivation from toggle state |

Fallback state directory: `~/.local/share/ammosecurity/` when privileged paths are inaccessible.

---

## 10. Network segmentation and egress control

**Primary module:** `net_mode.sh`

### 10.1 Mode behavioural specification

| Mode | Interface posture | rfkill |
|------|-------------------|--------|
| `wifi` | Wireless active; wired suppressed | WiFi permitted |
| `ethernet` | Wired active; wireless suppressed | WiFi blocked |
| `both` | Dual-homed | WiFi permitted |
| `airgap` | External interfaces administratively down | WiFi blocked |

Wireless mode invokes MAC address randomisation when NetworkManager (`nmcli`) is present — a modest unlinkability control.

### 10.2 Watch subsystem

`net_mode.sh watch`, invoked by `ammo_watch.sh` on timer expiry:

- Detects and remediates interface state divergence
- Reconstitutes missing nftables configuration
- Records violations to audit log

### 10.3 VPN-scoped egress

Activation via toggle `VPN_ONLY` or CLI `--vpn-only` restricts `allowed_ifaces` to detected `tun*` / `wg*` tunnels plus loopback — appropriate for VPN integrity requirements.

---

## 11. Visual data protection and authorised capture exception

### 11.1 Threat addressed

Unauthorised screen acquisition via desktop portal permissions, Flatpak capture grants, or legacy X11 tooling.

### 11.2 `screen_guard.sh` control measures

- Revocation of Flatpak `screen-capture` permission universe-wide, **except** `com.obsproject.Studio`
- Process interdiction against enumerated capture utilities (`scrot`, `import`, `grim`, `wf-recorder`, etc.)
- Continuous watch cycle terminating re-spawned capture processes
- `ffmpeg` pipelines matching `x11grab` (OBS-exempted) subject to interdiction

### 11.3 Authorised exception pathway: `obs_compat.sh`

Permits legitimate content creation via:

- Portal and PipeWire dependency provisioning
- Flatpak permission grant for OBS Studio
- Wayland environment configuration (`QT_QPA_PLATFORM=wayland`)

**Consultant position:** The dual-path design (deny-by-default + explicit OBS exception) balances confidentiality against operational recording requirements — provided OBS toggle remains discretionary.

---

## 12. Clipboard confidentiality subsystem

Classification: **Baseline mandatory control** — not subject to operator opt-out via menu.

| Component | Function |
|-----------|----------|
| `secure_clipboard.sh` | CLI vault operations |
| `install_clipboard.sh` | Backend provisioning; shell alias injection |
| `sclipd.c` | Optional hardened daemon |

### 12.1 Security properties

- Plaintext confined to `/dev/shm` (RAM-backed)
- Encryption: AES-256-CBC + PBKDF2 (shell); AES-256-GCM + Argon2id (daemon path)
- Temporal bounds: OS clipboard TTL (default 45 s); vault TTL (default 300 s)
- Suppression of third-party clipboard managers (CopyQ, Parcellite, clipman, et al.)
- No synchronisation to cloud or persistent history subsystems

### 12.2 Configuration locus

```
~/.config/secure-clipboard/
├── env
└── passphrase
```

### 12.3 Operational verbs

```bash
./ammo.sh clip
sclip init | copy | paste | clear | status
./ammo.sh clip daemon    # compiles and enables user-level sclipd.service
```

---

## 13. Physical and logical ingress control

**Module:** `ingress_clasp.sh`  
**Default posture:** LOCKED

### 13.1 Locked-state control catalogue

- udev rules denying authorisation of newly attached USB devices and storage
- modprobe blacklists for wireless, Bluetooth USB, mass storage, Thunderbolt drivers
- rfkill suppression across Bluetooth, WiFi, NFC, WWAN
- USB deauthorisation of non-essential devices
- Lock timestamp recorded at `/var/lib/ammo/ingress-clasp.lock`

### 13.2 Release procedure (elevated risk)

```bash
./ammo.sh clasp unlock
```

Or menu toggle `5` with affirmative confirmation. Consultant recommendation: **full system reboot** following clasp release to ensure driver stack consistency.

---

## 14. Module catalogue

| Module | Domain | Summary |
|--------|--------|---------|
| `ammo_gui.sh` | Control surface | Tick-box UI, preference I/O, autostart provisioning |
| `ammo_watch.sh` | Temporal enforcement | 30 s systemd user timer |
| `net_mode.sh` | Network | Interface mode state machine |
| `interface_guard.sh` | Network | nftables kill-switch |
| `net_harden.sh` | Host | sysctl, ufw/iptables, SMB elimination |
| `service_cleaner.sh` | Host | systemd unit masking |
| `screen_guard.sh` | Visual | Capture interdiction |
| `obs_compat.sh` | Visual | OBS exception configuration |
| `ingress_clasp.sh` | Ingress | Hardware clasp |
| `antivirus.sh` | Integrity | ClamAV purge; rkhunter/chkrootkit |
| `anti_surveillance.sh` | Input | Keylogger/HID guard |
| `fcc_guard.sh` | RF | Bluetooth/NFC block; rogue AP; SDR sweep |
| `fcc_emissions_regulator.sh` | RF/conducted | Part 15–inspired ceilings |
| `dead_air_regulator.sh` | Power | Anti-encoding rail stability |
| `human_contact_regulator.sh` | Power | 5 V / 500 mA human-contact bound |
| `scrub_location.sh` | Privacy | Metadata and profile scrub |
| `grok_world.sh` | Hygiene | 30-point desktop normalisation programme |
| `amouranth_gui.sh` | Legacy | Forwarder to `ammo_gui.sh` |

### 14.1 `service_cleaner.sh` — suppressed unit inventory

System scope: `telnet`, FTP daemons, r-services, Samba, Avahi, CUPS discovery, telemetry (`whoopsie`, `apport`), rogue AP tooling, Bluetooth, NFS/RPC, snapd, remote access (`teamviewer`, `anydesk`).

User scope: clipboard managers (`copyq`, `parcellite`, `clipit`, `greenclip`, `diodon`, `klipper`).

### 14.2 `anti_surveillance.sh` — interdicted classes

Known keylogger binaries; suspicious `xinput test`, `ydotool`, `evemu-record` patterns; udev rule `99-ammo-hid-guard.rules` blocking new USB HID hot-plug.

---

## 15. Grok World environmental hygiene programme

**Module:** `grok_world.sh`  
**Invocation:** `./ammo.sh world` | `./ammo.sh world N`

Structured as four thematic tranches — **PHI** (signal hygiene), **THERMO** (thermal/entropy), **FLOW** (network rivers), **FIELD** (substrate normalisation).

### PHI (1–8)

| # | Identifier | Objective |
|---|------------|-----------|
| 1 | `w01_phi_notifications` | Notification subsystem dampening |
| 2 | `w02_phi_compositor_calm` | Compositor animation suppression |
| 3 | `w03_phi_dpms_blank` | Display power management |
| 4 | `w04_phi_mouse_smooth` | Input acceleration stabilisation |
| 5 | `w05_phi_audio_hush` | Audio sink idle management |
| 6 | `w06_phi_browser_chatter` | Browser renderer churn reduction |
| 7 | `w07_phi_wallpaper_flat` | Static desktop background |
| 8 | `w08_phi_tray_flat` | Extension and conky suppression |

### THERMO (9–16)

| # | Identifier | Objective |
|---|------------|-----------|
| 9 | `w09_thermo_cpufreq_cool` | powersave governor |
| 10 | `w10_thermo_swap_off` | Swap deactivation |
| 11 | `w11_thermo_journal_vacuum` | Journal size constraint |
| 12 | `w12_thermo_log_scrub` | Cache and temporary log purge |
| 13 | `w13_thermo_apt_cache` | Package cache reduction |
| 14 | `w14_thermo_thumbnail_purge` | Thumbnail cache elimination |
| 15 | `w15_thermo_zram_tune` | zram sizing |
| 16 | `w16_thermo_battery_cap` | Charge threshold limitation |

### FLOW (17–23)

| # | Identifier | Objective |
|---|------------|-----------|
| 17 | `w17_flow_sync_stop` | Cloud sync termination |
| 18 | `w18_flow_torrent_kill` | P2P client interdiction |
| 19 | `w19_flow_dns_clean` | DNS cache flush |
| 20 | `w20_flow_ntp_single` | Temporal synchronisation |
| 21 | `w21_flow_ipv6_off` | IPv6 deactivation |
| 22 | `w22_flow_mail_idle` | Mail/calendar sync cessation |
| 23 | `w23_flow_cups_quiet` | Print subsystem suppression |

### FIELD (24–30)

| # | Identifier | Objective |
|---|------------|-----------|
| 24 | `w24_field_autostart_scrub` | Autostart desktop elimination |
| 25 | `w25_field_snap_trim` | Snap refresh deferral |
| 26 | `w26_field_telemetry_zero` | Telemetry unit masking |
| 27 | `w27_field_cron_audit` | Scheduled task visibility |
| 28 | `w28_field_duplicate_fm` | File manager deduplication |
| 29 | `w29_field_ssh_harden` | sshd hardening drop-in |
| 30 | `w30_field_world_status` | Programme status snapshot |

**Advisory:** Cleanup `w24` is aggressively destructive (removes all user autostart entries). Deploy only with explicit operational awareness.

---

## 16. State persistence, preference storage, and audit logging

### 16.1 Discretionary preferences

```
~/.config/ammo-shield/prefs
```

```
WIFI=0
ETHERNET=0
OBS=0
CLASP_UNLOCK=0
VPN_ONLY=0
```

Human-editable; modifications take effect on subsequent `gui_apply` or `./ammo.sh secure`.

### 16.2 Privileged runtime state

```
/var/lib/ammosecurity/
├── net_mode
├── screen_guard
├── violations.log
└── mode_changes.log
```

### 16.3 Fallback state (unprivileged)

```
~/.local/share/ammosecurity/
```

### 16.4 Ingress artefacts

```
/var/lib/ammo/ingress-clasp.lock
/etc/udev/rules.d/99-ammo-ingress-clasp.rules
/etc/modprobe.d/ammo-ingress-clasp.conf
```

### 16.5 Continuous enforcement artefacts

```
~/.config/systemd/user/amouranth-shield-watch.{service,timer}
~/.config/autostart/ammo-shield.desktop
```

---

## 17. Cross-platform artefacts (Windows / PowerShell)

Linux constitutes the **reference implementation**. Windows artefacts provide partial parity:

| Linux | Windows |
|-------|---------|
| `ammo.sh` | `ammo.ps1` |
| `secure_clipboard.sh` | `secure_clipboard.ps1` |
| `grok_world.sh` | `grok_world.ps1` |

The tick-box control surface is **not ported** to Windows. PowerShell entry points rely upon legacy `-Action` semantics.

---

## 18. Risk assessment and residual exposure

### 18.1 Threat actors (assumed)

- Local malware seeking visual or network exfiltration
- Adversaries with user-level shell access
- Supply-chain ingress via unexpected peripheral attachment
- VPN integrity failure resulting in cleartext egress

### 18.2 Control effectiveness summary

| Control | Effectiveness | Dependency |
|---------|---------------|------------|
| nftables kill-switch | High | `nft` installed; sudo |
| Portal screen revocation | High (Wayland) | xdg-desktop-portal, Flatpak |
| X11 capture interdiction | Moderate | Process watch only |
| Ingress clasp | High | sudo; reboot on release |
| Clipboard vault | High | shm; openssl |
| 30 s watcher | High | systemd user session |

### 18.3 Residual risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Kernel-level compromise | Critical | Out of scope; rkhunter provides weak signal |
| nft misconfiguration lockout | High | `unlock`; dry-run preview |
| Missing sudo | High | `sudo -v` pre-flight |
| Hardware implant | Critical | Not addressable in software |
| ClamAV absence | Low (by design) | Documented policy position |

### 18.4 Reversibility

Full posture relaxation available via `./ammo.sh unlock`, discretionary toggle de-assertion, and manual nft table deletion. System is **not designed as irreversible lockware**.

---

## 19. Incident response and diagnostic protocol

### 19.1 Symptom–remediation matrix

| Observation | Recommended action |
|-------------|-------------------|
| Elevated privilege denial | Execute `sudo -v`; verify operator in sudoers |
| Network unavailable post-lock | `./ammo.sh unlock`; assert network toggles |
| Corrupt `net_mode` persistence | Remove invalid state file; valid values: `wifi`, `ethernet`, `both`, `airgap` |
| nft table absent | Install `nftables`; inspect `interface_guard.sh` logs |
| OBS capture failure | `./ammo.sh obs`; verify PipeWire and portal services |
| Ingress over-restriction | Confirmed unlock + reboot |
| Module fault in control surface | Inspect `module failed:` log lines; isolate via individual module invocation |

### 19.2 Diagnostic command suite

```bash
./ammo.sh status
./ammo.sh net dry-run airgap --killswitch
sudo nft list table inet amouranth_shield
systemctl --user status amouranth-shield-watch.timer
cat ~/.config/ammo-shield/prefs
tail -20 ~/.local/share/ammosecurity/violations.log
```

---

## 20. Maturity roadmap

### 20.1 Current release (v2.0) — delivered

- Unified branding and command router
- Pure-shell control surface with preference persistence
- Network segmentation with kill-switch and dry-run preview
- Visual data protection with OBS exception path
- Temporal re-enforcement and violation audit
- ClamAV exclusion policy operationalised
- Mandatory clipboard confidentiality
- VPN-scoped egress; WiFi MAC randomisation
- Hardened state persistence (corrupt value rejection)

### 20.2 Target state (v2.5+)

| Initiative | Expected outcome |
|------------|------------------|
| AppArmor capture profiles | Kernel-enforced screen acquisition policy |
| Violation log analytics | Anomaly detection on audit stream |
| Hardware kill-switch integration | Physical egress interlock |
| Multi-DE validation matrix | Documented compatibility evidence |
| CI shellcheck gate | Regression prevention on shell modules |

---

## 21. Legal and licensing

Distribution is governed by the **MIT License** (Copyright © 2026 Zachary Robert Geurts). Full text resides at `SG/Security/LICENSE`.

Software is provided **without warranty**; operators assume responsibility for deployment context, regulatory compliance, and recovery procedures.

---

## Closing statement

Amouranth Shield v2.0 presents a **coherent, operator-governed desktop containment architecture** suitable for workstations requiring graduated exposure management. The system's fail-closed default, auditable violations, and reversible controls satisfy the consultancy criteria of proportionality, traceability, and informed consent.

For implementation authority, execute `./ammo.sh` from `SG/Security/`. For policy interpretation, this document remains definitive.

---

*Technical Consultancy Report — Amouranth Shield v2.0*  
*Scope: `SG/Security/` · Documentation locus: `SG/BarbieGirl/readme.md`*  
*Glamorous defense, ruthless logic.*