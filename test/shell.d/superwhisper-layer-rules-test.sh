#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command lua
require_command python3

layer_rules=$(OMARCHY_PATH="$ROOT" lua <<'LUA'
package.path = os.getenv("OMARCHY_PATH") .. "/?.lua;" .. package.path

local layer_rules = {}
hl = {
  layer_rule = function(rule)
    table.insert(layer_rules, rule)
  end,
}
-- App rules also call window helpers, which this test does not inspect.
o = setmetatable({}, { __index = function() return function() end end })

require("default.hypr.apps")

for _, rule in ipairs(layer_rules) do
  local namespace = rule.match and rule.match.namespace or ""
  print(table.concat({ namespace, tostring(rule.no_anim), tostring(rule.animation) }, "\t"))
end
LUA
)

python3 - "$layer_rules" <<'PY'
import re
import sys

rules = []
for line in sys.argv[1].splitlines():
  namespace, no_anim, animation = line.split("\t")
  if namespace:
    rules.append((re.compile(namespace), no_anim == "true", animation))

expected = {"superwhisper-edge-glow", "superwhisper-indicator"}
nearby = {
  "unrelated-layer",
  "prefix-superwhisper-edge-glow",
  "superwhisper-indicator-suffix",
}

def matching_rules(namespace):
  return [rule for rule in rules if rule[0].search(namespace)]

for namespace in expected:
  matches = matching_rules(namespace)
  assert len(matches) == 1, f"{namespace} should match exactly one loaded layer rule"
  assert matches[0][1:] == (True, "none"), f"{namespace} should have no animation"

for namespace in nearby:
  assert not matching_rules(namespace), f"{namespace} should match no loaded layer rule"

print("ok - Superwhisper layers alone receive the no-animation rule")
PY
