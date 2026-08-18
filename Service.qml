import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property var shell: null
  property var orgs: []
  property string lastRefreshAt: ""
  property bool cacheLoaded: false
  property bool busy: false
  property bool actionPending: false
  property bool actionInteractive: false
  property bool actionRefreshesOrgs: false
  property int operationGeneration: 0
  property int actionProcessGeneration: 0
  property var queuedActionCommand: null
  property string queuedActionLabel: ""
  property bool queuedActionRefreshesOrgs: false
  property string queuedAuthTarget: ""
  property string queuedAuthUrl: ""
  property bool queuedAuthRefreshesOrgs: false
  property int authPollGeneration: 0
  property var actionProcessOverride: null
  property var detachedOverride: null
  property string actionStatus: ""
  property string lastError: ""
  property string authTarget: ""
  property string authToken: ""
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
    || (Quickshell.env("HOME") + "/.cache/omarchy")
  readonly property string authStateDir: runtimeDir + "/omarchy-sf-plugin"
  readonly property string cachePath: Quickshell.env("HOME") + "/.cache/omarchy/salesforce-orgs.json"

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
    cancelCurrentCommand()
    busy = true
    actionStatus = "Refreshing orgs..."
    lastError = ""
    listProcess.command = ["sf", "org", "list", "--json"]
    listProcess.running = true
  }

  function cancelCurrentCommand() {
    if (actionPending || actionRunning()) cancelPendingAction()
    if (listProcess.running) {
      listProcess.running = false
      busy = false
    }
    if (authPollProcess.running) authPollProcess.running = false
  }

  function loadCache(raw) {
    root.cacheLoaded = true
    try {
      var cached = JSON.parse(String(raw || "{}"))
      if (!Array.isArray(cached.orgs)) return
      root.orgs = cached.orgs
      root.lastRefreshAt = String(cached.refreshedAt || "")
    } catch (error) {
      root.lastRefreshAt = ""
    }
  }

  function saveCache() {
    root.lastRefreshAt = new Date().toISOString()
    var payload = JSON.stringify({
      version: 1,
      refreshedAt: root.lastRefreshAt,
      orgs: root.orgs
    }, null, 2) + "\n"
    cacheWriteProcess.command = ["bash", "-c", "printf '%s' \"$1\" > \"$2\"", "--", payload, root.cachePath]
    cacheWriteProcess.running = true
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
    startInteractiveAuth(target, url, true)
  }

  function removeOrg(org) {
    var target = selectedTarget(org)
    if (target === "") return
    runAction(["sf", "org", "logout", "--target-org", target, "--no-prompt"], "Removing " + target + "...", true)
  }

  function addOrg(alias, url) {
    var cleanAlias = String(alias || "").trim()
    var cleanUrl = Model.trimUrl(url)
    if (cleanAlias === "" || !Model.validUrl(cleanUrl)) return false
    startInteractiveAuth(cleanAlias, cleanUrl, true)
    return true
  }

  // Run browser auth in an independent session so popup dismissal or shell
  // focus changes cannot terminate the localhost OAuth listener.
  function startInteractiveAuth(target, url, refreshesOrgs) {
    var wasPolling = authPollProcess.running
    queuedAuthTarget = target
    queuedAuthUrl = url
    queuedAuthRefreshesOrgs = refreshesOrgs === true
    cancelCurrentCommand()
    if (wasPolling) return
    startQueuedAuth()
  }

  function startQueuedAuth() {
    var target = queuedAuthTarget
    if (target === "") return
    var url = queuedAuthUrl
    var refreshesOrgs = queuedAuthRefreshesOrgs
    queuedAuthTarget = ""
    queuedAuthUrl = ""
    queuedAuthRefreshesOrgs = false
    operationGeneration++
    actionPending = true
    actionInteractive = true
    actionRefreshesOrgs = refreshesOrgs === true
    authTarget = target
    authToken = String(Date.now()) + "-" + String(Math.floor(Math.random() * 1000000))
    actionStatus = "Waiting for Salesforce login for " + target + "..."
    lastError = ""
    var script = Qt.resolvedUrl("auth-web-login.sh").toString().replace("file://", "")
    startDetached(["/usr/bin/setsid", "/usr/bin/bash", script, target, url, authToken, authStateDir])
    authPoll.restart()
  }

  function startDetached(command) {
    if (detachedOverride) detachedOverride.start(command)
    else Quickshell.execDetached(command)
  }

  function authStateName() {
    return Model.safeName(authTarget) + "-" + authToken
  }

  function authStateExpr() {
    return 'D="' + authStateDir + '"; cat "$D/' + authStateName() + '.status" 2>/dev/null || true'
  }

  function authKillExpr() {
    return 'D="' + authStateDir + '"; P="$D/' + authStateName() + '.pid"; [ -f "$P" ] && kill "$(cat "$P")" 2>/dev/null || true'
  }

  function runAction(command, label, refreshesOrgs) {
    queuedActionCommand = command
    queuedActionLabel = label || "Running Salesforce CLI..."
    queuedActionRefreshesOrgs = refreshesOrgs === true
    var wasRunning = actionRunning()
    cancelCurrentCommand()
    if (wasRunning) return
    startQueuedAction()
  }

  function startQueuedAction() {
    var command = queuedActionCommand
    if (!command) return
    queuedActionCommand = null
    var label = queuedActionLabel
    var refreshesOrgs = queuedActionRefreshesOrgs
    queuedActionLabel = ""
    queuedActionRefreshesOrgs = false
    operationGeneration++
    actionProcessGeneration = operationGeneration
    actionPending = true
    actionInteractive = false
    actionRefreshesOrgs = refreshesOrgs
    actionStatus = label
    lastError = ""
    if (actionProcessOverride) actionProcessOverride.start(command)
    else {
      actionProcess.command = command
      actionProcess.running = true
    }
    actionTimeout.restart()
  }

  function actionRunning() {
    return actionProcessOverride ? actionProcessOverride.running : actionProcess.running
  }

  function cancelPendingAction() {
    if (!actionPending && !actionRunning()) return
    actionTimeout.stop()
    operationGeneration++
    actionPending = false
    actionStatus = ""
    actionRefreshesOrgs = false
    if (actionInteractive) {
      actionInteractive = false
      killProcess.command = ["/usr/bin/bash", "-c", authKillExpr()]
      killProcess.running = true
      authTarget = ""
      authToken = ""
    } else if (actionProcessOverride) actionProcessOverride.stop()
    else actionProcess.running = false
  }

  function actionTimedOut() {
    if (actionInteractive || (!actionPending && !actionRunning())) return
    // Timeout is an explicit failure: the CLI may have acted just before it
    // was stopped, so reconcile the org list instead of abandoning state.
    cancelPendingAction()
    root.refresh()
    lastError = "Salesforce CLI command timed out"
    actionStatus = "Salesforce action timed out"
    actionFinished(false)
  }

  function finishAction(exitCode, output, error) {
    var generation = arguments.length > 3 ? arguments[3] : undefined
    if (generation !== undefined && generation !== root.operationGeneration) {
      startQueuedAction()
      return
    }
    var shouldRefreshOrgs = actionRefreshesOrgs
    actionPending = false
    actionInteractive = false
    actionRefreshesOrgs = false
    authTarget = ""
    authToken = ""
    actionTimeout.stop()
    authPoll.stop()
    if (exitCode !== 0) {
      lastError = String(error || output || "Salesforce CLI command failed").trim()
      actionStatus = "Salesforce action failed"
      actionFinished(false)
    } else {
      lastError = ""
      actionStatus = ""
      if (shouldRefreshOrgs) root.refresh()
      actionFinished(true)
    }
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
      if (parsed.error === "") root.saveCache()
      if (!root.actionPending) root.actionStatus = ""
    }
  }

  Process {
    id: actionProcess
    stdout: StdioCollector { id: actionOutput; waitForEnd: true }
    stderr: StdioCollector { id: actionError; waitForEnd: true }
    onExited: root.finishAction(exitCode, actionOutput.text, actionError.text, root.actionProcessGeneration)
  }

  Process {
    id: killProcess
  }

  Process {
    id: cacheDirProcess
    command: ["mkdir", "-p", Quickshell.env("HOME") + "/.cache/omarchy"]
    onExited: cacheReadProcess.running = true
  }

  Process {
    id: cacheReadProcess
    command: ["cat", root.cachePath]
    stdout: StdioCollector { id: cacheReadOutput; waitForEnd: true }
    onExited: root.loadCache(cacheReadOutput.text)
  }

  Process {
    id: cacheWriteProcess
  }

  Process {
    id: authPollProcess
    stdout: StdioCollector { id: authPollOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (authPollGeneration !== root.operationGeneration) {
        root.startQueuedAuth()
        return
      }
      var text = String(authPollOutput.text || "").trim()
      if (!/^\d+$/.test(text)) return
      var code = parseInt(text, 10)
      if (code === 0) root.finishAction(0, "", "")
      else root.finishAction(code, "", "Salesforce login failed (exit " + code + ")")
    }
  }

  Timer {
    id: authPoll
    interval: 1000
    repeat: true
    onTriggered: {
      if (!root.actionPending || !root.actionInteractive || root.authTarget === "") return
      if (authPollProcess.running) return
      root.authPollGeneration = root.operationGeneration
      authPollProcess.command = ["/usr/bin/bash", "-c", root.authStateExpr()]
      authPollProcess.running = true
    }
  }

  Timer {
    id: actionTimeout
    // Only non-interactive CLI commands get a bounded lifetime; browser auth
    // waits for its localhost callback with no fixed deadline.
    interval: 120000
    repeat: false
    onTriggered: root.actionTimedOut()
  }

  Component.onCompleted: cacheDirProcess.running = true

}
