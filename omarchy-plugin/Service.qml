import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property var orgs: []
  property bool busy: false
  property string actionStatus: ""
  property string lastError: ""
  property int refreshIntervalSec: intSetting("refreshIntervalSec", 60, 15, 3600)

  signal actionFinished(bool success)

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var value = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(value)) value = fallback
    return Math.max(min, Math.min(max, value))
  }

  function refresh() {
    if (listProcess.running) return
    busy = true
    lastError = ""
    listProcess.command = ["sf", "org", "list", "--json"]
    listProcess.running = true
  }

  function selectedTarget(org) {
    if (!org) return ""
    return String(org.alias || org.username || "")
  }

  function openOrg(org) {
    var target = selectedTarget(org)
    if (target === "") return
    runAction(["sf", "org", "open", "--target-org", target], "Opening " + target + "...")
  }

  function reauthenticate(org) {
    var target = selectedTarget(org)
    var url = org && org.isSandbox ? "https://test.salesforce.com" : "https://login.salesforce.com"
    if (target === "" || !Model.validUrl(url)) return
    runAction(["sf", "org", "login", "web", "--alias", target, "--instance-url", url], "Opening Salesforce login for " + target + "...")
  }

  function addOrg(alias, url) {
    var cleanAlias = String(alias || "").trim()
    var cleanUrl = Model.trimUrl(url)
    if (cleanAlias === "" || !Model.validUrl(cleanUrl)) return false
    runAction(["sf", "org", "login", "web", "--alias", cleanAlias, "--instance-url", cleanUrl], "Opening Salesforce login for " + cleanAlias + "...")
    return true
  }

  function runAction(command, label) {
    actionStatus = label || "Running Salesforce CLI..."
    lastError = ""
    actionProcess.command = command
    actionProcess.running = true
  }

  Process {
    id: listProcess
    stdout: StdioCollector { id: listOutput; waitForEnd: true }
    stderr: StdioCollector { id: listError; waitForEnd: true }
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0) {
        root.lastError = String(listError.text || "sf org list failed").trim()
        root.actionStatus = "Unable to refresh orgs"
        return
      }
      var parsed = Model.parseOrgs(listOutput.text)
      root.orgs = parsed.orgs
      root.lastError = parsed.error
      root.actionStatus = ""
    }
  }

  Process {
    id: actionProcess
    stdout: StdioCollector { id: actionOutput; waitForEnd: true }
    stderr: StdioCollector { id: actionError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = String(actionError.text || actionOutput.text || "Salesforce CLI command failed").trim()
        root.actionStatus = "Salesforce action failed"
        root.actionFinished(false)
      } else {
        root.lastError = ""
        root.actionStatus = "Refreshing orgs..."
        refreshDelay.restart()
        root.actionFinished(true)
      }
    }
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: refreshDelay
    interval: 700
    repeat: false
    onTriggered: {
      root.actionStatus = ""
      root.refresh()
    }
  }
}
