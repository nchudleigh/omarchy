#!/bin/bash

# Machines already dictating with Voxtype finished first-run before Superwhisper
# became the default, so a migration installs a post-update hook that invites
# them to try it, once. Everyone else stays undisturbed.

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

hook="$ROOT/install/user/first-run/try-superwhisper.hook"
migration=$(grep -l 'try-superwhisper.hook' "$ROOT"/migrations/*.sh)
[[ $(wc -l <<<"$migration") -eq 1 ]] || fail "one migration installs the invitation" "$migration"

# Each machine is a HOME plus a PATH holding only the providers it names, so
# "not installed" cannot be answered by this machine's own Voxtype or
# Superwhisper.
machine() {
  local name=$1 tool
  shift
  mkdir -p "$test_tmp/$name/bin" "$test_tmp/$name/home"
  for tool in "$@"; do
    printf '#!/bin/bash\n' >"$test_tmp/$name/bin/$tool"
  done
  cat >"$test_tmp/$name/bin/omarchy-notification-send" <<'EOF'
#!/bin/bash
echo notification >>"$HOME/log"
while (($# > 0)); do
  if [[ $1 == "--exec" ]]; then shift; echo "exec:$*" >>"$HOME/log"; break; fi
  shift
done
EOF
  chmod +x "$test_tmp/$name/bin"/*
  for tool in mkdir cp chmod basename; do
    ln -s "$(command -v "$tool")" "$test_tmp/$name/bin/$tool"
  done
}

on() {
  local name=$1
  shift
  HOME="$test_tmp/$name/home" OMARCHY_PATH="$ROOT" PATH="$test_tmp/$name/bin:$ROOT/bin" "$@"
}

notifications() { grep -c '^notification$' "$test_tmp/$1/home/log" 2>/dev/null || true; }

machine voxtype voxtype
on voxtype "$BASH" -euo pipefail "$migration" >/dev/null
installed="$test_tmp/voxtype/home/.config/omarchy/hooks/post-update.d/try-superwhisper.hook"
[[ -x $installed ]] || fail "the migration installs the invitation as a post-update hook"
on voxtype "$BASH" "$installed"
[[ $(notifications voxtype) -eq 1 ]] || fail "a Voxtype machine is invited once"
grep -qx 'exec:omarchy-default-dictation superwhisper' "$test_tmp/voxtype/home/log" ||
  fail "the invitation opens Superwhisper's installer" "$(cat "$test_tmp/voxtype/home/log")"
on voxtype "$BASH" "$installed"
[[ $(notifications voxtype) -eq 1 ]] || fail "the invitation is not repeated on the next update"
pass "a Voxtype machine is invited to try Superwhisper once"

machine both voxtype superwhisper
on both "$BASH" "$hook"
[[ $(notifications both) -eq 0 ]] || fail "a machine with Superwhisper is not invited"
[[ ! -e $test_tmp/both/home/.local/state/omarchy/done/superwhisper-try-invitation ]] ||
  fail "a machine with Superwhisper keeps its marker unset"
pass "a machine that has Superwhisper is not invited"

machine none
on none "$BASH" "$hook"
[[ $(notifications none) -eq 0 ]] || fail "a machine without Voxtype is not invited"
[[ ! -e $test_tmp/none/home/.local/state/omarchy/done/superwhisper-try-invitation ]] ||
  fail "a machine without Voxtype keeps its marker unset"
pass "a machine without Voxtype is not invited"
