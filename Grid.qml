import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia as Multimedia
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

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
  property bool typingFilter: false
  property bool previewOpen: false
  property string chip: "all"
  property var items: []
  property var chips: []
  property int selectedIndex: 0
  property bool cursorActive: false
  property string notice: ""
  property string currentId: ""

  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color scrim: Commons.Color.menu.scrim
  property color accent: Commons.Color.accent
  property color surface: Qt.tint(root.background, Util.alpha(root.foreground, 0.045))
  property color hoverFill: Qt.tint(root.background, Util.alpha(root.foreground, 0.10))
  property color hairline: Util.alpha(root.foreground, 0.17)
  property color secondary: Util.alpha(root.foreground, 0.72)

  readonly property int cornerRadius: Style.space(18)
  readonly property string fontFamily: Style.font.menuFamily
  readonly property int gap: Style.space(14)
  readonly property int controlHeight: Style.space(38)
  readonly property int labelHeight: Math.max(Style.space(58), Style.font.body + Style.font.caption + Style.space(18))

  readonly property int cardWidth: Math.max(0, Math.min(panel.width - Style.space(24), Style.space(1800)))
  readonly property int cardHeight: Math.max(0, Math.min(panel.height - Style.space(32), Style.space(880)))
  readonly property int columns: Math.max(1, Math.floor((grid.width + gap) / (Style.space(270) + gap)))

  component Label: Text {
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
  }

  component Action: Rectangle {
    property alias label: caption.text
    property bool active: false
    property bool compact: false
    signal clicked()

    implicitWidth: caption.implicitWidth + Style.space(24)
    height: compact ? Style.space(30) : root.controlHeight
    radius: compact ? height / 2 : Style.space(9)
    color: active ? Qt.tint(root.surface, Util.alpha(root.accent, 0.19))
                  : actionMouse.containsMouse ? root.hoverFill : root.surface
    border.width: 1
    border.color: active ? root.accent : root.hairline

    Label {
      id: caption
      anchors.centerIn: parent
      font.pixelSize: compact ? Style.font.bodySmall : Style.font.body
      font.weight: active ? Font.DemiBold : Font.Normal
    }
    MouseArea {
      id: actionMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: parent.clicked()
    }
  }

  function typeLabel(type) {
    switch (type) {
      case "scene": return "Escena"
      case "video": return "Vídeo"
      case "web": return "Web"
      default: return type === "?" ? "Fondo" : type
    }
  }

  function open(payload) {
    root.opened = true
    root.filterText = ""
    root.typingFilter = false
    root.previewOpen = false
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
    root.close()
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
      { key: "all", label: "Todos" },
      { key: "fav", label: "★ Favoritos" },
      { key: "recent", label: "Recientes" }
    ]
    var typeOrder = ["scene", "video", "web"]
    for (var t = 0; t < typeOrder.length; t++)
      if (types[typeOrder[t]]) out.push({ key: "type:" + typeOrder[t], label: root.typeLabel(typeOrder[t]) })
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
        thumb: String(row.thumb || (!row.previewIsVideo && row.preview) || ""),
        preview: String(row.preview || row.thumb || ""),
        video: String(row.video || ""),
        previewIsVideo: row.previewIsVideo === true,
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
    root.typingFilter = text.length > 0
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuild()
  }

  function setChip(key) {
    root.chip = key
    root.typingFilter = false
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuild()
  }

  function togglePreview() {
    if (model.count === 0 || root.loading) return
    root.typingFilter = false
    root.previewOpen = !root.previewOpen
  }

  function handlePreviewKey(event) {
    switch (Util.readingKey(event)) {
      case Qt.Key_Escape:
      case Qt.Key_Space:
        if (!event.isAutoRepeat) root.previewOpen = false
        break
      case Qt.Key_Left:
      case Qt.Key_Up:
        root.move(-1)
        break
      case Qt.Key_Right:
      case Qt.Key_Down:
        root.move(1)
        break
      case Qt.Key_Return:
      case Qt.Key_Enter:
        root.applyIndex(root.selectedIndex)
        break
      case Qt.Key_W:
        if (event.modifiers & Qt.MetaModifier) root.dismiss()
        break
    }
    event.accepted = true
  }

  function move(delta) {
    root.typingFilter = false
    if (model.count === 0) return
    if (!root.cursorActive) { root.cursorActive = true; root.selectedIndex = 0 }
    else root.selectedIndex = Math.max(0, Math.min(model.count - 1, root.selectedIndex + delta))
    grid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
  }

  function moveRow(delta) {
    root.typingFilter = false
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
    root.showNotice(next ? "Añadido a favoritos" : "Quitado de favoritos")
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

  Ui.OverlayWindow {
    id: panel
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

    Rectangle {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: panel.contentItem
      color: root.background
      border.width: 1
      border.color: root.hairline

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (root.previewOpen) {
            root.handlePreviewKey(event)
          } else if (event.key === Qt.Key_Space
                     && (event.modifiers === Qt.ControlModifier
                         || (event.modifiers === Qt.NoModifier && !root.typingFilter))) {
            if (!event.isAutoRepeat) root.togglePreview()
            event.accepted = true
          } else if (event.key === Qt.Key_Escape) {
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

      ColumnLayout {
        visible: !root.previewOpen
        anchors.fill: parent
        anchors.margins: Style.space(24)
        spacing: Style.space(14)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          Label {
            Layout.fillWidth: true
            text: "Wallpaper Engine"
            font.pixelSize: Style.space(26)
            font.weight: Font.DemiBold
            elide: Text.ElideRight
          }

          Action {
            label: "Aleatorio"
            onClicked: root.applyRandom()
          }
          Action {
            label: "Detener"
            onClicked: root.stopLive()
          }
          Action {
            Layout.preferredWidth: root.controlHeight
            label: "×"
            onClicked: root.dismiss()
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: root.controlHeight + Style.space(4)
          radius: Style.space(10)
          color: root.surface
          border.width: 1
          border.color: root.filterText ? root.accent : root.hairline

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(10)

            Label {
              text: "󰍉"
              color: root.secondary
            }
            Label {
              Layout.fillWidth: true
              text: root.filterText || "Escribe para buscar por título o etiqueta"
              color: root.filterText ? root.foreground : root.secondary
              elide: Text.ElideRight
            }
            Action {
              visible: root.filterText.length > 0
              compact: true
              label: "Limpiar"
              onClicked: root.setFilter("")
            }
          }
          TapHandler {
            onTapped: keyCatcher.forceActiveFocus()
          }
        }

        Flow {
          Layout.fillWidth: true
          Layout.preferredHeight: implicitHeight
          spacing: Style.space(6)

          Repeater {
            model: root.chips
            delegate: Action {
              required property var modelData
              width: implicitWidth
              compact: true
              active: root.chip === modelData.key
              label: modelData.label
              onClicked: root.setChip(modelData.key)
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          color: root.hairline
        }

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.minimumHeight: 0

          GridView {
            id: grid
            anchors.fill: parent
            model: model
            clip: true
            cellWidth: Math.max(1, Math.floor(width / root.columns))
            cellHeight: Math.round((cellWidth - root.gap) * 9 / 16) + root.labelHeight + root.gap
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: cellHeight

            ScrollBar.vertical: ScrollBar {
              width: Style.space(7)
              policy: ScrollBar.AsNeeded
            }

            delegate: Item {
              id: cell
              required property int index
              required property string wid
              required property string title
              required property string type
              required property string thumb
              required property bool fav

              readonly property bool selected: root.cursorActive && index === root.selectedIndex
              readonly property bool live: wid === root.currentId

              width: grid.cellWidth
              height: grid.cellHeight

              Rectangle {
                id: tile
                width: Math.max(1, parent.width - root.gap)
                height: parent.height - root.gap
                radius: Style.space(10)
                color: cellMouse.containsMouse || cell.selected ? root.hoverFill : root.surface

                Image {
                  id: shot
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(4)
                  height: tile.height - root.labelHeight - Style.space(4)
                  source: cell.thumb ? Util.fileUrl(cell.thumb) : ""
                  asynchronous: true
                  fillMode: Image.PreserveAspectFit
                  clip: true
                  sourceSize.width: Math.round(width)
                  sourceSize.height: Math.round(height)
                }

                Label {
                  anchors.centerIn: shot
                  visible: shot.status !== Image.Ready
                  text: shot.status === Image.Loading ? "Cargando vista previa…" : "Sin vista previa"
                  color: root.secondary
                  font.pixelSize: Style.font.caption
                }

                Column {
                  anchors.top: shot.bottom
                  anchors.bottom: parent.bottom
                  anchors.left: parent.left
                  anchors.right: favorite.left
                  anchors.margins: Style.space(10)
                  spacing: Style.space(3)

                  Label {
                    width: parent.width
                    text: cell.title
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                  }
                  Label {
                    width: parent.width
                    text: cell.live ? "● En uso · " + root.typeLabel(cell.type) : root.typeLabel(cell.type)
                    color: cell.live ? root.accent : root.secondary
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }

                Rectangle {
                  anchors.fill: parent
                  radius: tile.radius
                  color: "transparent"
                  border.width: cell.selected ? 2 : 1
                  border.color: cell.selected ? root.accent : root.hairline
                }

                MouseArea {
                  id: cellMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPositionChanged: {
                    root.cursorActive = true
                    root.selectedIndex = cell.index
                  }
                  onClicked: root.applyIndex(cell.index)
                }

                Action {
                  id: favorite
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  anchors.margins: Style.space(10)
                  width: height
                  compact: true
                  active: cell.fav
                  label: cell.fav ? "★" : "☆"
                  Accessible.name: cell.fav ? "Quitar de favoritos" : "Añadir a favoritos"
                  onClicked: root.toggleFavorite(cell.index)
                }
              }
            }
          }

          Label {
            anchors.centerIn: parent
            visible: model.count === 0
            text: root.loading ? "Cargando biblioteca…" : "No hay fondos que coincidan"
            color: root.secondary
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(16)

          Label {
            Layout.fillWidth: true
            text: root.notice || (model.count === 1 ? "1 fondo" : model.count + " fondos")
            color: root.notice ? root.accent : root.secondary
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
          Action {
            label: "Vista previa"
            compact: true
            enabled: model.count > 0 && !root.loading
            opacity: enabled ? 1 : 0.5
            onClicked: root.togglePreview()
          }
          Label {
            Layout.maximumWidth: card.width * 0.66
            text: (root.typingFilter ? "Ctrl+Espacio" : "Espacio") + "  Vista previa     ↵  Aplicar     Esc  Cerrar"
            color: root.secondary
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
        }
      }

      Loader {
        anchors.fill: parent
        anchors.margins: Style.space(24)
        active: root.opened && root.previewOpen && model.count > 0

        sourceComponent: ColumnLayout {
          id: previewPage
          property string failedVideo: ""
          property string clipPath: ""
          property string requestedScene: ""
          property bool clipFailed: false
          readonly property string sceneId: wallpaper && wallpaper.type === "scene"
                                            && !wallpaper.video && !animated && imagePath
                                            ? wallpaper.wid : ""
          readonly property string videoPath: wallpaper
                                              ? (wallpaper.video || (requestedScene === sceneId ? clipPath : ""))
                                              : ""
          readonly property bool hasVideoPreview: videoPath !== "" && videoPath !== failedVideo
          readonly property var wallpaper: model.count > root.selectedIndex
                                          ? model.get(root.selectedIndex) : null
          readonly property string imagePath: wallpaper ? (wallpaper.previewIsVideo ? wallpaper.thumb : wallpaper.preview) : ""
          readonly property url media: imagePath ? Util.fileUrl(imagePath) : ""
          readonly property bool animated: wallpaper && /\.gif$/i.test(wallpaper.preview)
          spacing: Style.space(14)

          function queueClip() {
            clipPath = ""
            clipFailed = false
            clipProcess.running = false
            clipDelay.stop()
            if (sceneId) clipDelay.start()
          }

          onSceneIdChanged: Qt.callLater(queueClip)

          Timer {
            id: clipDelay
            interval: 250
            onTriggered: {
              if (!previewPage.sceneId) return
              if (clipProcess.processId) {
                restart()
                return
              }
              previewPage.requestedScene = previewPage.sceneId
              clipProcess.command = ["bash", root.pluginDir + "/we-scene-clip", previewPage.sceneId]
              clipProcess.running = true
            }
          }

          Process {
            id: clipProcess
            stdout: StdioCollector {
              onStreamFinished: {
                if (previewPage.requestedScene === previewPage.sceneId)
                  previewPage.clipPath = text.trim()
              }
            }
            onExited: exitCode => {
              if (exitCode !== 0 && previewPage.requestedScene === previewPage.sceneId)
                previewPage.clipFailed = true
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Action {
              label: "‹ Galería"
              onClicked: root.previewOpen = false
            }

            Label {
              Layout.fillWidth: true
              text: wallpaper ? wallpaper.title : ""
              font.weight: Font.DemiBold
              font.pixelSize: Style.font.heading
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            Action {
              label: "Aplicar"
              active: true
              onClicked: root.applyIndex(root.selectedIndex)
            }
          }

          Rectangle {
            id: previewStage
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Style.space(10)
            color: root.surface
            clip: true

            Loader {
              id: previewMedia
              anchors.fill: parent
              anchors.margins: Style.space(8)
              sourceComponent: hasVideoPreview ? videoPreview : animated ? animatedPreview : staticPreview
            }

            Component {
              id: videoPreview

              Item {
                readonly property int status: player.mediaStatus === Multimedia.MediaPlayer.LoadedMedia
                                              || player.mediaStatus === Multimedia.MediaPlayer.BufferingMedia
                                              || player.mediaStatus === Multimedia.MediaPlayer.BufferedMedia
                                              ? Image.Ready : Image.Loading

                Multimedia.MediaPlayer {
                  id: player
                  source: Util.fileUrl(previewPage.videoPath)
                  loops: Multimedia.MediaPlayer.Infinite
                  autoPlay: true
                  videoOutput: output
                  onErrorOccurred: previewPage.failedVideo = previewPage.videoPath
                }

                Multimedia.VideoOutput {
                  id: output
                  anchors.fill: parent
                  fillMode: Multimedia.VideoOutput.PreserveAspectFit
                }
              }
            }

            Component {
              id: animatedPreview
              AnimatedImage {
                source: media
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                playing: root.opened && root.previewOpen
                cache: false
              }
            }

            Component {
              id: staticPreview
              Image {
                source: media
                fillMode: Image.PreserveAspectFit
                asynchronous: true
              }
            }

            Label {
              anchors.centerIn: parent
              visible: !previewMedia.item || previewMedia.item.status !== Image.Ready
              text: previewMedia.item && previewMedia.item.status === Image.Loading
                    ? "Cargando vista previa…" : "Sin vista previa"
              color: root.secondary
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Action {
              compact: true
              label: "‹ Anterior"
              enabled: root.selectedIndex > 0
              opacity: enabled ? 1 : 0.5
              onClicked: root.move(-1)
            }
            Action {
              compact: true
              label: "Siguiente ›"
              enabled: root.selectedIndex < model.count - 1
              opacity: enabled ? 1 : 0.5
              onClicked: root.move(1)
            }
            Label {
              Layout.fillWidth: true
              text: (root.selectedIndex + 1) + " / " + model.count
                    + (hasVideoPreview || animated || !imagePath ? ""
                       : sceneId && !clipFailed && !clipPath ? " · Preparando animación…"
                       : " · Vista previa estática")
              color: root.secondary
              font.pixelSize: Style.font.bodySmall
            }
            Label {
              Layout.maximumWidth: card.width * 0.5
              text: "←→  Comparar     ↵  Aplicar     Esc  Volver"
              color: root.secondary
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }
          }
        }
      }
    }
  }
}
