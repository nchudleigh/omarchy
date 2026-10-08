#!/bin/bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT
export HOME="$test_tmp/home" XDG_CONFIG_HOME="$test_tmp/config" OMARCHY_PATH="$ROOT"
export DICTATION_LOG="$test_tmp/calls" DICTATION_INSTALLED="voxtype superwhisper"
export HYPRLAND_INSTANCE_SIGNATURE=""
mkdir -p "$test_tmp/bin"
export PATH="$test_tmp/bin:$ROOT/bin:$PATH"

cat > "$test_tmp/bin/omarchy-cmd-present" <<'SH'
#!/bin/bash
[[ " $DICTATION_INSTALLED " == *" $1 "* ]]
SH
cat > "$test_tmp/bin/omarchy-cmd-missing" <<'SH'
#!/bin/bash
! omarchy-cmd-present "$1"
SH
cat > "$test_tmp/bin/omarchy-launch-floating-terminal-with-presentation" <<'SH'
#!/bin/bash
printf '%s\n' "$*" > "$DICTATION_INSTALL_LOG"
SH
cat > "$test_tmp/bin/omarchy-notification-send" <<'SH'
#!/bin/bash
printf '%s\n' "$*" > "$DICTATION_NOTIFICATION_LOG"
SH
export DICTATION_NOTIFICATION_LOG="$test_tmp/notification"
export DICTATION_INSTALL_LOG="$test_tmp/install"
for backend in voxtype superwhisper; do
  cat > "$test_tmp/bin/$backend" <<'SH'
#!/bin/bash
printf '%s %s\n' "${0##*/}" "$*" >> "$DICTATION_LOG"
exit "${DICTATION_EXIT:-0}"
SH
done
chmod +x "$test_tmp/bin/"*

[[ $(omarchy-dictation backend) == "voxtype" ]] || fail "existing Voxtype is the default when both are installed"
DICTATION_INSTALLED=superwhisper
[[ $(omarchy-dictation backend) == "superwhisper" ]] || fail "Superwhisper is selected when it is the only backend"
DICTATION_INSTALLED=""
if omarchy-dictation start 2> "$test_tmp/error"; then
  fail "no installed backend fails without starting recording"
fi
[[ ! -f $DICTATION_LOG ]] || fail "missing backend does not dispatch"
pass "backend detection preserves Voxtype and supports Superwhisper alone"

DICTATION_INSTALLED="voxtype superwhisper"
for backend in voxtype superwhisper; do
  : > "$DICTATION_LOG"
  omarchy-dictation backend "$backend"
  if [[ $backend == "superwhisper" ]]; then
    [[ $(cat "$DICTATION_LOG") == $'superwhisper shortcuts set toggle Alt+Space\nsuperwhisper shortcuts set hold none' ]] ||
      fail "selecting Superwhisper hands recording shortcuts to Omarchy"
  else
    [[ ! -s $DICTATION_LOG ]] || fail "selecting Voxtype leaves Superwhisper settings alone"
  fi
  [[ $(omarchy-dictation backend) == "$backend" ]] || fail "backend selection persists"
  : > "$DICTATION_LOG"
  omarchy dictation start
  omarchy dictation stop
  omarchy dictation toggle
  if [[ $backend == "voxtype" ]]; then
    expected=$'voxtype record start\nvoxtype record stop\nvoxtype record toggle'
  else
    expected=$'superwhisper start\nsuperwhisper stop\nsuperwhisper record'
  fi
  [[ $(cat "$DICTATION_LOG") == "$expected" ]] || fail "shared commands dispatch to $backend" "$(cat "$DICTATION_LOG")"
done
pass "shared start, stop, and toggle commands use the selected backend"

lua <<'LUA'
local root = os.getenv("ROOT")
package.path = root .. "/?.lua;" .. package.path
package.loaded["default.hypr.paths"] = { config_home = "/config" }
local selected, available, loaded = "superwhisper", true, {}
local missing = false
o = { cmd_missing = function() return missing end }
local real_open, real_popen, real_dofile = io.open, io.popen, dofile
io.popen = function(command)
  assert(command == "omarchy-dictation backend 2>/dev/null")
  return { read = function() return selected end, close = function() end }
end
io.open = function(path)
  assert(path == "/config/" .. selected .. "/shortcuts.lua")
  if available then return { close = function() end } end
end
dofile = function(path) table.insert(loaded, path) end
local function load_backend()
  package.loaded["default.hypr.dictation-backend"] = nil
  require("default.hypr.dictation-backend")
end
load_backend()
assert(loaded[1] == "/config/superwhisper/shortcuts.lua")
selected, available = "voxtype", false
load_backend()
assert(#loaded == 1, "a backend with no integration should need no config")
selected, available = "future-backend", true
load_backend()
assert(loaded[2] == "/config/future-backend/shortcuts.lua", "integration must not be limited to named providers")
missing = true
load_backend()
assert(#loaded == 2, "an uninstalled backend must not load a stale bridge")
missing = false
dofile = function() error("broken generated bridge") end
load_backend()
assert(#loaded == 2, "a broken bridge must not abort the desktop configuration")
dofile = function(path) table.insert(loaded, path) end
selected = "../../outside"
load_backend()
assert(#loaded == 2, "a backend must not escape the config directory")
selected = nil
load_backend()
assert(#loaded == 2, "no installed backend must leave configuration usable")
io.open, io.popen, dofile = real_open, real_popen, real_dofile
LUA
pass "desktop integration follows the selected backend without personal Hyprland config"

if omarchy-dictation backend invalid 2> "$test_tmp/error"; then
  fail "invalid backend is rejected"
fi
DICTATION_INSTALLED=superwhisper
omarchy-dictation backend voxtype
[[ $(cat "$DICTATION_INSTALL_LOG") == "omarchy-install-dictation-voxtype" ]] || fail "missing backend opens its installation flow"
[[ $(omarchy-dictation backend) == "superwhisper" ]] || fail "pending installation preserves the saved backend"
DICTATION_INSTALLED=voxtype
if omarchy-dictation stop 2> "$test_tmp/error"; then
  fail "missing selected backend does not silently switch"
fi
pass "invalid selections fail and missing backends install before switching"

cat > "$test_tmp/bin/hyprctl" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >> "$DICTATION_HYPR_LOG"
SH
chmod +x "$test_tmp/bin/hyprctl"
export DICTATION_HYPR_LOG="$test_tmp/hypr"
DICTATION_INSTALLED="voxtype superwhisper"
omarchy-dictation backend voxtype
if HYPRLAND_INSTANCE_SIGNATURE=test DICTATION_EXIT=7 omarchy-dictation backend superwhisper; then
  fail "a failed shortcut handoff does not select Superwhisper"
fi
[[ $(omarchy-dictation backend) == "voxtype" ]] || fail "a failed shortcut handoff preserves the backend"
pass "a failed native shortcut setup preserves the backend"

DICTATION_INSTALLED=superwhisper
omarchy-dictation backend superwhisper
result=0
DICTATION_EXIT=7 omarchy-dictation start || result=$?
(( result == 7 )) || fail "backend failures reach the caller"
printf '%s\n' invalid > "$XDG_CONFIG_HOME/omarchy/dictation-backend"
if omarchy-dictation start 2> "$test_tmp/error"; then
  fail "invalid saved backend is rejected"
fi
pass "backend errors and invalid saved settings fail clearly"

cat > "$test_tmp/bin/systemctl" <<'SH'
#!/bin/bash
exit 0
SH
cat > "$test_tmp/bin/omarchy-pkg-drop" <<'SH'
#!/bin/bash
exit 0
SH
chmod +x "$test_tmp/bin/systemctl" "$test_tmp/bin/omarchy-pkg-drop"
printf '%s\n' voxtype > "$XDG_CONFIG_HOME/omarchy/dictation-backend"
DICTATION_INSTALLED="voxtype superwhisper"
omarchy-voxtype-remove
[[ ! -e $XDG_CONFIG_HOME/omarchy/dictation-backend ]] || fail "removing Voxtype clears its saved selection"
DICTATION_INSTALLED=superwhisper
[[ $(omarchy-dictation backend) == "superwhisper" ]] || fail "removing Voxtype allows another installed backend to be detected"
pass "removing Voxtype clears a stale backend selection"
