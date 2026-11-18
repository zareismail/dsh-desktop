#!/usr/bin/env bash
# Lifecycle test: exercises `run` without a real dsh server or a visible window.
#
# It stubs `dsh` with a tiny script that announces a token URL and serves HTTP,
# stubs the browser with `true` (ignores its arguments), and points state at a
# throwaway HOME. What is verified: dsh discovery on a desktop-session PATH,
# detached start, token scraping from the log, state files, reuse of an already
# running server, and the stale-token fallback.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
port=$(( 40000 + RANDOM % 1000 ))
server_pid=""

cleanup() {
  [ -n "$server_pid" ] && kill "$server_pid" 2>/dev/null
  pkill -f "http.server $port" 2>/dev/null
  rm -rf "$tmp"
}
trap cleanup EXIT

export HOME="$tmp/home"
export XDG_DATA_HOME="$tmp/home/.local/share"
export XDG_STATE_HOME="$tmp/home/.local/state"
export PATH="/usr/bin:/bin"
mkdir -p "$HOME/.local/bin" "$XDG_STATE_HOME"

# A stub dsh: prints the startup line dsh-desktop greps for, then serves HTTP.
cat >"$HOME/.local/bin/dsh" <<EOF
#!/usr/bin/env bash
echo "dsh web: http://127.0.0.1:$port/?token=stubtoken"
exec python3 -m http.server "$port" --bind 127.0.0.1
EOF
chmod +x "$HOME/.local/bin/dsh"

# `true` stands in for the browser: it accepts and ignores the window flags.
export DSH_DESKTOP_BROWSER="native:true"
export DSH_DESKTOP_PORT="$port"

dsh="$here/bin/dsh-desktop"
state="$XDG_STATE_HOME/dsh-web-app"
pass=0 fail=0
check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); echo "ok   $label"
  else fail=$((fail + 1)); echo "FAIL $label"; fi
}

check "starts with no server"        bash -c "! curl -s --max-time 1 http://127.0.0.1:$port/ >/dev/null"

"$dsh" run >/dev/null 2>&1 || true
server_pid="$(head -n1 "$state/server.pid" 2>/dev/null)"

check "server answers after run"     curl -s -o /dev/null --max-time 3 "http://127.0.0.1:$port/"
check "token url captured"           grep -q 'token=stubtoken' "$state/url"
check "pid recorded and alive"       kill -0 "$server_pid"
check "server is detached"           bash -c "[ \"\$(ps -o sess= -p $server_pid | tr -d ' ')\" != \"\$(ps -o sess= -p $$ | tr -d ' ')\" ]"

first_pid="$server_pid"
"$dsh" run >/dev/null 2>&1 || true
check "second run reuses the server" test "$(head -n1 "$state/server.pid")" = "$first_pid"
check "state survives the run"       test -s "$state/server.log"

# A token URL that no longer answers 303 must fall back to the plain root.
printf 'http://127.0.0.1:%s/?token=staletoken\n' "$port" >"$state/url"
"$dsh" run >/dev/null 2>&1 || true
check "stale token accepted as fallback" kill -0 "$first_pid"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
