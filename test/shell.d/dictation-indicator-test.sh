#!/bin/bash

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

run_node_test <<'JS'
const fs = require('fs')
const qml = fs.readFileSync(path.join(root, 'shell/plugins/bar/indicators/Dictation.qml'), 'utf8')
const setSelection = new Function('root', 'text', qml.match(/onLoaded: (.*)/)[1])
const indicator = { voxtypeSelected: false }
for (const [backend, visible] of [['voxtype\n', true], ['superwhisper\n', false], ['future-backend\n', false], ['', false]]) {
  setSelection(indicator, () => backend)
  assertEqual(indicator.voxtypeSelected, visible, `indicator availability follows ${backend.trim() || 'no selection'}`)
}
assert(qml.includes('active: voxtypeSelected && state === "recording"'), 'another provider cannot expose a stale Voxtype recording')
assert(qml.includes('keepSpace: voxtypeSelected') && qml.includes('inactiveText: voxtypeSelected ?'), 'unselected Voxtype has neither a hover icon nor a reserved slot')
assert(qml.includes('running: root.voxtypeSelected'), 'Voxtype status follower runs only while selected')
JS
