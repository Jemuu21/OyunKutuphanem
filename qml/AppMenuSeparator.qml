import QtQuick
import QtQuick.Controls

MenuSeparator {
    height: visible ? implicitHeight : 0
    topPadding: 4
    bottomPadding: 4
    contentItem: Rectangle { implicitHeight: 1; color: theme.line }
}
