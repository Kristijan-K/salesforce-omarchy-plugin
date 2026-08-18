import QtQuick
import QtTest
import ".."

TestCase {
  name: "Service"

  QtObject {
    id: mockProcess
    property bool running: false
    property var command: []

    function start(nextCommand) {
      command = nextCommand
      running = true
    }

    function stop() {
      running = false
    }
  }

  QtObject {
    id: mockDetached
    property var command: []

    function start(nextCommand) {
      command = nextCommand
    }
  }

  Service {
    id: service
    actionProcessOverride: mockProcess
    detachedOverride: mockDetached
  }

  SignalSpy {
    id: actionSpy
    target: service
    signalName: "actionFinished"
  }

  function init() {
    mockProcess.running = false
    mockProcess.command = []
    mockDetached.command = []
    service.actionPending = false
    service.actionInteractive = false
    service.authTarget = ""
    service.authToken = ""
    service.actionStatus = ""
    service.lastError = ""
    actionSpy.clear()
  }

  function test_confirmedLogoutBuildsCommand() {
    service.removeOrg({ alias: "test-org" })
    compare(JSON.stringify(mockProcess.command), JSON.stringify([
      "sf", "org", "logout", "--target-org", "test-org", "--no-prompt"
    ]))
    verify(service.actionPending)
  }

  function test_reauthenticationRunsInIsolatedProcess() {
    service.reauthenticate({ alias: "test-org", isSandbox: false })
    compare(mockDetached.command[0], "/usr/bin/setsid")
    compare(mockDetached.command[1], "/usr/bin/bash")
    verify(String(mockDetached.command[2]).indexOf("auth-web-login.sh") !== -1)
    compare(mockDetached.command[3], "test-org")
    compare(mockDetached.command[4], "https://login.salesforce.com")
    compare(mockDetached.command[5], service.authToken)
    compare(mockDetached.command[6], service.authStateDir)
    verify(service.actionPending)
    verify(service.actionInteractive)
  }

  function test_logoutTimeoutReportsFailureAndReconciles() {
    service.removeOrg({ alias: "test-org" })
    service.actionTimedOut()
    verify(!mockProcess.running)
    verify(!service.actionPending)
    compare(service.actionStatus, "Salesforce action timed out")
    verify(service.lastError !== "")
    compare(actionSpy.count, 1)
    compare(actionSpy.signalArguments[0][0], false)
    // Late exit from the stopped process must not double-report.
    service.finishAction(1, "", "killed", service.operationGeneration - 1)
    compare(actionSpy.count, 1)
  }

  function test_successfulCompletionCleansUpState() {
    service.removeOrg({ alias: "test-org" })
    service.finishAction(0, "", "")
    verify(!service.actionPending)
    compare(service.lastError, "")
    compare(actionSpy.count, 1)
    compare(actionSpy.signalArguments[0][0], true)
  }

  function test_failedCompletionCleansUpState() {
    service.removeOrg({ alias: "test-org" })
    service.finishAction(1, "", "logout failed")
    verify(!service.actionPending)
    compare(service.actionStatus, "Salesforce action failed")
    compare(service.lastError, "logout failed")
    compare(actionSpy.count, 1)
    compare(actionSpy.signalArguments[0][0], false)
  }
}
