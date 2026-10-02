import QtQuick
import QtQuick.Controls

TextField {
    id: f
    font.family: theme.bodyFont
    font.pixelSize: 14
    color: theme.text
    placeholderTextColor: theme.faint
    selectionColor: theme.accent
    selectedTextColor: theme.onAccent
    leftPadding: 12
    rightPadding: 12
    implicitHeight: 38
    background: Rectangle {
        radius: 7
        color: theme.surfaceHigh
        border.width: f.activeFocus ? 2 : 1
        border.color: f.activeFocus ? theme.accent : theme.line
    }
}
