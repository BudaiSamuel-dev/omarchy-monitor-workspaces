import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Per-monitor workspace indicator. Pairs with hypr/workspaces.lua:
// the primary monitor owns workspaces 1-10, the secondary owns 11-20, and each
// bar shows only its own block, labelled 1-0.
BarWidget {
  id: root
  moduleName: "budaisamuel.workspaces"

  readonly property int offset: 10

  readonly property var monitor: {
    var window = root.QsWindow.window
    return window && window.screen ? Hyprland.monitorFor(window.screen) : null
  }

  // Keep in sync with LAPTOP_OUTPUTS in hypr/workspaces.lua.
  function isLaptop(monitor) {
    return /^(eDP|LVDS|DSI)/.test(String(monitor.name))
  }

  // Same rule as workspaces.lua: the first external monitor (by id) is primary;
  // the laptop panel is primary only when it is the sole screen.
  function primaryName() {
    var values = Hyprland.monitors.values.slice()
    values.sort(function(left, right) { return left.id - right.id })

    for (var i = 0; i < values.length; i++) {
      if (!root.isLaptop(values[i])) return values[i].name
    }

    return values.length > 0 ? values[0].name : ""
  }

  readonly property bool primary: root.monitor === null || root.monitor.name === root.primaryName()
  readonly property bool soleScreen: Hyprland.monitors.values.length <= 1
  readonly property int base: root.primary ? 0 : root.offset

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = []
    for (var slot = 1; slot <= 5; slot++) ids.push(root.base + slot)

    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      var own = id > root.base && id <= root.base + root.offset
      // Undocked, the secondary block lives here too; show what exists of it.
      var stray = root.soleScreen && id > root.offset && id <= root.offset * 2
      if ((own || stray) && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function label(id) {
    var digit = (id - 1) % root.offset + 1
    return digit === root.offset ? "0" : String(digit)
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData
        required property int index

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        // First secondary-block workspace shown on a sole (undocked) screen gets a gap.
        readonly property bool firstStray: root.base === 0 && modelData > root.offset && (index === 0 || root.workspaceIds()[index - 1] <= root.offset)

        Layout.leftMargin: firstStray && !root.vertical ? Style.space(4) : 0
        Layout.topMargin: firstStray && root.vertical ? Style.space(4) : 0

        bar: root.bar
        text: focused ? "󱓻" : root.label(modelData)
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }
  }
}
