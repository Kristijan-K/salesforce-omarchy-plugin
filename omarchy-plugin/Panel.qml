import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.kkosu.salesforce-orgs"
  ipcTarget: "io.github.kkosu.salesforce-orgs"
  manageIpc: false

  property int selectedIndex: 0
  property bool cursorActive: false
  property bool addMode: false
  property int addTypeIndex: 0
  property string addAlias: ""
  property string addCustomUrl: ""
  property string addFocus: "type"
  property bool searchMode: false
  property string searchQuery: ""

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color fontColor: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var addTypes: [
    { key: "production", label: "Production", url: "https://login.salesforce.com" },
    { key: "sandbox", label: "Sandbox", url: "https://test.salesforce.com" },
    { key: "custom", label: "Custom URL", url: "" }
  ]
  readonly property var selectedAddType: addTypes[Math.max(0, Math.min(addTypeIndex, addTypes.length - 1))]
  readonly property string addUrl: selectedAddType.key === "custom" ? addCustomUrl : selectedAddType.url
  readonly property bool addValid: addAlias.trim() !== "" && Model.validUrl(addUrl)
  readonly property var filteredOrgs: filterOrgs()
  readonly property bool hasOrgCursor: cursorActive && !addMode && filteredOrgs.length > 0
  readonly property string statusText: service.actionStatus

  function selectedOrg() {
    if (filteredOrgs.length === 0) return null
    return filteredOrgs[Math.max(0, Math.min(selectedIndex, filteredOrgs.length - 1))]
  }

  function notify(title, message) {
    Quickshell.execDetached(["omarchy-notification-send", title, message])
  }

  function closePanel() {
    addMode = false
    searchMode = false
    root.controller.hide()
  }

  function openSelectedOrg() {
    var org = selectedOrg()
    if (!org) return
    if (!Model.statusIsConnected(org)) {
      notify("Salesforce org", "Org is not connected: " + String(org.alias || org.username || "unknown"))
      return
    }
    service.openOrg(org)
  }

  function reauthenticateSelectedOrg() {
    var org = selectedOrg()
    if (!org) return
    service.reauthenticate(org)
  }

  function filterOrgs() {
    var query = String(searchQuery || "").trim().toLowerCase()
    if (query === "") return service.orgs
    var result = []
    for (var i = 0; i < service.orgs.length; i++) {
      var org = service.orgs[i]
      var haystack = String(org.alias || "") + " " + String(org.name || "") + " " + String(org.username || "")
      if (haystack.toLowerCase().indexOf(query) !== -1) result.push(org)
    }
    return result
  }

  function statusColor(org) {
    if (Model.statusIsConnected(org)) return Color.accent
    var status = Model.statusLabel(org).toLowerCase()
    if (status.indexOf("error") !== -1 || status.indexOf("notfound") !== -1 || status.indexOf("unauthorized") !== -1)
      return Color.urgent
    return root.dim
  }

  function clampSelection() {
    selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, filteredOrgs.length - 1)))
  }

  function moveSelection(delta) {
    cursorActive = true
    if (filteredOrgs.length === 0) return
    selectedIndex = Math.max(0, Math.min(filteredOrgs.length - 1, selectedIndex + delta))
    scrollSelectedIntoView()
  }

  function scrollSelectedIntoView() {
    if (!orgRepeater || selectedIndex < 0 || selectedIndex >= filteredOrgs.length) return
    var item = orgRepeater.itemAt(selectedIndex)
    if (!item || !panelFlick) return
    Qt.callLater(function() {
      if (!item) return
      var point = item.mapToItem(panelFlick.contentItem, 0, 0)
      var top = point.y
      var bottom = top + item.height
      var viewTop = panelFlick.contentY
      var viewBottom = viewTop + panelFlick.height
      var maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height)
      if (top < viewTop + Style.space(6)) panelFlick.contentY = Math.max(0, top - Style.space(6))
      else if (bottom > viewBottom - Style.space(6)) panelFlick.contentY = Math.min(maxY, bottom + Style.space(6) - panelFlick.height)
    })
  }

  function activateSelection() {
    if (addMode) {
      if (addFocus === "type") {
        addFocus = "alias"
        Qt.callLater(function() { aliasField.forceActiveFocus() })
      } else {
        submitAdd()
      }
      return
    }
    openSelectedOrg()
  }

  function beginAdd() {
    addMode = true
    addTypeIndex = 0
    addAlias = ""
    addCustomUrl = ""
    addFocus = "type"
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function beginSearch() {
    if (addMode) return
    searchMode = true
    if (searchMode) searchQuery = ""
    selectedIndex = 0
    Qt.callLater(function() { searchField.forceActiveFocus() })
  }

  function leaveSearchInput(delta) {
    searchMode = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    if (delta !== 0) moveSelection(delta)
  }

  function closeSearch() {
    searchMode = false
    searchQuery = ""
    selectedIndex = 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function closeAdd() {
    addMode = false
    addFocus = "type"
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function changeAddType(delta) {
    addTypeIndex = Math.max(0, Math.min(addTypes.length - 1, addTypeIndex + delta))
    if (selectedAddType.key !== "custom") addCustomUrl = ""
  }

  function focusAddType() {
    addFocus = "type"
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function submitAdd() {
    if (!addValid) {
      service.actionStatus = selectedAddType.key === "custom" && !Model.validUrl(addUrl)
        ? "Enter a valid custom URL"
        : "Enter an alias"
      return
    }
    service.addOrg(addAlias, addUrl)
  }

  function open() {
    root.controller.show()
  }

  function close() {
    if (addMode) {
      closeAdd()
      return
    }
    if (searchMode) {
      closeSearch()
      return
    }
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) close()
    else open()
  }

  onOpenedChanged: if (opened) {
    cursorActive = false
    service.refresh()
    Qt.callLater(function() {
      keyCatcher.forceActiveFocus()
      root.scrollSelectedIntoView()
    })
  }
  onSearchQueryChanged: clampSelection()
  onSelectedIndexChanged: scrollSelectedIntoView()

  Service {
    id: service
    settings: root.settings
  }

  Connections {
    target: service
    function onOrgsChanged() { root.clampSelection() }
    function onActionFinished(success) {
      if (!success) root.notify("Salesforce CLI", "The Salesforce action failed")
      root.closePanel()
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        SalesforceIcon {
          anchors.centerIn: parent
          iconSize: Style.space(12)
          color: root.barForeground
          warning: service.lastError !== ""
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) service.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: Math.max(Style.space(560), popup.fittedContentWidth(Style.space(560)))
    contentHeight: Math.max(Style.space(420), popup.fittedContentHeight(column.implicitHeight, Style.space(700)))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (root.addMode) {
          if (root.addFocus === "type" && dy !== 0) root.changeAddType(dy)
          else if (dy < 0) root.focusAddType()
          return
        }
        if (!root.cursorActive) {
          root.cursorActive = true
          return
        }
        if (dy !== 0) root.moveSelection(dy)
      }
      onActivateRequested: root.activateSelection()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (root.addMode) {
          if (t === "p" || t === "P") root.addTypeIndex = 0
          else if (t === "s" || t === "S") root.addTypeIndex = 1
          else if (t === "c" || t === "C") root.addTypeIndex = 2
          else if (t === "a" || t === "A") root.submitAdd()
          return
        }
        if (t === "j" || t === "J") root.moveSelection(1)
        else if (t === "k" || t === "K") root.moveSelection(-1)
        else if (t === "o" || t === "O") root.openSelectedOrg()
        else if (t === "r" || t === "R") root.reauthenticateSelectedOrg()
        else if (t === "a" || t === "A") root.beginAdd()
        else if (t === "/") root.beginSearch()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(10)

          PanelHero {
            width: parent.width
            title: root.addMode ? "Add Salesforce org" : "Salesforce Orgs"
            meta: root.addMode ? "Choose an environment and authenticate" : (root.searchMode ? "Filtering configured orgs" : (service.orgs.length + " configured org" + (service.orgs.length === 1 ? "" : "s")))
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              SalesforceIcon {
                iconSize: Style.font.display
                color: root.foreground
              }
            }
          }

          Text {
            visible: root.statusText !== ""
            width: parent.width
            text: root.statusText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Column {
            visible: !root.addMode
            width: parent.width
            spacing: Style.space(8)

            TextField {
              id: searchField
              visible: root.searchMode
              width: parent.width
              foreground: root.foreground
              placeholderText: "Search by name or username"
              text: root.searchQuery
              onTextChanged: root.searchQuery = text
              onAccepted: root.leaveSearchInput(0)
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) { root.closeSearch(); event.accepted = true }
                else if (event.key === Qt.Key_Down) { root.leaveSearchInput(1); event.accepted = true }
                else if (event.key === Qt.Key_Up) { root.leaveSearchInput(-1); event.accepted = true }
                else if (event.text === "/") { root.beginSearch(); event.accepted = true }
              }
            }

            Text {
              visible: root.filteredOrgs.length === 0
              width: parent.width
              text: root.searchMode ? "No matching orgs." : "No Salesforce orgs found. Press a to add one."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
            }

            Text {
              visible: root.filteredOrgs.length > 0
              width: parent.width
              text: (root.selectedIndex + 1) + " of " + root.filteredOrgs.length + "  ·  Up/Down to change"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
            }

            PanelSectionHeader {
              visible: root.filteredOrgs.length > 0
              text: "ORG CONNECTIONS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              id: orgColumn
              width: parent.width
              spacing: Style.space(5)

              Repeater {
                id: orgRepeater
                model: root.filteredOrgs
                OrgRow {
                  required property var modelData
                  required property int index
                  width: orgColumn.width
                  org: modelData
                  rowIndex: index
                }
              }
            }
          }

          Column {
            visible: root.addMode
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "ENVIRONMENT"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.addTypes
              AddTypeRow {
                required property var modelData
                required property int index
                width: parent.width
                option: modelData
                rowIndex: index
              }
            }

            Text {
              width: parent.width
              text: "Alias"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            TextField {
              id: aliasField
              width: parent.width
              foreground: root.foreground
              placeholderText: "e.g. my-production"
              text: root.addAlias
              onTextChanged: root.addAlias = text
              onActiveFocusChanged: if (activeFocus) root.addFocus = "alias"
              onAccepted: {
                if (root.selectedAddType.key === "custom") customUrlField.forceActiveFocus()
                else root.submitAdd()
              }
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) { root.closeAdd(); event.accepted = true }
                else if (event.key === Qt.Key_Down) { root.focusAddType(); event.accepted = true }
              }
            }

            Text {
              visible: root.selectedAddType.key === "custom"
              width: parent.width
              text: "Instance URL"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            TextField {
              id: customUrlField
              visible: root.selectedAddType.key === "custom"
              width: parent.width
              foreground: root.foreground
              placeholderText: "https://my-domain.my.salesforce.com"
              text: root.addCustomUrl
              onTextChanged: root.addCustomUrl = text
              onActiveFocusChanged: if (activeFocus) root.addFocus = "url"
              onAccepted: root.submitAdd()
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) { root.closeAdd(); event.accepted = true }
                else if (event.key === Qt.Key_Up) { aliasField.forceActiveFocus(); event.accepted = true }
              }
            }

            CursorSurface {
              width: parent.width
              foreground: root.foreground
              hasCursor: root.addFocus === "submit"
              implicitHeight: submitText.implicitHeight + Style.spacing.rowPaddingX

              Text {
                id: submitText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Style.space(12)
                text: "Enter: add org    p/s/c: environment    Esc: cancel"
                color: root.addValid ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }

              MouseArea {
                anchors.fill: parent
                onClicked: root.submitAdd()
              }
            }
          }
        }
      }
    }
  }

  component OrgRow: CursorSurface {
    id: orgRow
    property var org: null
    property int rowIndex: 0
    readonly property bool selected: root.cursorActive && root.selectedIndex === rowIndex
    readonly property string aliasText: org ? String(org.alias || "Unknown alias") : "Unknown alias"
    readonly property string usernameText: org ? String(org.username || "Unknown username") : "Unknown username"
    readonly property string urlText: org ? String(org.loginUrl || "") : ""

    foreground: root.foreground
    hasCursor: orgRow.selected
    current: org ? Model.statusIsConnected(org) : false
    fill: root.bar ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
    currentFill: root.bar ? Style.selectedFillFor(root.foreground, Color.accent) : "transparent"
    implicitHeight: details.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        root.cursorActive = true
        root.selectedIndex = orgRow.rowIndex
      }
      onClicked: {
        root.cursorActive = true
        root.selectedIndex = orgRow.rowIndex
        root.openSelectedOrg()
      }
    }

    RowLayout {
      id: details
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        text: org && org.isSandbox ? "S" : "P"
        color: Model.statusIsConnected(org) ? Color.accent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          text: orgRow.aliasText + (org && org.isDefault ? "  *" : "")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: orgRow.selected
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: orgRow.usernameText + "  ·  " + Model.statusLabel(orgRow.org)
          color: root.statusColor(orgRow.org)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: orgRow.urlText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }

  component ActionRow: CursorSurface {
    id: actionRow
    signal chosen()
    property string label: ""
    property string hint: ""

    enabled: true
    foreground: root.foreground
    height: Style.space(48)
    implicitHeight: height

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)

      Text {
        id: actionLabel
        text: actionRow.label
        color: actionRow.enabled ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        Layout.fillWidth: true
      }

      Text {
        text: actionRow.hint
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: actionRow.enabled
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: actionRow.chosen()
    }
  }

  component AddTypeRow: CursorSurface {
    id: addTypeRow
    property var option: null
    property int rowIndex: 0
    readonly property bool selected: root.addTypeIndex === rowIndex

    foreground: root.foreground
    hasCursor: root.addMode && root.addFocus === "type" && selected
    current: selected
    fill: root.bar ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
    currentFill: root.bar ? Style.selectedFillFor(root.foreground, Color.accent) : "transparent"
    implicitHeight: label.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onEntered: {
        root.addFocus = "type"
        root.addTypeIndex = addTypeRow.rowIndex
      }
      onClicked: {
        root.addFocus = "type"
        root.addTypeIndex = addTypeRow.rowIndex
      }
    }

    Text {
      id: label
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Style.space(12)
      text: (addTypeRow.selected ? "●  " : "○  ") + String(addTypeRow.option.label || "") + "  (" + String(addTypeRow.option.url || "custom") + ")"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }
  }
}
