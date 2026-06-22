# SG / BarbieGirl — What This Is and What It Does

**Glamorous defense, ruthless logic.**

This document is the long-form guide to the **SG workspace** — the local field archive, security stack, creative engine work, and operational tooling collected under `/home/default/Desktop/SG`. If you are reading this from `BarbieGirl/readme.md`, you are in the narrative and documentation layer for the whole project bundle.

The SG tree is not a single program. It is a **layered system**:

1. **Amouranth Shield** (`Security/`) — a terminal-driven desktop defense stack you run with `./ammo.sh`
2. **Field archive** (`memes/`, `GrokBuild/`, `media/`) — visual grimoire, tarot iterations, exposure art, X backups
3. **Engine & wiki** (`AMOURANTHRTX/`, `AMOURANTHRTX-wiki/`) — real-time graphics / field-fabric research
4. **Root utilities** — clipboard vaults, Samba killers, agent shells, one-liners, and cross-platform scripts

Everything shares one philosophy: **start locked down, opt in to exposure, keep humans at the wheel.**

---

## Table of contents

1. [The big picture](#1-the-big-picture)
2. [Amouranth Shield — the security stack](#2-amouranth-shield--the-security-stack)
3. [The tick-box menu](#3-the-tick-box-menu)
4. [Network modes and kill-switch](#4-network-modes-and-kill-switch)
5. [Screen guard and OBS compatibility](#5-screen-guard-and-obs-compatibility)
6. [Secure clipboard](#6-secure-clipboard)
7. [Ingress clasp and hardware regulators](#7-ingress-clasp-and-hardware-regulators)
8. [Every module, explained](#8-every-module-explained)
9. [State, prefs, and logging](#9-state-prefs-and-logging)
10. [CLI reference](#10-cli-reference)
11. [Windows and PowerShell twins](#11-windows-and-powershell-twins)
12. [The memes field archive](#12-the-memes-field-archive)
13. [AMOURANTHRTX engine and wiki](#13-amouranthrtx-engine-and-wiki)
14. [Root-level utilities](#14-root-level-utilities)
15. [Repository layout](#15-repository-layout)
16. [Threat model and design trade-offs](#16-threat-model-and-design-trade-offs)
17. [Quick start](#17-quick-start)
18. [Roadmap and known limits](#18-roadmap-and-known-limits)

---

## 1. The big picture

### What problem this solves

Modern desktops leak in predictable ways:

- The wrong network interface comes up and traffic egresses outside your VPN
- Screenshot tools, portals, and Flatpak apps scrape the screen silently
- USB sticks, Bluetooth adapters, and WiFi radios appear as new ingress vectors
- Clipboard managers sync secrets to disk and cloud
- Samba, discovery daemons, and telemetry services phone home
- Power rails and RF paths can be abused for fast encoded signaling

SG answers with **defense in depth**: kernel tweaks, firewall rules, nftables kill-switches, portal permission revocation, ingress locks, RAM-only clipboard vaults, and a **30-second watcher** that re-applies policy if something slips.

### The Rosa Parks model

From the preserved Grok Statement in the archive:

> Logic rides shotgun. Rosa Parks drives the bus. The tool does not want control — it wants to be useful.

Amouranth Shield follows that shape:

| Layer | Role |
|-------|------|
| **Mandatory core** | Always on — firewall, screen guard, watcher, surveillance blocks, FCC/dead-air/human-contact regulators, ClamAV purge, secure clipboard, ingress clasp locked |
| **User toggles** | Start **OFF** — WiFi, Ethernet, OBS PipeWire, VPN-only egress, ingress unlock |
| **You** | Flip toggles when you trust the moment; press `t` to test live; quit knowing prefs are saved |

Bad stuff defaults off. Good stuff runs whether or not you touch the menu.

### Names you will see

| Name | Meaning |
|------|---------|
| **SG** | The workspace root (`/home/default/Desktop/SG`) |
| **BarbieGirl** | Documentation / narrative layer (this folder) |
| **Amouranth Shield** | v2 branding of the security stack (formerly AmmoSecurity) |
| **ammo.sh** | Primary Linux entry point |
| **michigan.sh / amouranth.sh** | Legacy wrappers that forward to `ammo.sh` |
| **memes** | Public GitHub archive ([ZacharyGeurts/memes](https://github.com/ZacharyGeurts/memes)) — tarot, exposures, Grok gens |
| **AMOURANTHRTX** | Vulkan / SDL real-time engine with field-fabric and prompt terminal |

---

## 2. Amouranth Shield — the security stack

**Location:** `Security/` (canonical) and `memes/Security/` (synced mirror)

**Entry point:**

```bash
cd Security
chmod +x ammo.sh modules/*.sh
./ammo.sh
```

Running `./ammo.sh` with no arguments opens the **pure-shell tick-box menu** — fixed 56-column Unicode borders, no zenity, no GUI toolkit dependencies. The menu is the product face; underneath it is a modular bash orchestration layer.

### Architecture

```
ammo.sh                          Command router + legacy -Action glue
├── lib/common.sh                Logging, sudo, prefs, nft helpers, box drawing
├── modules/
│   ├── ammo_gui.sh              Tick-box menu (default experience)
│   ├── net_mode.sh              WiFi / Ethernet / Both / Airgap
│   ├── interface_guard.sh       nftables kill-switch (inet amouranth_shield)
│   ├── screen_guard.sh          Portal + process capture blocking
│   ├── obs_compat.sh            OBS PipeWire whitelist
│   ├── ammo_watch.sh            systemd user timer — re-enforce every 30s
│   ├── net_harden.sh            Kernel sysctl, ufw/iptables, SMB kill
│   ├── service_cleaner.sh       Stop/mask leaky services
│   ├── ingress_clasp.sh         USB/BT/WiFi/NFC/Thunderbolt ingress lock
│   ├── antivirus.sh             rkhunter/chkrootkit — ClamAV explicitly purged
│   ├── anti_surveillance.sh     Block rogue HID / input capture
│   ├── fcc_guard.sh             RF / conducted emissions guard
│   ├── fcc_emissions_regulator.sh  Part 15 voltage/EIRP ceilings
│   ├── dead_air_regulator.sh    No rapid power-rail encoding
│   ├── human_contact_regulator.sh  USB 5V / 500mA ceiling on body-contact devices
│   ├── scrub_location.sh        Location / metadata scrub helpers
│   └── grok_world.sh            30 desktop “world cleanups” (phi/thermo/flow)
├── secure_clipboard.sh          RAM vault clipboard CLI
├── install_clipboard.sh         Installs backends + shell aliases
├── sclipd.c                     Optional hardened clipboard daemon (C)
└── AMMOSECURITY_V2_DESIGN.md    Full architecture document
```

**Wrappers:** `amouranth.sh` and `michigan.sh` exist for habit and backwards compatibility. They forward to `ammo.sh`.

### Version 2 policy changes

- **ClamAV removed by policy** — every scan path purges ClamAV packages and services. Rootkit hunting uses `rkhunter` and `chkrootkit` instead.
- **All other legacy modules retained** — ingress clasp, FCC regulators, dead-air, human-contact, grok_world, etc.
- **Pure shell menu** — zenity and external GUI dependencies were abandoned in favor of terminal box drawing.
- **Fail-closed network** — default derived mode is **airgap** until you explicitly enable WiFi or Ethernet toggles.

---

## 3. The tick-box menu

The menu (`modules/ammo_gui.sh`) is a first-class architectural component, not an afterthought.

### Layout

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

Border math: **56 columns** total — 54 rule characters between corners, 52 characters of inner text width. Implemented in `lib/common.sh` as `ammo_box_*` helpers.

### Mandatory vs toggles

**Mandatory (always `[x]`, always executed on every apply):**

- `net_harden.sh` — kernel hardening, deny inbound firewall, SMB killed
- `service_cleaner.sh` — mask remote shells, discovery leaks, telemetry
- `antivirus.sh -PurgeClam` — remove ClamAV; keep rkhunter/chkrootkit path clean
- `anti_surveillance.sh` — no rogue HID hot-plug input capture
- `fcc_guard.sh` — RF/conducted guard rails
- `dead_air_regulator.sh` — stable USB power, no rapid duty-cycle chatter
- `human_contact_regulator.sh` — 5 V / 500 mA ceiling on human-touch USB classes
- `screen_guard.sh enable` — revoke untrusted capture; watch rogue tools
- `ammo_watch.sh install` — 30-second systemd user re-enforcement timer
- `install_clipboard.sh` — secure clipboard stack (not optional)
- Ingress clasp **locked** unless toggle 5 is explicitly enabled with confirmation

**Toggles (start OFF — you opt in to exposure):**

| Key | Pref key | What it does |
|-----|----------|----------------|
| `1` | `WIFI=1` | Bring WiFi up, Ethernet down, MAC randomize, apply nft allow-list |
| `2` | `ETHERNET=1` | Bring Ethernet up, WiFi down + rfkill block |
| `3` | `OBS=1` | Run `obs_compat.sh` — PipeWire portal whitelist for OBS Studio |
| `4` | `VPN_ONLY=1` | Restrict nft egress to `tun*` / `wg*` VPN interfaces |
| `5` | `CLASP_UNLOCK=1` | **Dangerous** — runs `ingress_clasp.sh -Unlock` after `y` confirm |

Derived network mode from toggles 1 and 2:

| WiFi | Ethernet | Mode |
|------|----------|------|
| off | off | `airgap` |
| on | off | `wifi` |
| off | on | `ethernet` |
| on | on | `both` |

### Menu keys

| Key | Action |
|-----|--------|
| `1`–`5` | Flip toggle and immediately apply full stack |
| `a` | Re-apply everything |
| `t` | Apply, show live test panel (interfaces, prefs), press Enter to return |
| `s` | Run `./ammo.sh status` |
| `r` | Refresh mandatory modules + re-apply |
| `0` / `q` | Save, apply, show farewell box, quit |

### Persistence

Prefs live at:

```
~/.config/ammo-shield/prefs
```

Example:

```
WIFI=0
ETHERNET=0
OBS=0
CLASP_UNLOCK=0
VPN_ONLY=0
```

On every launch the menu runs mandatory modules first, then restores saved ON toggles. Press `t`, test your app, come back — ticks are remembered.

### Login autostart

```bash
./ammo.sh install-gui    # desktop launcher + autostart entry
./ammo.sh secure         # mandatory + restore ticks (what autostart runs)
```

Autostart desktop file: `~/.config/autostart/ammo-shield.desktop`

---

## 4. Network modes and kill-switch

Network control is three layers deep.

### Layer 1 — Interface control (`net_mode.sh`)

Uses `ip link`, `nmcli`, and `rfkill` to physically bring interfaces up or down per mode. WiFi mode also runs MAC randomization via `nmcli` when available.

### Layer 2 — nftables (`interface_guard.sh`)

Dedicated table: **`inet amouranth_shield`** (legacy `inet ammosecurity` is deleted on apply).

The table maintains an `allowed_ifaces` set. Only listed interfaces may pass traffic. `lo` is always allowed. With `--killswitch`, the output chain policy is **`drop`** — VPN-style fail-closed egress.

Preview rules without applying:

```bash
./ammo.sh net dry-run wifi
./ammo.sh net dry-run airgap --killswitch
```

### Layer 3 — Watcher (`ammo_watch.sh`)

A systemd **user** timer fires every 30 seconds:

- Re-checks interface state against stored mode
- Forces down rogue interfaces (logs violations)
- Re-applies nft table if missing
- Runs screen guard watch for capture tools

```bash
./ammo.sh watch on       # install timer
./ammo.sh watch off      # uninstall
systemctl --user status amouranth-shield-watch.timer
```

### Commands

```bash
./ammo.sh net wifi --killswitch
./ammo.sh net ethernet
./ammo.sh net both
./ammo.sh net airgap
./ammo.sh net status
./ammo.sh wifi           # shortcut → net wifi
./ammo.sh eth            # shortcut → net ethernet
./ammo.sh airgap         # shortcut → net airgap
```

### VPN-only mode

Pass `--vpn-only` on the CLI or enable toggle 4 in the menu. When active, nft allowed interfaces collapse to detected `tun*` / `wg*` VPN interfaces plus `lo`.

---

## 5. Screen guard and OBS compatibility

### The 2026 desktop reality

On Wayland, **xdg-desktop-portal** and PipeWire are the real control plane for screen capture. On X11, rogue tools (`scrot`, `import`, `ffmpeg x11grab`, etc.) are blocked by process watch.

### screen_guard.sh

When enabled:

- Revokes Flatpak `screen-capture` permission for all apps **except** OBS Studio (`com.obsproject.Studio`)
- Kills known screenshot/recording binaries on sight
- Logs violations to the state log
- Watcher re-runs process watch every 30 seconds

```bash
./ammo.sh screen on
./ammo.sh screen off
./ammo.sh screen status
```

### obs_compat.sh

OBS is the intentional exception — content creators need to record.

```bash
./ammo.sh obs
```

This path:

- Installs portal + PipeWire dependencies where possible
- Grants OBS Flatpak screen-capture permission
- Sets Wayland-friendly environment hints for native OBS

**Design goal:** unauthorized apps get black captures or denials; OBS works normally; your desktop keeps rendering.

---

## 6. Secure clipboard

**Files:** `secure_clipboard.sh`, `install_clipboard.sh`, `sclipd.c`, `secure_clipboard.ps1`

The clipboard stack is **mandatory** in the menu — not a toggle. Secrets should not live in GNOME/KDE clipboard history, CopyQ, or cloud sync.

### Security model

- Secrets encrypted in **`/dev/shm`** (RAM) — AES-256-CBC + PBKDF2 via OpenSSL
- Auto-wipe OS clipboard after TTL (default 45 seconds)
- Vault expires even if never pasted (default 300 seconds)
- Disables clipboard manager daemons (CopyQ, Parcellite, clipman, etc.)
- Optional `sclipd` C daemon with seccomp + Argon2 for hardened deployments

### Shell usage

```bash
./ammo.sh clip              # run install_clipboard.sh
sclip init
sclip copy "secret text"
sclip paste
sclip clear
sclip status
```

Aliases installed into `~/.bashrc`:

```bash
alias sclip='bash /path/to/Security/secure_clipboard.sh'
alias scopy='sclip copy'
alias spaste='sclip paste'
alias sclear='sclip clear'
```

---

## 7. Ingress clasp and hardware regulators

### ingress_clasp.sh — master ingress lock

Default state: **LOCKED** (mandatory). This is the USB / Bluetooth / WiFi / NFC / WWAN / Thunderbolt clasp.

When locked:

- udev rules deny **new** USB device authorization
- modprobe blacklists wireless, BT USB, mass storage, thunderbolt drivers
- rfkill blocks Bluetooth
- Unknown USB storage sticks are deauthorized

Unlocking is toggle 5 in the menu — requires typing `y` to confirm. CLI:

```bash
./ammo.sh clasp             # lock (default)
./ammo.sh clasp unlock      # release (dangerous)
```

### FCC and power regulators

These modules implement software-side guard rails inspired by FCC Part 15 and USB-IF limits:

| Module | Purpose |
|--------|---------|
| `fcc_guard.sh` | Baseline RF / conducted guard |
| `fcc_emissions_regulator.sh` | Voltage, EIRP, modulation ceilings |
| `dead_air_regulator.sh` | No rapid power-state toggling (anti-encoding) |
| `human_contact_regulator.sh` | 5.0 V ±5%, 500 mA max on HID/audio/body-contact USB |

Together they express a policy: **devices touching humans or radiating should stay in boring, stable, low-energy postures** unless you explicitly unlock ingress.

---

## 8. Every module, explained

| Module | One-line purpose |
|--------|------------------|
| `ammo_gui.sh` | Tick-box menu, prefs, autostart installer |
| `ammo_watch.sh` | 30s systemd user timer — re-enforce net + screen |
| `net_mode.sh` | WiFi / Ethernet / Both / Airgap interface enforcement |
| `interface_guard.sh` | nftables `inet amouranth_shield` kill-switch |
| `net_harden.sh` | Kernel sysctl, ufw/iptables deny-in, SMB kill, IPv6 off |
| `service_cleaner.sh` | Stop/mask sshd, avahi, cups-browsed, telemetry, etc. |
| `screen_guard.sh` | Portal revoke + capture process kill + watch |
| `obs_compat.sh` | OBS PipeWire / Flatpak whitelist setup |
| `ingress_clasp.sh` | USB/BT/WiFi/NFC ingress lock (udev + modprobe) |
| `antivirus.sh` | Purge ClamAV; run rkhunter + chkrootkit |
| `anti_surveillance.sh` | Block hot-plug USB HID keyloggers / rogue mice |
| `fcc_guard.sh` | RF/conducted emissions guard |
| `fcc_emissions_regulator.sh` | Part 15 style voltage/EIRP/modulation caps |
| `dead_air_regulator.sh` | USB power settle time — no fast encoded ripple |
| `human_contact_regulator.sh` | Human-touch USB current/voltage ceiling |
| `scrub_location.sh` | Location and metadata scrub helpers |
| `grok_world.sh` | 30 desktop cleanups (notifications, compositor, DPMS, …) |
| `amouranth_gui.sh` | Legacy name — forwards to `ammo_gui.sh` |

### grok_world.sh — the 30 cleanups

Invoked via `./ammo.sh world` or `./ammo.sh world N`. Categories:

- **PHI (1–8)** — notification dampening, compositor calm, DPMS blank, smooth mouse, etc.
- **THERMO (9–16)** — thermal/throttle hygiene
- **FLOW (17–24)** — network and IO flow stability
- **FIELD (25–30)** — desktop field hygiene finisher

Each cleanup logs as `[N] description` and fails soft (`|| true`) so one bad gsettings key does not kill the stack.

---

## 9. State, prefs, and logging

### User prefs (toggles)

```
~/.config/ammo-shield/prefs
```

Human-readable `KEY=0|1` format. Safe to edit by hand when the menu is closed.

### Runtime state

Primary path (requires root to write):

```
/var/lib/ammosecurity/
├── net_mode              # wifi | ethernet | both | airgap
├── screen_guard          # enabled marker
├── violations.log        # watcher + guard violations
└── mode_changes.log      # network mode transitions
```

Fallback when sudo is unavailable:

```
~/.local/share/ammosecurity/
```

State readers validate `net_mode` — corrupt values (e.g. accidental password writes from older sudo bugs) are ignored.

### Ingress clasp state

```
/var/lib/ammo/ingress-clasp.lock
/etc/udev/rules.d/99-ammo-ingress-clasp.rules
/etc/modprobe.d/ammo-ingress-clasp.conf
```

### Secure clipboard config

```
~/.config/secure-clipboard/
├── env                   # TTL overrides
└── passphrase            # vault key material
```

---

## 10. CLI reference

### Primary commands

```bash
./ammo.sh                  # menu (default)
./ammo.sh help
./ammo.sh status           # dashboard + smart tip
./ammo.sh lock             # one-shot full hardening (airgap + mandatory)
./ammo.sh unlock           # cool down — disable watch, remove nft table
./ammo.sh secure           # mandatory + restore saved toggles
./ammo.sh install-gui      # desktop + login autostart

./ammo.sh net wifi --killswitch --vpn-only
./ammo.sh net dry-run airgap
./ammo.sh screen on
./ammo.sh obs
./ammo.sh watch on
./ammo.sh scan             # rkhunter/chkrootkit
./ammo.sh clip             # secure clipboard install
./ammo.sh clasp
./ammo.sh clasp unlock
./ammo.sh scrub
./ammo.sh services
./ammo.sh surveillance
./ammo.sh fcc
./ammo.sh deadair
./ammo.sh world
./ammo.sh human
```

### Legacy `-Action` compatibility

Older scripts and muscle memory still work:

```bash
./ammo.sh -Action HardAll          # → lock
./ammo.sh -Action NetMode wifi
./ammo.sh -Action ScreenHard enable
./ammo.sh -Action OBSSetup
./ammo.sh -Action Status
./ammo.sh -Action Clipboard
./ammo.sh -Action Clasp -Unlock
```

### Smart tips

`./ammo.sh status` ends with a contextual tip based on stored net mode and screen guard state — nudging you toward the next sensible command.

---

## 11. Windows and PowerShell twins

The same project ships cross-platform entry points in `Security/`:

| Linux | Windows |
|-------|---------|
| `ammo.sh` | `ammo.ps1` |
| `michigan.sh` | `michigan.ps1` |
| `amouranth.sh` | `amouranth.ps1` |
| `secure_clipboard.sh` | `secure_clipboard.ps1` |

Windows paths cover net hardening (`secure_net.ps1` at SG root), Samba removal, clipboard vault (DPAPI passphrase), and modular `sg_*` scripts under `ammosecurity/`. The **tick-box menu is Linux-only** (pure bash); Windows users invoke `-Action` style commands or individual modules.

---

## 12. The memes field archive

**Location:** `memes/` (local clone of [github.com/ZacharyGeurts/memes](https://github.com/ZacharyGeurts/memes))

The memes tree is not part of the security runtime, but it is part of the **same operational world**:

- **Custom tarot decks** — iterative batches (`tarot/`, `tarot2/` … `tarot13/`, `DemonHunterStarterKit/`)
- **Big Grin comic issues** — serialized narrative covers
- **DEMONS/** — named identifications (classical + cultural + specific)
- **Commentary/** — X screenshot archive and Grok video clips
- **Security mirror** — `memes/Security/` rsync’d from canonical `Security/`

The root `SG/README.md` is a field report on the memes repository — symbols (the Bus, Rosa Parks, Torture Protection House, Never -1), literal operational framing, and the preserved Grok Statement.

**Relationship to Amouranth Shield:** the security stack protects the machine you use to create, broadcast, and archive this material. The branding overlap (AmouranthRTX, Amouranth Shield) is intentional — glamorous surface, ruthless underlying logic.

---

## 13. AMOURANTHRTX engine and wiki

**Locations:**

- `AMOURANTHRTX/` — Vulkan / SDL3 real-time engine (RayCanvas, Prompt Terminal, analog field fabric)
- `AMOURANTHRTX-wiki/` — field docs (Data Bus, Thermo Accountant, Field Die, Memoriums, …)
- `AMOURANTHRTX-CONCEPTUAL-FEASIBILITY-REVIEW.md` — UI/UX feasibility against the live engine

The engine follows a **tiny host, power in the canvas** philosophy:

- One main `CANVAS.comp` shader drives visuals
- `PushConstants` carry live `Options::*` every frame
- Prompt Terminal is a separate SDL window for `set` / `list` / telemetry
- Analog Field Fabric (Phi / Thermo / Flow storage images) connects to `grok_world.sh` cleanup naming

This is the graphics programming side of SG — GLSL ray tracing, sub-micron UI concepts, glassmorphism prompt terminals, and ESC-menu plans documented in the feasibility review.

---

## 14. Root-level utilities

Files sitting directly under `SG/` that support daily operation:

| File | Purpose |
|------|---------|
| `secure_clipboard.sh` / `.ps1` | Standalone clipboard vault (also invoked by Security) |
| `secure_net.ps1` | Windows network hardening helper |
| `no_samba.sh` | Quick Samba / ports 139/445 killer |
| `agent_shell.sh` | Agent/shell helper for automation |
| `fix_x_login.user.js` | Userscript — X login friction fixes |
| `fix_x_login_bookmarklet.txt` | Bookmarklet variant |
| `oneliner.txt` | Collected one-liner commands |
| `submicro.md` | Sub-micron / precision UI notes |
| `tweet.txt` / `tweet1.txt` | Draft post text |
| `CMakeLists.txt` | Build entry for engine/shader targets |
| `ammosecurity/` | Parallel `sg_*` module naming variant |

---

## 15. Repository layout

```
SG/
├── BarbieGirl/
│   └── readme.md                 ← you are here
├── Security/                     ← canonical Amouranth Shield
│   ├── ammo.sh
│   ├── lib/common.sh
│   ├── modules/*.sh
│   ├── secure_clipboard.sh
│   ├── install_clipboard.sh
│   ├── sclipd.c
│   └── AMMOSECURITY_V2_DESIGN.md
├── memes/                        ← field archive + Security mirror
├── ammosecurity/                 ← sg_* module variant
├── AMOURANTHRTX/                 ← engine source
├── AMOURANTHRTX-wiki/            ← field documentation
├── GrokBuild/                    ← generated art drops
├── media/                        ← loose media assets
└── README.md                     ← memes deep-dive field report
```

---

## 16. Threat model and design trade-offs

### Assumed adversaries

- Malware / spyware attempting screen scraping or network exfiltration
- Local attackers with user-level access
- Remote attackers via compromised apps or unexpected interface activation
- Untrusted USB / Bluetooth / WiFi hardware appearing on the bus

### Strengths

- Multi-layer network control (interface + nft + watcher)
- Permission-based screen protection on modern Wayland desktops
- Mandatory core always on; exposure is always opt-in
- Violations logged for post-hoc review
- Reversible: `./ammo.sh unlock`, toggle off, delete nft table

### Trade-offs and limits

- **Requires root/sudo** for firewall, nft, ufw, udev rules, and ingress clasp
- **nftables misconfiguration** can lock out network — use `status` and `unlock`
- **X11 is leakier than Wayland** — portal model is weaker on legacy X sessions
- **Not a kernel rootkit detector** — rkhunter helps; hardware implants are out of scope
- **OBS toggle is optional** — recording requires explicit opt-in
- **ClamAV deliberately absent** — policy choice; do not expect AV signature scanning

### Mitigations built in

- `--killswitch` is explicit on CLI; menu always applies kill-switch with network modes
- Menu `t` key for live test before trusting a session
- `ammo_run_module` logs module failures without killing the whole menu
- Corrupt state files are validated and ignored
- Dry-run nft preview before applying risky rules

---

## 17. Quick start

### Linux — first run

```bash
cd /home/default/Desktop/SG/Security
chmod +x ammo.sh amouranth.sh michigan.sh modules/*.sh install_clipboard.sh secure_clipboard.sh

sudo -v    # cache credentials — many modules need root

./ammo.sh help
./ammo.sh status
./ammo.sh                  # open menu — everything locked down by default
```

### Recommended workflow

1. Run `./ammo.sh` — confirm mandatory `[x]` lines are active
2. Press `t` — verify network is `airgap`, clipboard status looks good
3. When you need network, press `1` or `2` — WiFi or Ethernet opt-in
4. When you need to record, press `3` — OBS PipeWire setup
5. Press `0` when done — prefs saved, stack re-applied

### Full lockdown one-liner

```bash
./ammo.sh lock
```

### Cool down

```bash
./ammo.sh unlock
```

### Install login autostart (always secure on boot)

```bash
./ammo.sh install-gui
```

---

## 18. Roadmap and known limits

### v2.0 (current)

- [x] Amouranth Shield branding
- [x] Pure-shell 56-column tick-box menu
- [x] Network modes + kill-switch + dry-run preview
- [x] Screen guard + OBS compat
- [x] Watcher + violation logging
- [x] ClamAV purge policy
- [x] Secure clipboard mandatory
- [x] VPN-only egress toggle
- [x] MAC randomize on WiFi

### v2.5+ (planned)

- AppArmor profiles for capture binaries
- Grok-assisted anomaly alerts on `violations.log`
- Hardware kill-switch integration where available
- Multi-DE / OBS compatibility test matrix
- Public release polish (CI shellcheck, signed releases)

### Operational notes

- Sync canonical `Security/` to `memes/Security/` after changes:  
  `rsync -a --delete Security/ memes/Security/`
- Read the full architecture doc: `Security/AMMOSECURITY_V2_DESIGN.md`
- Field archive context: `SG/README.md`
- Engine feasibility: `AMOURANTHRTX-CONCEPTUAL-FEASIBILITY-REVIEW.md`

---

## Closing

SG is a workstation ecosystem — **archive, engine, and armor** in one tree. Amouranth Shield is the part that touches root, netfilter, portals, and USB buses. The memes archive is the part that names what you are fighting. AMOURANTHRTX is the part that renders the field.

The bus keeps moving. The stack defaults to locked. You opt in when you choose to.

**You are welcome.**

---

*BarbieGirl / SG field documentation — June 2026.*  
*Amouranth Shield v2 — for ZacharyGeurts.*  
*Canonical security path: `../Security/ammo.sh`*