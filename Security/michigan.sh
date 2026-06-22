#!/usr/bin/env bash
# michigan.sh — backward-compat wrapper → Amouranth Shield
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/ammo.sh" "$@"