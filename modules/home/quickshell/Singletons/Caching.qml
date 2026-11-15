pragma Singleton
import QtQuick
import Quickshell

QtObject {
  readonly property string cacheRoot: Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")
  readonly property string mainQml: Quickshell.shellPath("shell.qml")

  function getCacheDir(name) {
    var dir = cacheRoot + "/quickshell/" + name
    Quickshell.execDetached(["mkdir", "-p", dir])
    return dir
  }
}
