#!/usr/bin/env bash
# legacy name — forwards to ammo_gui.sh
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ammo_gui.sh" "$@"