#!/usr/bin/env bash
# amouranth.sh — alias to ammo.sh
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ammo.sh" "$@"