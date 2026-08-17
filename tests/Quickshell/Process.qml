import QtQuick

QtObject {
  property var command: []
  property bool running: false
  property var stdout
  property var stderr
  signal exited(int exitCode)
}
