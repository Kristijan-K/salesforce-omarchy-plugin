import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root

  property var service: null
  property var shell: null
  property var manifest: null
  property bool addMode: false
  property int addTypeIndex: 0
  property string addAlias: ""
  property string addCustomUrl: ""
  property string addUrl: "https://login.salesforce.com"
  property bool searchMode: false
  property string searchQuery: ""
  property int selectedIndex: 0
  property bool deleteConfirmation: false
  property var deleteOrg: null
  readonly property string pluginId: manifest && manifest.id ? manifest.id : "io.github.kkosu.salesforce-orgs"
  readonly property var liveService: service || (bar && bar.shell ? bar.shell.serviceFor(pluginId) : null)
  readonly property var addTypes: ["Production", "Sandbox", "Custom URL"]

  function filteredOrgs() {
    var query = searchQuery.trim().toLowerCase()
    if (query === "") return liveService ? liveService.orgs : []
    var result = []
    var source = liveService ? liveService.orgs : []
    for (var i = 0; i < source.length; i++) {
      var org = source[i]
      var haystack = String(org.alias || "") + " " + String(org.name || "") + " " + String(org.username || "")
      if (haystack.toLowerCase().indexOf(query) !== -1) result.push(org)
    }
    return result
  }

  // The bar host sizes the widget from the root item's implicit dimensions.
  // The button is anchored to this root, so forward its slot size explicitly.
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
          anchors.verticalCenterOffset: Style.space(-1)
          iconSize: Style.space(11)
          color: root.barForeground
          warning: root.liveService ? root.liveService.lastError !== "" : false
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) {
        if (root.liveService) root.liveService.refresh()
      } else if (root.bar && root.bar.shell) {
        root.toggle()
      }
    }
  }

  onOpenedChanged: if (opened) {
    refreshIfEmpty()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function selectedOrg() {
    var orgs = filteredOrgs()
    if (orgs.length === 0) return null
    return orgs[Math.max(0, Math.min(selectedIndex, orgs.length - 1))]
  }

  function moveSelection(delta) {
    var orgs = filteredOrgs()
    if (orgs.length === 0) return
    selectedIndex = Math.max(0, Math.min(orgs.length - 1, selectedIndex + delta))
    Qt.callLater(function() {
      orgList.positionViewAtIndex(selectedIndex, ListView.Contain)
    })
  }

  function openSelected() {
    var org = selectedOrg()
    if (!org || !liveService) return
    if (!Model.statusIsConnected(org)) {
      liveService.actionStatus = "Org is not connected: " + String(org.alias || org.username)
      return
    }
    liveService.openOrg(org)
  }

  function reauthenticateSelected() {
    var org = selectedOrg()
    if (org && liveService) liveService.reauthenticate(org)
  }

  function beginDelete(org) {
    if (!org) return
    deleteOrg = org
    deleteConfirmation = true
  }

  function beginAdd() {
    addMode = true
    addTypeIndex = 0
    addAlias = ""
    addCustomUrl = ""
    addUrl = "https://login.salesforce.com"
    Qt.callLater(function() { aliasField.forceActiveFocus() })
  }

  function beginSearch() {
    if (addMode) return
    searchMode = true
    searchQuery = ""
    selectedIndex = 0
    Qt.callLater(function() { searchField.forceActiveFocus() })
  }

  function closeSearch() {
    searchMode = false
    searchQuery = ""
    selectedIndex = 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function commitSearch() {
    var orgs = filteredOrgs()
    selectedIndex = Math.max(0, Math.min(selectedIndex, orgs.length - 1))
    Qt.callLater(function() {
      keyCatcher.forceActiveFocus()
      orgList.positionViewAtIndex(selectedIndex, ListView.Contain)
    })
  }

  function refreshIfEmpty() {
    if (liveService && liveService.cacheLoaded && liveService.orgs.length === 0 && liveService.lastRefreshAt === "")
      liveService.refresh()
  }

  function confirmDelete() {
    if (liveService) liveService.removeOrg(deleteOrg)
    deleteConfirmation = false
    deleteOrg = null
  }

  function cancelDelete() {
    deleteConfirmation = false
    deleteOrg = null
  }

  Connections {
    target: liveService
    function onOrgsChanged() {
      var orgs = root.filteredOrgs()
      selectedIndex = Math.max(0, Math.min(selectedIndex, orgs.length - 1))
    }
    function onActionFinished(success) {
      if (success) root.close()
    }
    function onCacheLoadedChanged() {
      if (root.opened) root.refreshIfEmpty()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: Style.space(620)
    contentHeight: Style.space(560)

    Rectangle {
      id: card
      anchors.fill: parent
      color: "transparent"

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(18)
        spacing: Style.space(10)

        RowLayout {
          Layout.fillWidth: true

          SalesforceIcon {
            iconSize: Style.space(24)
            color: Color.foreground
          }

          ColumnLayout {
            Layout.fillWidth: true
            Text {
              text: "Salesforce Orgs"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }
            Text {
              text: liveService ? liveService.orgs.length + " configured org" + (liveService.orgs.length === 1 ? "" : "s") : "Loading..."
              color: Qt.darker(Color.foreground, 1.5)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

        }

        Text {
          Layout.fillWidth: true
          visible: liveService && (liveService.actionStatus !== "" || liveService.lastRefreshAt !== "")
          text: liveService && liveService.actionStatus !== ""
            ? liveService.actionStatus
            : "Last refresh: " + new Date(liveService.lastRefreshAt).toLocaleString()
          color: liveService && liveService.lastError !== "" ? Color.urgent : Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        TextField {
          id: searchField
          Layout.fillWidth: true
          visible: !root.addMode && root.searchMode
          placeholderText: "Search orgs"
          text: root.searchQuery
          onTextChanged: root.searchQuery = text
          onAccepted: root.commitSearch()
        }

        ListView {
          id: orgList
          property real savedContentY: 0
          property bool restoringContentY: false
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          model: root.filteredOrgs()
          spacing: Style.space(5)
          visible: !root.addMode
          interactive: true
          flickableDirection: Flickable.VerticalFlick
          boundsBehavior: Flickable.StopAtBounds
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
          onContentYChanged: if (!restoringContentY) savedContentY = contentY
          onModelChanged: Qt.callLater(function() {
            restoringContentY = true
            contentY = Math.max(0, Math.min(savedContentY, Math.max(0, contentHeight - height)))
            restoringContentY = false
          })
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: orgList.width
            height: Style.space(64)
            radius: Style.cornerRadius
            color: index === root.selectedIndex ? Color.accent : Color.popups.background
            border.color: index === root.selectedIndex ? Color.accent : Color.popups.border
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              Text {
                text: modelData.isSandbox ? "S" : "P"
                color: index === root.selectedIndex ? Color.background : Color.accent
                font.family: Style.font.family
                font.bold: true
              }
              ColumnLayout {
                Layout.fillWidth: true
                Text {
                  Layout.fillWidth: true
                  text: String(modelData.alias || modelData.username) + (modelData.isDefault ? "  *" : "")
                  color: index === root.selectedIndex ? Color.background : Color.foreground
                  font.family: Style.font.family
                  font.bold: true
                  elide: Text.ElideRight
                }
                Text {
                  Layout.fillWidth: true
                  text: String(modelData.username || "") + "  -  " + Model.statusLabel(modelData)
                  color: index === root.selectedIndex ? Color.background : (Model.statusIsConnected(modelData) ? Color.accent : Color.urgent)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }
              Button {
                text: "X"
                onClicked: root.beginDelete(modelData)
              }
            }

            MouseArea {
              anchors.fill: parent
              z: -1
              onClicked: {
                root.selectedIndex = index
                root.openSelected()
              }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          visible: !root.addMode
          text: root.deleteConfirmation
            ? "Y confirm    N cancel    Esc cancel"
            : "Enter open    R reauthorize    G refresh    A add    / search    X remove    Esc close"
          color: Qt.darker(Color.foreground, 1.4)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          visible: root.addMode
          spacing: Style.space(10)

          Text {
            text: "Add Salesforce org"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          ComboBox {
            id: addTypeField
            Layout.fillWidth: true
            model: root.addTypes
            currentIndex: root.addTypeIndex
            onCurrentIndexChanged: {
              root.addTypeIndex = currentIndex
              if (currentIndex === 1) root.addUrl = "https://test.salesforce.com"
              else if (currentIndex === 0) root.addUrl = "https://login.salesforce.com"
              else root.addUrl = root.addCustomUrl
            }
          }

          TextField {
            id: customUrlField
            Layout.fillWidth: true
            visible: root.addTypeIndex === 2
            placeholderText: "Custom login URL, e.g. https://mydomain.my.salesforce.com"
            text: root.addCustomUrl
            onTextChanged: {
              root.addCustomUrl = text
              if (root.addTypeIndex === 2) root.addUrl = text
            }
          }

          TextField {
            id: aliasField
            Layout.fillWidth: true
            placeholderText: "Alias, e.g. my-production"
            text: root.addAlias
            onTextChanged: root.addAlias = text
            onAccepted: root.startAdd()
          }

          RowLayout {
            Layout.fillWidth: true
            Button {
              text: "Authenticate"
              enabled: root.addAlias.trim() !== ""
              onClicked: root.startAdd()
            }
            Button {
              text: "Cancel"
              onClicked: root.addMode = false
            }
          }
        }
      }

      Rectangle {
        visible: root.deleteConfirmation
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.84)
        radius: parent.radius
        Column {
          anchors.centerIn: parent
          width: parent.width - Style.space(60)
          spacing: Style.space(12)
          Text {
            width: parent.width
            text: "Remove Salesforce org?"
            color: Color.foreground
            horizontalAlignment: Text.AlignHCenter
            font.bold: true
            font.pixelSize: Style.font.subtitle
          }
          Text {
            width: parent.width
            text: "Are you sure you want to delete " + String(root.deleteOrg ? (root.deleteOrg.alias || root.deleteOrg.username) : "this org") + "?"
            color: Color.foreground
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(8)
            Button {
              text: "Yes"
              onClicked: root.confirmDelete()
            }
            Button {
              text: "No"
              onClicked: {
                root.deleteConfirmation = false
                root.deleteOrg = null
              }
            }
          }
        }
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: card
      focus: true
      Keys.onPressed: function(event) {
        if (root.deleteConfirmation) {
          if (event.text === "y" || event.text === "Y") root.confirmDelete()
          else if (event.text === "n" || event.text === "N" || event.key === Qt.Key_Escape) root.cancelDelete()
          else return
          event.accepted = true
        }
        else if (event.key === Qt.Key_Escape) {
          if (root.searchMode) root.closeSearch()
          else root.close()
          event.accepted = true
        }
        else if (event.text === "g" || event.text === "G") {
          if (root.liveService) root.liveService.refresh()
          event.accepted = true
        }
        else if (event.key === Qt.Key_Down || event.text === "j") { root.moveSelection(1); event.accepted = true }
        else if (event.key === Qt.Key_Up || event.text === "k") { root.moveSelection(-1); event.accepted = true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.openSelected(); event.accepted = true }
        else if (event.text === "o" || event.text === "O") { root.openSelected(); event.accepted = true }
        else if (event.text === "r" || event.text === "R") { root.reauthenticateSelected(); event.accepted = true }
        else if (event.text === "a" || event.text === "A") { root.beginAdd(); event.accepted = true }
        else if (event.text === "/") { root.beginSearch(); event.accepted = true }
        else if (event.text === "x" || event.text === "X") { root.beginDelete(root.selectedOrg()); event.accepted = true }
      }
    }
  }

  function startAdd() {
    if (!liveService || addAlias.trim() === "") return
    if (!Model.validUrl(addUrl)) {
      liveService.actionStatus = "Enter a valid custom login URL"
      return
    }
    if (liveService.addOrg(addAlias, addUrl)) {
      addMode = false
      addAlias = ""
    }
  }
}
