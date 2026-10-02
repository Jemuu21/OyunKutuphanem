import QtQuick
import QtQuick.Controls

Menu {
    id: m
    topPadding: 6
    bottomPadding: 6
    font.family: theme.bodyFont
    font.pixelSize: 14
    background: Rectangle {
        implicitWidth: 250
        color: theme.surfaceHigh
        radius: 9
        border.color: theme.line
    }
    enter: Transition { enabled: appRoot.motion; NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 110 } }
    exit: Transition { enabled: appRoot.motion; NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90 } }
}
