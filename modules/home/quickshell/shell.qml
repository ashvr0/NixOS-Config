import QtQuick
import Quickshell
import "."
import "Widgets" as Widgets
import "Bar"
import "Singletons"

ShellRoot {
    Bar {}
    Launcher {}
    Clipboard {}
    Notification {}
    WallpaperPicker {}
    Widgets.DesktopWidgets {}
}
