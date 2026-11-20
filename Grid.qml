import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Wallpaper Engine grid picker.
//
// Grid real (no carrusel horizontal): búsqueda sobre títulos y tags,
// chips de filtro, favoritos y recents. Aplicar usa `omarchy-we set`,
// así el renderer, el hook de tema y el autostart siguen igual.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  readonly property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/coronel.wallpaper-grid"
  readonly property string weBin: Quickshell.env("HOME") + "/.local/bin/omarchy-we"

  property bool opened: false
  property bool loading: false
  property string filterText: ""
  property string chip: "all"
  property var items: []
  property var chips: []
  property int selectedIndex: 0
  property bool cursorActive: false
  property string notice: ""
  property string currentId: ""

  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property int borderWidth: Math.max(1, Style.space(2))
  property color scrim: Commons.Color.menu.scrim
  property color selectedBackground: Commons.Color.menu.selectedBackground
  property color selectedText: Commons.Color.menu.selectedText
  property color accent: Commons.Color.accent
  property color muted: Commons.Color.muted
  property color hoverFill: Util.alpha(root.foreground, 0.06)
  property color rowHoverFill: Util.alpha(root.accent, 0.10)

  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int gap: Style.space(10)
  property int headerHeight: Math.max(Style.space(50), Style.font.heading + Style.spacing.controlPaddingY * 2)
  property int chipHeight: Math.max(Style.space(32), Style.font.body + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property int labelHeight: Math.round(Style.font.body * 1.7 + Style.spacing.sm * 2)
  property int footerHeight: Math.max(Style.space(28), Style.font.bodySmall + Style.spacing.sm * 2)

  property int cardWidth: Math.max(Style.space(240), Math.min(panel.width - Style.space(64), Style.space(1560)))
  property int cardHeight: Math.max(Style.space(220), Math.min(panel.height - Style.space(64), Style.space(900)))
  property int columns: Math.max(3, Math.min(7, Math.floor((gridArea.width + gap) / (Style.space(270) + gap))))

  function open(payload) {
    root.opened = true
    panel.shown = true
    root.filterText = ""
    root.chip = "all"
    root.cursorActive = true
    root.notice = ""
    root.loading = true
    root.reload()
    root.loadCurrentId()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "coronel.wallpaper-grid")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function reload() {
    if (dataProc.running) dataProc.running = false
    Qt.callLater(function() { dataProc.running = true })
  }

  // Lee el ID del wallpaper activo desde el archivo de estado de omarchy-we
  function loadCurrentId() {
    currentProc.command = ["cat", Quickshell.env("HOME") + "/.local/state/omarchy-we/current"]
    currentProc.running = true
  }

  function positionOnCurrent() {
    if (!root.currentId || model.count === 0) return
    for (var m = 0; m < model.count; m++) {
      if (model.get(m).wid === root.currentId) {
        root.selectedIndex = m
        root.cursorActive = true
        Qt.callLater(function() {
          grid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
        })
        break
      }
    }
  }

  function loadData(raw) {
    var parsed = []
    try { parsed = JSON.parse(raw) } catch (e) { parsed = [] }
    if (!Array.isArray(parsed)) parsed = []
    root.items = parsed
    root.chips = root.buildChips(parsed)
    root.loading = false
    root.rebuild()
    root.positionOnCurrent()
  }

  function buildChips(list) {
    var types = ({})
    var tagCounts = ({})
    for (var i = 0; i < list.length; i++) {
      var item = list[i]
      types[String(item.type || "?")] = true
      var tags = item.tags || []
      for (var j = 0; j < tags.length; j++) {
        var tag = String(tags[j])
        tagCounts[tag] = (tagCounts[tag] || 0) + 1
      }
    }
    var out = [
      { key: "all", label: "All" },
      { key: "fav", label: "★ Favorites" },
      { key: "recent", label: "Recent" }
    ]
    var typeOrder = ["scene", "video", "web"]
    for (var t = 0; t < typeOrder.length; t++)
      if (types[typeOrder[t]]) out.push({ key: "type:" + typeOrder[t], label: typeOrder[t] })
    var tags = Object.keys(tagCounts).filter(function(name) { return tagCounts[name] >= 2 })
    tags.sort(function(a, b) { return tagCounts[b] - tagCounts[a] })
    for (var k = 0; k < Math.min(tags.length, 8); k++)
      out.push({ key: "tag:" + tags[k], label: tags[k] })
    return out
  }

  function passesChip(item, key) {
    if (key === "all") return true
    if (key === "fav") return item.favorite === true
    if (key === "recent") return Number(item.recentRank) >= 0
    if (key.indexOf("type:") === 0) return String(item.type) === key.slice(5)
    if (key.indexOf("tag:") === 0) return (item.tags || []).indexOf(key.slice(4)) >= 0
    return true
  }

  function scoreOf(item, query) {
    var hay = (String(item.title) + " " + (item.tags || []).join(" ") + " " + String(item.type)).toLowerCase()
    var direct = hay.indexOf(query)
    if (direct >= 0) return 1000 - direct
    var tokens = query.split(/\s+/)
    var total = 0
    for (var i = 0; i < tokens.length; i++) {
      var token = tokens[i]
      if (!token) continue
      var pos = 0
      var gaps = 0
      for (var c = 0; c < token.length; c++) {
        var found = hay.indexOf(token.charAt(c), pos)
        if (found < 0) return -1
        gaps += found - pos
        pos = found + 1
      }
      total += 200 - gaps - token.length
    }
    return total
  }

  function rebuild(keepId) {
    var query = root.filterText.toLowerCase().trim()
    var rows = []
    for (var i = 0; i < root.items.length; i++) {
      var item = root.items[i]
      if (!root.passesChip(item, root.chip)) continue
      var score = query ? root.scoreOf(item, query) : 0
      if (query && score < 0) continue
      rows.push({ item: item, score: score })
    }
    rows.sort(function(a, b) {
      if (query) return b.score - a.score
      if (root.chip === "recent") return Number(a.item.recentRank) - Number(b.item.recentRank)
      if (a.item.favorite !== b.item.favorite) return a.item.favorite ? -1 : 1
      return String(a.item.title).toLowerCase() < String(b.item.title).toLowerCase() ? -1 : 1
    })

    model.clear()
    for (var k = 0; k < rows.length; k++) {
      var row = rows[k].item
      model.append({
        wid: String(row.id),
        title: String(row.title),
        type: String(row.type || "?"),
        thumb: String(row.thumb || row.preview || ""),
        fav: row.favorite === true,
        current: row.current === true
      })
    }

    if (keepId) {
      for (var m = 0; m < model.count; m++) {
        if (model.get(m).wid === keepId) { root.selectedIndex = m; break }
      }
    }
    if (model.count === 0) root.selectedIndex = 0
    else if (root.selectedIndex >= model.count) root.selectedIndex = model.count - 1
    else if (root.selectedIndex < 0) root.selectedIndex = 0
    root.cursorActive = model.count > 0
    Qt.callLater(function() {
      if (model.count > 0) grid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
    })
  }

  function setFilter(text) {
    root.filterText = text
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuild()
  }

  function setChip(key) {
    root.chip = key
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuild()
  }

  function move(delta) {
    if (model.count === 0) return
    if (!root.cursorActive) { root.cursorActive = true; root.selectedIndex = 0 }
    else root.selectedIndex = Math.max(0, Math.min(model.count - 1, root.selectedIndex + delta))
    grid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
  }

  function moveRow(delta) {
    if (model.count === 0) return
    if (!root.cursorActive) { root.cursorActive = true; root.selectedIndex = 0 }
    else root.selectedIndex = Math.max(0, Math.min(model.count - 1, root.selectedIndex + delta * root.columns))
    grid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
  }

  function movePage(delta) {
    var rows = Math.max(1, Math.floor(grid.height / grid.cellHeight))
    root.moveRow(delta * rows)
  }

  function showNotice(text) {
    root.notice = text
    noticeTimer.restart()
  }

  function applyIndex(index) {
    if (index < 0 || index >= model.count) return
    var id = String(model.get(index).wid)
    root.dismiss()
    Quickshell.execDetached([root.weBin, "set", id])
    Quickshell.execDetached(["bash", root.pluginDir + "/we-grid-data", "touch", id])
  }

  function toggleFavorite(index) {
    if (index < 0 || index >= model.count) return
    var row = model.get(index)
    var id = String(row.wid)
    var next = !row.fav
    favProc.command = ["bash", root.pluginDir + "/we-grid-data", next ? "fav" : "unfav", id]
    favProc.running = true
    for (var i = 0; i < root.items.length; i++) {
      if (String(root.items[i].id) === id) { root.items[i].favorite = next; break }
    }
    root.items = root.items.slice()
    root.rebuild(id)
    root.showNotice(next ? "Added to favorites" : "Removed from favorites")
  }

  function applyRandom() {
    if (root.items.length === 0) return
    var item = root.items[Math.floor(Math.random() * root.items.length)]
    root.dismiss()
    Quickshell.execDetached([root.weBin, "set", String(item.id)])
    Quickshell.execDetached(["bash", root.pluginDir + "/we-grid-data", "touch", String(item.id)])
  }

  function stopLive() {
    root.dismiss()
    Quickshell.execDetached([root.weBin, "stop"])
  }

  ListModel { id: model }

  Process {
    id: dataProc
    command: ["bash", root.pluginDir + "/we-grid-data", "data"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.loadData(String(text || ""))
    }
    onExited: root.loading = false
  }

  Process { id: favProc }

  Process {
    id: currentProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.currentId = String(text || "").trim()
    }
    onExited: root.positionOnCurrent()
  }

  Timer {
    id: noticeTimer
    interval: 1800
    onTriggered: root.notice = ""
  }

  OverlayWindow {
    id: panel
    width: Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1920
    height: Quickshell.screens.length > 0 ? Quickshell.screens[0].height : 1080
    shown: root.opened
    WlrLayershell.namespace: "wallpaper-engine-grid"

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: panel.contentItem
      color: root.background
      border.width: root.borderWidth
      border.color: root.border
      anchors.margins: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.dismiss()
            event.accepted = true
          } else if ((event.modifiers & Qt.MetaModifier) && event.key === Qt.Key_W) {
            root.dismiss()
            event.accepted = true
          } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
            root.toggleFavorite(root.selectedIndex)
            event.accepted = true
          } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_R) {
            root.applyRandom()
            event.accepted = true
          } else if (event.key === Qt.Key_Delete) {
            root.stopLive()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (Util.readingKey(event) === Qt.Key_Left) {
            root.move(-1)
            event.accepted = true
          } else if (Util.readingKey(event) === Qt.Key_Right) {
            root.move(1)
            event.accepted = true
          } else if (Util.readingKey(event) === Qt.Key_Up) {
            root.moveRow(-1)
            event.accepted = true
          } else if (Util.readingKey(event) === Qt.Key_Down) {
            root.moveRow(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.movePage(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.movePage(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Home) {
            root.selectedIndex = 0
            root.move(0)
            event.accepted = true
          } else if (event.key === Qt.Key_End) {
            root.selectedIndex = Math.max(0, model.count - 1)
            root.move(0)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.cursorActive) root.applyIndex(root.selectedIndex)
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32
                     && event.text.charCodeAt(0) !== 127
                     && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }
      }

      Column {
        id: contentColumn
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        // ---- header: search + actions + close ----------------------------
        Item {
          width: parent.width
          height: root.headerHeight

          Row {
            anchors.fill: parent
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(10)

            // Buscador (ocupa el espacio disponible a la izquierda)
            Rectangle {
              width: searchText.implicitWidth + Style.spacing.controlPaddingX * 2 + 40
              height: root.chipHeight
              radius: root.cornerRadius
              color: root.hoverFill
              border.width: root.filterText ? 1 : 0
              border.color: root.filterText ? root.accent : root.border

              Text {
                id: searchText
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Style.spacing.controlPaddingX
                anchors.right: parent.right
                anchors.rightMargin: 36
                text: root.filterText || "󰍉  Search title or tag…"
                color: root.filterText ? root.foreground : root.muted
                opacity: root.filterText ? 1 : 0.6
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                elide: Text.ElideRight
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Style.spacing.controlPaddingX / 2
                text: "󰍉"
                color: root.filterText ? root.accent : root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
              }
            }

            // Acciones (centro-derecha)
            Row {
              spacing: Style.space(8)

              Rectangle {
                width: stopLabel.implicitWidth + Style.spacing.controlPaddingX * 2
                height: root.chipHeight
                radius: root.cornerRadius
                color: stopArea.containsMouse ? root.selectedBackground : root.hoverFill
                border.width: 1
                border.color: root.border

                Text {
                  id: stopLabel
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: "Stop live"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
                MouseArea {
                  id: stopArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.stopLive()
                }
              }

              Rectangle {
                width: randomLabel.implicitWidth + Style.spacing.controlPaddingX * 2
                height: root.chipHeight
                radius: root.cornerRadius
                color: randomArea.containsMouse ? root.selectedBackground : root.hoverFill
                border.width: 1
                border.color: root.border

                Text {
                  id: randomLabel
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: "Random"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
                MouseArea {
                  id: randomArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.applyRandom()
                }
              }
            }

            // Cerrar (X) — siempre al extremo derecho, sin solapes
            Rectangle {
              width: root.chipHeight
              height: root.chipHeight
              radius: root.cornerRadius
              color: closeArea.containsMouse ? root.selectedBackground : root.hoverFill
              border.width: 1
              border.color: root.border

              Text {
                anchors.centerIn: parent
                text: "✕"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
              }
              MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dismiss()
              }
            }
          }
        }

        // ---- filter chips (horizontal scroll) ----------------------------
        Flow {
          width: parent.width
          height: root.chipHeight + Style.space(4)
          spacing: Style.space(6)

          Repeater {
            model: root.chips

            delegate: Rectangle {
              required property var modelData
              readonly property bool active: root.chip === modelData.key

              width: chipText.implicitWidth + Style.spacing.controlPaddingX * 2
              height: root.chipHeight
              radius: root.cornerRadius
              color: active ? root.selectedBackground : (mouseArea.containsMouse ? root.rowHoverFill : "transparent")
              border.width: active ? 2 : 1
              border.color: active ? root.accent : root.border

              Text {
                id: chipText
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: modelData.label
                color: active ? root.selectedText : root.foreground
                opacity: active ? 1 : 0.9
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }

              MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setChip(modelData.key)
              }
            }
          }
        }

        // ---- grid --------------------------------------------------------
        Item {
          id: gridArea
          width: parent.width
          height: parent.height - root.headerHeight - root.chipHeight - root.footerHeight
                  - root.contentSpacing * 4

          GridView {
            id: grid
            anchors.fill: parent
            model: model
            clip: true
            cellWidth: Math.max(1, Math.floor((width + root.gap) / root.columns) - root.gap)
            cellHeight: Math.round(cellWidth * 9 / 16) + root.labelHeight
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: cellHeight * 2
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 180

            delegate: Item {
              id: cell
              required property int index
              required property string wid
              required property string title
              required property string type
              required property string thumb
              required property bool fav
              required property bool current

              readonly property bool selected: root.cursorActive && index === root.selectedIndex
              readonly property bool hovered: mouseArea.containsMouse || root.selectedIndex === index

              width: grid.cellWidth
              height: grid.cellHeight

              // Marco de selección alrededor de la tarjeta (rectangular, más visible cuando está seleccionada)
              Rectangle {
                id: selectionFrame
                anchors.centerIn: tile
                width: tile.width + Style.space(8)
                height: tile.height + Style.space(8)
                radius: 0
                color: "transparent"
                border.width: selected ? Math.max(4, Style.space(4)) : 0
                border.color: selected ? root.accent : "transparent"
                Behavior on border.width { NumberAnimation { duration: 150 } }
                Behavior on color { NumberAnimation { duration: 150 } }
              }

              Rectangle {
                id: tile
                anchors.fill: parent
                anchors.margins: root.gap / 2
                radius: root.cornerRadius
                color: selected ? root.selectedBackground : (hovered ? root.rowHoverFill : "transparent")
                border.width: selected ? Math.max(2, Style.space(2)) : (hovered ? 1 : 0)
                border.color: selected ? root.accent : root.border
                clip: true

                Behavior on border.width { NumberAnimation { duration: 150 } }
                Behavior on color { NumberAnimation { duration: 150 } }

                Image {
                  id: shot
                  anchors.fill: parent
                  source: cell.thumb ? Util.fileUrl(cell.thumb) : ""
                  asynchronous: true
                  cache: true
                  fillMode: Image.PreserveAspectCrop
                  sourceSize.width: Math.round(tile.width)
                  sourceSize.height: Math.round(tile.height)

                  Rectangle {
                    anchors.fill: parent
                    color: root.background
                    visible: shot.status !== Image.Ready
                    opacity: 0.8
                  }

                  // Sombreado inferior con título (estilo Wallpaper Engine)
                  Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: root.labelHeight
                    color: "#000000"
                    opacity: selected || hovered ? 0.55 : 0.45
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.left: parent.left
                      anchors.leftMargin: Style.space(8)
                      anchors.right: parent.right
                      anchors.rightMargin: Style.space(8)
                      textFormat: Text.PlainText
                      text: cell.title
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      wrapMode: Text.Wrap
                      maximumLineCount: 2
                      elide: Text.ElideRight
                      Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                  }

                  // Badge tipo (esquina superior izquierda)
                  Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: Style.space(6)
                    width: typeText.implicitWidth + Style.space(10)
                    height: typeText.implicitHeight + Style.space(3)
                    radius: root.cornerRadius / 2
                    color: "#000000"
                    opacity: 0.75

                    Text {
                      id: typeText
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: cell.type
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  // Favorito (esquina superior derecha)
                  Text {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: Style.space(8)
                    textFormat: Text.PlainText
                    text: cell.fav ? "★" : "☆"
                    color: cell.fav ? root.selectedText : root.muted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                    opacity: 0.9
                  }

                  // LIVE (esquina inferior derecha, sobre la barra)
                  Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: Style.space(6)
                    visible: cell.wid === root.currentId
                    width: liveText.implicitWidth + Style.space(10)
                    height: liveText.implicitHeight + Style.space(3)
                    radius: root.cornerRadius / 2
                    color: root.accent

                    Text {
                      id: liveText
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: "LIVE"
                      color: root.background
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  // Efecto hover sobre la imagen
                  Rectangle {
                    anchors.fill: parent
                    color: selected ? root.accent : (hovered ? root.foreground : "transparent")
                    opacity: selected ? 0.10 : (hovered ? 0.04 : 0)
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                  }
                }

                MouseArea {
                  id: mouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onContainsMouseChanged: if (containsMouse) {
                    root.cursorActive = true
                    root.selectedIndex = index
                  }
                  onClicked: root.applyIndex(index)
                }
              }
            }
          }

          Column {
            anchors.centerIn: parent
            width: parent.width - 2 * root.contentMargin
            spacing: Style.space(10)
            visible: model.count === 0

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: root.loading ? "Loading…" : "󰈉"
              color: root.foreground
              opacity: 0.75
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: root.loading ? "" : "No wallpapers match"
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              elide: Text.ElideRight
              Behavior on opacity { NumberAnimation { duration: 200 } }
            }
          }
        }

        // ---- footer ------------------------------------------------------
        Item {
          width: parent.width
          height: root.footerHeight

          Row {
            anchors.fill: parent
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(16)

            Text {
              textFormat: Text.PlainText
              text: "Enter apply · Esc/X close · Ctrl+F favorite · Ctrl+R random · Del stop"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Text {
              anchors.right: parent.right
              textFormat: Text.PlainText
              text: root.notice
              color: root.selectedText
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }
    }
  }
}
