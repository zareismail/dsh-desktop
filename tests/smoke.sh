#!/usr/bin/env bash
# Smoke test: exercises install/doctor/uninstall in a throwaway HOME, so the
# real desktop configuration is never touched.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
export XDG_DATA_HOME="$tmp/home/.local/share"
export XDG_STATE_HOME="$tmp/home/.local/state"
mkdir -p "$HOME"

dsh="$here/bin/dsh-desktop"
apps="$XDG_DATA_HOME/applications"
pass=0 fail=0

check() { # check <label> <command...>
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); echo "ok   $label"
  else fail=$((fail + 1)); echo "FAIL $label"; fi
}

present() { [ -f "$1" ]; }
absent()  { [ ! -f "$1" ]; }
has()     { grep -qF "$2" "$1"; }
nocls()   { ! grep -q '^StartupWMClass=dsh-web-app$' "$1"; }

# --- flatpak browser: the entry id must carry the sandbox prefix ------------
"$dsh" install --browser flatpak:com.google.Chrome --no-pin >/dev/null
chrome_entry="$apps/com.google.Chrome.dsh-web-app.desktop"
check "flatpak: prefixed entry created"      present "$chrome_entry"
check "flatpak: plain entry removed"         absent  "$apps/dsh-web-app.desktop"
check "flatpak: StartupWMClass matches"      has     "$chrome_entry" "StartupWMClass=dsh-web-app"
check "flatpak: Exec points at the CLI"      has     "$chrome_entry" "dsh-desktop"
check "flatpak: icon installed"              present "$XDG_DATA_HOME/icons/hicolor/scalable/apps/deepseek-harness.svg"
check "flatpak: doctor passes"               "$dsh" doctor --browser flatpak:com.google.Chrome

# --- switching to an unconfined browser rewrites the id ---------------------
"$dsh" install --browser native:chromium --no-pin >/dev/null
check "native: plain entry created"          present "$apps/dsh-web-app.desktop"
check "native: prefixed entry removed"       absent  "$chrome_entry"
check "native: doctor passes"                "$dsh" doctor --browser native:chromium

# --- a competing entry must be reported -------------------------------------
printf '[Desktop Entry]\nType=Application\nName=Stale\nStartupWMClass=dsh-web-app\n' \
  >"$apps/zzz.dsh-web-app.desktop"
"$dsh" doctor --browser native:chromium >/dev/null 2>&1 && rc=0 || rc=$?
check "doctor rejects a competing entry"     test "$rc" -ne 0
rm -f "$apps/zzz.dsh-web-app.desktop"

# --- uninstall cleans up ----------------------------------------------------
"$dsh" uninstall >/dev/null
check "uninstall: entry removed"             absent "$apps/dsh-web-app.desktop"
check "uninstall: icon removed"              absent "$XDG_DATA_HOME/icons/hicolor/scalable/apps/deepseek-harness.svg"
check "uninstall: CLI removed"               absent "$HOME/.local/bin/dsh-desktop"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
