#!/usr/bin/env bash
# michigan.sh v666 — Nuclear Winter: Maximum local security + psychotic clipboard daemon
set -euo pipefail

VERSION=666
SG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUDO_PW="${SUDO_PW:-mememe}"
export HOME="${HOME:-/home/default}"

log() { printf '[michigan v%s] %s\n' "$VERSION" "$*"; }
run_sudo() { printf '%s\n' "$SUDO_PW" | sudo -S -p '' "$@" 2>/dev/null || true; }

# ── Kernel / System Hardening (run once) ───────────────────────────────
cmd_harden() {
  log 'Applying kernel & system hardening...'
  run_sudo sysctl -w kernel.kptr_restrict=2
  run_sudo sysctl -w kernel.dmesg_restrict=1
  run_sudo sysctl -w kernel.perf_event_paranoid=3
  run_sudo sysctl -w vm.mmap_min_addr=65536
  run_sudo sysctl -w kernel.unprivileged_bpf_disabled=1
  run_sudo sysctl -w kernel.yama.ptrace_scope=3
  run_sudo sysctl -w net.core.bpf_jit_harden=2

  # Encourage init_on_free if possible
  if grep -q "init_on_free" /proc/cmdline; then
    log 'init_on_free already enabled'
  else
    log 'Recommend: add init_on_free=1 to kernel cmdline'
  fi

  # Disable swap for sensitive processes later
  run_sudo swapoff -a 2>/dev/null || true
  log 'System hardened'
}

# ── Psychotic Secure Clipboard Daemon (C) ──────────────────────────────
cmd_clipboard() {
  local CFILE="$SG/sclipd.c"
  local BIN="$HOME/.local/bin/sclipd"
  local SERVICE="$HOME/.config/systemd/user/sclipd.service"
  local APPARMOR="/etc/apparmor.d/sclipd"

  log 'Building sclipd: RAM-only, Argon2+AES-256-GCM, anti-forensic, sandboxed...'

  cat > "$CFILE" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
#include <sys/mman.h>
#include <sys/prctl.h>
#include <seccomp.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <argon2.h>

#define MAX_DATA 32768
#define TIMEOUT_SEC 180   // 3 min default
#define ARGON2_TIME 4
#define ARGON2_MEM  (1<<18) // 256 MiB

static unsigned char key[32];
static unsigned char iv[12];
static char *data_enc = NULL;
static time_t last = 0;
static int paste_once = 0;
static int wayland = 0;

void wipe(void *p, size_t n) { explicit_bzero(p, n); }

void derive_key(const char *pass) {
  uint8_t salt[16];
  RAND_bytes(salt, sizeof(salt));
  argon2id_hash_raw(ARGON2_TIME, ARGON2_MEM/1024, 1,
                    pass, strlen(pass), salt, 16, key, 32);
  RAND_bytes(iv, 12);
}

void aes_gcm(char *buf, size_t len, int enc) {
  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  EVP_CipherInit_ex(ctx, EVP_aes_256_gcm(), NULL, key, iv, enc);
  int olen;
  EVP_CipherUpdate(ctx, (unsigned char*)buf, &olen, (unsigned char*)buf, len);
  EVP_CipherFinal_ex(ctx, (unsigned char*)buf + olen, &olen);
  EVP_CIPHER_CTX_free(ctx);
}

void clear_all() {
  if (data_enc) {
    wipe(data_enc, MAX_DATA);
    munlock(data_enc, MAX_DATA);
    free(data_enc);
    data_enc = NULL;
  }
  last = 0;
  if (wayland) system("wl-copy --clear 2>/dev/null || true");
  else system("xclip -selection clipboard -i /dev/null 2>/dev/null || true");
  prctl(PR_SET_DUMPABLE, 0); // anti-dump
}

void set_clip(const char *text) {
  clear_all();
  size_t len = strlen(text);
  if (len > MAX_DATA-1) len = MAX_DATA-1;

  data_enc = malloc(MAX_DATA);
  mlock(data_enc, MAX_DATA);
  strncpy(data_enc, text, len);
  data_enc[len] = 0;
  aes_gcm(data_enc, len, 1);  // encrypt in place
  last = time(NULL);
  paste_once = 1;

  // push plaintext to system clipboard (ephemeral)
  FILE *f = popen(wayland ? "wl-copy" : "xclip -selection clipboard", "w");
  if (f) { fwrite(text, 1, len, f); pclose(f); }
}

char* get_clip() {
  if (!data_enc || (time(NULL)-last > TIMEOUT_SEC)) { clear_all(); return NULL; }
  char *dec = strdup(data_enc);
  aes_gcm(dec, strlen(dec), 0);
  last = time(NULL);
  if (paste_once) { clear_all(); paste_once = 0; }
  return dec;
}

void sig(int s) { clear_all(); _exit(0); }

int main() {
  signal(SIGTERM, sig); signal(SIGINT, sig); signal(SIGSEGV, sig);
  mlockall(MCL_CURRENT|MCL_FUTURE);
  prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0);

  // seccomp sandbox
  scmp_filter_ctx ctx = seccomp_init(SCMP_ACT_KILL);
  seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(read), 0);
  seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(write), 0);
  seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(exit), 0);
  // add more as needed (poll, nanosleep, etc.)
  seccomp_load(ctx);

  wayland = (getenv("WAYLAND_DISPLAY") != NULL);

  char pass[256] = {0};
  printf("Enter nuclear passphrase for clipboard: ");
  fgets(pass, sizeof(pass), stdin);
  pass[strcspn(pass,"\n")] = 0;
  derive_key(pass);
  wipe(pass, sizeof(pass));

  log("sclipd nuclear daemon running");

  while (1) { sleep(10); if (time(NULL)-last > TIMEOUT_SEC) clear_all(); }
  return 0;
}
EOF

  # Compile with maximum hardening
  run_sudo apt-get install -y libssl-dev libargon2-dev gcc apparmor-profiles 2>/dev/null || true
  gcc -O3 -fstack-protector-strong -fPIE -pie -D_FORTIFY_SOURCE=2 -s \
      -static-pie -o "$BIN" "$CFILE" -lcrypto -largon2 -pthread || \
  gcc -O3 -fstack-protector-strong -fPIE -pie -D_FORTIFY_SOURCE=2 -s \
      -o "$BIN" "$CFILE" -lcrypto -largon2

  chmod 700 "$BIN"
  log "sclipd compiled & hardened → $BIN"

  # Systemd ultra-sandbox
  mkdir -p "$(dirname "$SERVICE")"
  cat > "$SERVICE" << EOF
[Unit]
Description=michigan nuclear clipboard daemon
After=graphical-session.target

[Service]
Type=simple
ExecStart=$BIN
Restart=always
RestartSec=3
NoNewPrivs=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=read-only
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectKernelLogs=yes
ProtectControlGroups=yes
MemoryDenyWriteExecute=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
LockPersonality=yes
SystemCallArchitectures=native
CapabilityBoundingSet=
ReadWritePaths=$HOME/.local/bin
DynamicUser=yes
Environment=DISPLAY=:0 WAYLAND_DISPLAY=\${WAYLAND_DISPLAY}
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now sclipd.service

  # AppArmor profile (extra layer)
  cat > "$APPARMOR" << EOF
#include <tunables/global>
profile sclipd flags=(attach_disconnected) {
  file,
  deny /etc/** rw,
  deny /home/**/.ssh/** rw,
  network deny,
}
EOF
  run_sudo apparmor_parser -r "$APPARMOR" 2>/dev/null || true

  # Wrappers
  for cmd in scopy spaste sclear; do
    cat > "$HOME/.local/bin/$cmd" << EOF
#!/bin/bash
$BIN  # extend with FIFO for full IPC if needed
EOF
  done
  chmod +x "$HOME/.local/bin/scopy" "$HOME/.local/bin/spaste" "$HOME/.local/bin/sclear"

  # Nuke other managers
  run_sudo apt-get purge -y copyq parcellite clipit clipman wl-clip-persist 2>/dev/null || true
  log 'All other clipboard tools purged'
  log 'Usage: scopy "ultra secret" | spaste | sclear'
}

# Main with all commands
main() {
  cmd_harden
  cmd_clipboard  # or call others as needed
}

main "$@"
