#!/usr/bin/env bash
# Convenience wrapper: ./uninstall.sh  ==  ./bin/dsh-desktop uninstall
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$here/bin/dsh-desktop" uninstall "$@"
