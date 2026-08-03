import QtQuick
import Quickshell
import "Scaler.js" as LayoutMath

Item {
    id: root
    visible: false

    property real currentWidth: 3840.0
    property real currentHeight: 2160.0
    property real uiScale: Config.uiScale

    property real baseScale: LayoutMath.getScale(currentWidth, currentHeight, uiScale)

    function s(val) {
        return LayoutMath.s(val, baseScale);
    }
}
