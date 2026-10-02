import QtQuick
import QtQuick.Layouts

// Alt ortada kısa bildirimler
Column {
    id: t
    spacing: 8
    property int uid: 0
    function show(text, kind) {
        uid += 1
        items.append({ msg: text, kind: kind || "info", uid: uid })
        if (items.count > 4) items.remove(0)
    }
    ListModel { id: items }

    Repeater {
        model: items
        Rectangle {
            id: toast
            required property string msg
            required property string kind
            required property int uid
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(560, label.implicitWidth + 48)
            height: label.implicitHeight + 22
            radius: 10
            color: theme.surfaceHigh
            border.color: theme.line
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { enabled: appRoot.motion; NumberAnimation { duration: 160 } }

            Rectangle {
                x: 10; anchors.verticalCenter: parent.verticalCenter
                width: 4; height: parent.height - 18; radius: 2
                color: toast.kind === "error" ? theme.danger : toast.kind === "ok" ? theme.ok : theme.accent
            }
            Text {
                id: label
                x: 26
                width: Math.min(implicitWidth, 512)
                anchors.verticalCenter: parent.verticalCenter
                text: toast.msg
                color: theme.text
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }
            MouseArea { anchors.fill: parent; onClicked: remove() }
            Timer { running: true; interval: toast.kind === "error" ? 7000 : 4500; onTriggered: toast.remove() }
            function remove() {
                for (var i = 0; i < items.count; i++)
                    if (items.get(i).uid === toast.uid) { items.remove(i); return }
            }
        }
    }
}
