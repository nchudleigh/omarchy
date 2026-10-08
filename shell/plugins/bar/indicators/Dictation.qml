import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

BarIndicator {
  id: root

  property bool voxtypeSelected: false
  property string state: "idle"
  property string icon: ""

  active: voxtypeSelected && state === "recording"
  keepSpace: voxtypeSelected
  activeText: icon
  inactiveText: voxtypeSelected ? "󰍬" : ""
  activeTooltipText: state
  inactiveTooltipText: "Dictate"

  function update(raw) {
    var data = extractData(raw)

    state = String(data.alt || data.class || "idle")
    if (state === "recording") icon = "󰍬"
    else if (state === "transcribing") icon = "󰔟"
    else icon = ""
  }

  FileView {
    path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/omarchy/dictation-backend"
    watchChanges: true
    printErrors: false
    onLoaded: root.voxtypeSelected = text().trim() === "voxtype"
    onFileChanged: reload()
    onLoadFailed: root.voxtypeSelected = false
  }

  Process {
    command: ["bash", "-c", "omarchy-voxtype-status"]
    running: root.voxtypeSelected
    stdout: SplitParser {
      onRead: function(data) { root.update(data) }
    }
  }

  onPressed: function() {
    if (!root.bar || !root.voxtypeSelected) return
    root.bar.run("omarchy-voxtype-config")
  }
}
