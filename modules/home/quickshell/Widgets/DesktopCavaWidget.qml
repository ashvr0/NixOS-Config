import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../Singletons"

Item {
  id: root
  anchors.fill: parent

  property real targetSlotWidth: 16
  property int minBars: 8
  property int maxBars: Cava.barCount // can't exceed what the singleton computes

  property int activeBars: Math.max(
    root.minBars,
    Math.min(root.maxBars, Math.floor(width / root.targetSlotWidth))
  )

  property bool isVisVisible: visible

  onIsVisVisibleChanged: {
    if (isVisVisible) Cava.registerConsumer();
    else Cava.unregisterConsumer();
  }

  Component.onCompleted: {
    if (isVisVisible) Cava.registerConsumer();
  }

  Component.onDestruction: {
    if (isVisVisible) Cava.unregisterConsumer();
  }

  // Resample the singleton's fixed-size barLevels array down (or across)
  // to however many bars currently fit in this widget's width. Mapped
  // by distance-from-center (fanning outward) rather than linearly, with
  // a noise floor and gamma curve so quiet signal doesn't look jittery.
  property var displayLevels: {
    let source = Cava.barLevels;
    let count = root.activeBars;
    let out = [];

    if (!source || source.length === 0) {
      for (let i = 0; i < count; i++) out.push(0.0);
      return out;
    }

    let srcLen = source.length;
    let half = (count - 1) / 2;

    for (let i = 0; i < count; i++) {
      let distFromCenter = Math.abs(i - half);
      let norm = half > 0 ? (distFromCenter / half) : 0;
      let pos = Math.pow(norm, 1.25) * (srcLen - 1);
      let idx0 = Math.floor(pos);
      let idx1 = Math.min(srcLen - 1, idx0 + 1);
      let frac = pos - idx0;

      let v0 = source[idx0] || 0.0;
      let v1 = source[idx1] || 0.0;
      let rawVal = v0 + (v1 - v0) * frac;

      let val = rawVal < 0.03 ? 0.0 : Math.pow((rawVal - 0.03) / 0.97, 1.15);
      out.push(Math.max(0.0, Math.min(1.0, val)));
    }

    return out;
  }

  // ── Rendering: bars anchored to the bottom, flat baseline ──
  Item {
    anchors.fill: parent

    Row {
      id: barsRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: parent.height
      spacing: Math.max(1, width / root.activeBars * 0.25)

      Repeater {
        model: root.activeBars
        delegate: Rectangle {
          required property int index
          readonly property real level: (root.displayLevels && index < root.displayLevels.length) ? root.displayLevels[index] : 0.0
          readonly property real ratio: Math.max(0, Math.min(1, level))
          readonly property real edgeNorm: Math.sin((index / Math.max(1, root.activeBars - 1)) * Math.PI)
          readonly property real rawEdgeFactor: Math.min(1.0, edgeNorm * 2.0)
          readonly property real edgeFactor: rawEdgeFactor * rawEdgeFactor * (3.0 - 2.0 * rawEdgeFactor)
          width: Math.max(1, (barsRow.width - barsRow.spacing * (root.activeBars - 1)) / root.activeBars)
          height: Math.max(3, barsRow.height * ratio * edgeFactor)
          anchors.bottom: parent.bottom
          radius: width / 2
          color: MatugenColors.accent
          opacity: (0.3 + (ratio * 0.7)) * edgeFactor

          Behavior on height {
            NumberAnimation { duration: 75; easing.type: Easing.OutQuad }
          }

          Behavior on opacity {
            NumberAnimation { duration: 75; easing.type: Easing.OutQuad }
          }
        }
      }
    }
  }
}
