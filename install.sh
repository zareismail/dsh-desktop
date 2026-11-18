#!/usr/bin/env bash
# Convenience wrapper: ./install.sh [flags]  ==  ./bin/dsh-desktop install [flags]
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$here/bin/dsh-desktop" install "$@"
