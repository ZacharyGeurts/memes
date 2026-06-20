#!/usr/bin/env bash
# michigan.sh v4 — full local security stack (SG)
#   net: deny inbound, no IPv6, no Samba
#   scrub: remove Michigan footprint (local + GitHub)
#   clipboard: secured sclip (RAM vault, auto-wipe, no history managers)
#   all: everything
set -euo pipefail

VERSION=4
SG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUDO_PW="${SUDO_PW:-mememe}"
export HOME="${HOME:-/home/default}"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${HOME}/.local/bin:${PATH}"

log()  { printf '[michigan v%s] %s\n' "$VERSION" "$*"; }
run_sudo() { printf '%s\n' "$SUDO_PW" | sudo -S -p '' "$@" 2>/dev/null; }

usage() {
  cat <<EOF
michigan.sh v${VERSION} — SG security bundle

  sudo env:
    SUDO_PW=yourpw bash michigan.sh <command>

  commands:
    all          net + samba + scrub + clipboard (full stack)
    net          firewall deny-in, disable IPv6, stop Samba
    samba        stop/mask Samba only
    scrub        local Michigan scrub + GitHub profile/memes + UP IP blocks
    clipboard    install secured sclip + disable CopyQ/Parcellite
    status       show net / clipboard / scrub state
    help

  clipboard daily (after install):
    scopy 'secret'     spaste     sclear
EOF
}

# ── Samba ──────────────────────────────────────────────────────────────────
cmd_samba() {
  log 'samba: stop + disable + mask'
  run_sudo systemctl stop smbd nmbd smb winbind 2>/dev/null || true
  run_sudo systemctl disable smbd nmbd smb winbind 2>/dev/null || true
  run_sudo systemctl mask smbd nmbd 2>/dev/null || true
  if ss -tlnp 2>/dev/null | grep -qE ':139|:445'; then
    log 'WARNING: still listening on 139/445'
    ss -tlnp | grep -E ':139|:445' || true
  else
    log 'OK: 139/445 closed'
  fi
  if [[ "${PURGE_SAMBA:-}" == "1" ]] || [[ "${1:-}" == "--purge" ]]; then
    run_sudo apt-get remove --purge -y samba samba-common smbclient 2>/dev/null || true
    run_sudo apt-get autoremove -y 2>/dev/null || true
    log 'samba packages purged'
  fi
}

# ── Network ────────────────────────────────────────────────────────────────
cmd_net() {
  cmd_samba
  log 'disable IPv6 (kernel)'
  local SYSCTL=/etc/sysctl.d/99-michigan-no-ipv6.conf
  run_sudo tee "$SYSCTL" >/dev/null <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
  run_sudo sysctl --system >/dev/null 2>&1 || run_sudo sysctl -p "$SYSCTL" 2>/dev/null || true

  log 'disable IPv6 (NetworkManager)'
  if command -v nmcli >/dev/null 2>&1; then
    while read -r con; do
      [[ -n "$con" ]] || continue
      run_sudo nmcli con mod "$con" ipv6.method disabled 2>/dev/null || true
    done < <(nmcli -t -f NAME con show 2>/dev/null | sort -u)
  fi

  log 'firewall: deny in, allow out'
  if command -v ufw >/dev/null 2>&1; then
    run_sudo ufw --force reset
    run_sudo ufw default deny incoming
    run_sudo ufw default allow outgoing
    run_sudo ufw default deny routed
    run_sudo ufw --force enable
    run_sudo ufw status verbose | tail -15
  else
    log 'ufw missing — iptables drop inbound'
    run_sudo iptables -P INPUT DROP
    run_sudo iptables -P FORWARD DROP
    run_sudo iptables -P OUTPUT ACCEPT
    run_sudo iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null ||
      run_sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    run_sudo iptables -C INPUT -i lo -j ACCEPT 2>/dev/null ||
      run_sudo iptables -A INPUT -i lo -j ACCEPT
  fi

  log 'verify net'
  echo -n 'IPv6 disabled: '; sysctl net.ipv6.conf.all.disable_ipv6 2>/dev/null | awk '{print $3}'
  echo -n 'Samba active: '; systemctl is-active smbd 2>/dev/null || echo inactive
  ss -tlnp 2>/dev/null | grep -vE '127.0.0.1|::1' | grep -E ':139|:445' ||
    log 'no public 139/445 listeners'
}

# ── Scrub Michigan ─────────────────────────────────────────────────────────
cmd_scrub() {
  log 'scrub local SG files'
  umask 022
  cd "$SG" || exit 1

  local files=(
    "$SG/README.md"
    "$SG/submicro.md"
    "$SG/AMOURANTHRTX-wiki/Home.md"
    "$SG/AMOURANTHRTX-wiki/Memoriums.md"
    "$SG/AMOURANTHRTX-wiki/scripts/gen_wiki_markdown.py"
    "$SG/ammo/README.md"
    "$SG/ammo/SG_DEEP_DIVE_BUSINESS_README.md"
  )
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    perl -pi -e 's/,?\s*Gladstone Michigan//gi; s/Gladstone, Michigan, USA//gi; s/come to Michigan and //gi; s/come to Michigan//gi' "$f" 2>/dev/null || true
  done
  [[ -f "$SG/README.md" ]] && perl -pi -e 's/^- \*\*Location\*\*:.*\n//mg' "$SG/README.md" 2>/dev/null || true

  log 'local grep (expect empty)'
  grep -rin 'gladstone\|michigan\|49837\|burntwood' "$SG" \
    --include='*.md' --include='*.py' --include='*.sh' --include='*.hpp' \
    2>/dev/null | grep -v 'toupper\|Upper \(UMB\)\|expand up\|expand down' || log 'local clean'

  log 'GitHub profile → Singapore'
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    gh api -X PATCH user \
      -f location='Singapore' \
      -f bio='God (1d) is both inside and outside of every dimension. All higher dimension contains both the lower dimensions (including 1) and the highest dimension (1). ¬0 ♠' \
      && log 'profile updated'
    gh api user --jq '{login,location,bio}' 2>/dev/null || true
  else
    log 'gh not ready — run: gh auth login'
  fi

  log 'memes repo README'
  local MEMES="$SG/memes"
  if [[ -d "$MEMES/.git" ]]; then
    (
      cd "$MEMES"
      git diff --quiet README.md 2>/dev/null || {
        git add README.md
        git commit -m "Remove location metadata from README" 2>/dev/null || true
      }
      if gh auth status >/dev/null 2>&1; then
        local REMOTE_SHA CONTENT_B64
        REMOTE_SHA=$(gh api repos/ZacharyGeurts/memes/contents/README.md --jq .sha 2>/dev/null || echo "")
        if [[ -n "$REMOTE_SHA" && -f README.md ]]; then
          CONTENT_B64=$(base64 -w0 README.md)
          gh api -X PUT repos/ZacharyGeurts/memes/contents/README.md \
            -f message='Remove location metadata from README' \
            -f content="$CONTENT_B64" \
            -f sha="$REMOTE_SHA" \
            -f branch='main' 2>/dev/null && log 'memes README pushed via API'
        fi
      fi
      git push origin main 2>/dev/null && log 'memes git push ok' || log 'memes push skipped'
    )
  fi

  log 'block UP Michigan ISP ranges (best-effort)'
  if command -v ufw >/dev/null 2>&1; then
    run_sudo ufw deny from 97.95.0.0/16 comment 'michigan v4 UP ISP' 2>/dev/null || true
    run_sudo ufw deny from 66.219.0.0/16 comment 'michigan v4 UP ISP' 2>/dev/null || true
  elif command -v iptables >/dev/null 2>&1; then
    run_sudo iptables -C INPUT -s 97.95.0.0/16 -j DROP 2>/dev/null ||
      run_sudo iptables -I INPUT -s 97.95.0.0/16 -j DROP || true
    run_sudo iptables -C INPUT -s 66.219.0.0/16 -j DROP 2>/dev/null ||
      run_sudo iptables -I INPUT -s 66.219.0.0/16 -j DROP || true
  fi

  curl -fsSL 'https://raw.githubusercontent.com/ZacharyGeurts/memes/main/README.md' 2>/dev/null \
    | grep -i 'gladstone\|michigan' && log 'WARNING: still on GitHub' || log 'GitHub memes README clean'
}

# ── Secure clipboard ───────────────────────────────────────────────────────
cmd_clipboard() {
  local SCLIP="$SG/secure_clipboard.sh"
  [[ -x "$SCLIP" ]] || chmod +x "$SCLIP"

  log 'install clipboard backends'
  if command -v apt-get >/dev/null 2>&1; then
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] || [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
      run_sudo apt-get install -y openssl wl-clipboard 2>/dev/null || true
    else
      run_sudo apt-get install -y openssl xclip 2>/dev/null || true
    fi
  fi

  if [[ ! -f "${HOME}/.config/secure-clipboard/passphrase" ]]; then
    if [[ -t 0 ]]; then
      log 'init sclip vault (set passphrase when prompted)'
      bash "$SCLIP" init
    else
      log 'run interactively once: bash michigan.sh clipboard'
      bash "$SCLIP" disable-managers
    fi
  else
    bash "$SCLIP" disable-managers
    log 'sclip already initialized'
  fi

  local MARK='# >>> michigan v4 secure-clipboard'
  local MARK_END='# <<< michigan v4 secure-clipboard'
  local BLOCK="
${MARK}
alias sclip='bash ${SCLIP}'
alias scopy='sclip copy'
alias spaste='sclip paste'
alias sclear='sclip clear'
${MARK_END}
"
  for rc in "${HOME}/.bashrc" "${HOME}/.profile"; do
    [[ -f "$rc" ]] || touch "$rc"
    if ! grep -qF "$MARK" "$rc" 2>/dev/null; then
      printf '%s\n' "$BLOCK" >> "$rc"
      log "aliases → $rc"
    fi
  done
  bash "$SCLIP" status
}

# ── Status ─────────────────────────────────────────────────────────────────
cmd_status() {
  log '--- network ---'
  echo -n 'IPv6: '; sysctl net.ipv6.conf.all.disable_ipv6 2>/dev/null | awk '{print $3}' || echo '?'
  systemctl is-active smbd nmbd 2>/dev/null || echo 'smbd: inactive'
  command -v ufw >/dev/null && sudo ufw status 2>/dev/null | head -8 || true

  log '--- clipboard ---'
  if [[ -x "$SG/secure_clipboard.sh" ]]; then
    bash "$SG/secure_clipboard.sh" status 2>/dev/null || log 'sclip not initialized'
  fi

  log '--- local michigan grep ---'
  grep -rin 'gladstone\|49837\|burntwood' "$SG" --include='*.md' 2>/dev/null | head -5 ||
    log 'no obvious leaks in md'
}

# ── All ────────────────────────────────────────────────────────────────────
cmd_all() {
  cmd_net
  cmd_scrub
  cmd_clipboard
  log 'v4 complete — cable to modem, outbound only, sclip clipboard, scrub done'
  log 'reload shell: source ~/.bashrc'
}

main() {
  local cmd="${1:-help}"
  shift || true
  case "$cmd" in
    all)        cmd_all ;;
    net)        cmd_net ;;
    samba)      cmd_samba "$@" ;;
    scrub)      cmd_scrub ;;
    clipboard|clip|sclip) cmd_clipboard ;;
    status)     cmd_status ;;
    help|-h|--help) usage ;;
    *) log "unknown: $cmd"; usage; exit 1 ;;
  esac
}

main "$@"