import QtQuick
import qs

FocusScope {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool expandable: false
    property bool expanded: false

    signal clicked()

    implicitHeight: 58
    activeFocusOnTab: true
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
    Accessible.role: Accessible.Button
    Accessible.name: title + (subtitle ? ", " + subtitle : "")

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: root.active ? Theme.green : Theme.bg0
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.foreground

        Behavior on color {
            ColorAnimation {
                duration: Theme.animationFast
            }

        }

    }

    Row {
        anchors.fill: parent
        anchors.margins: 9
        spacing: 8

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30
            radius: 15
            color: root.active ? Qt.rgba(0.12, 0.14, 0.12, 0.14) : Theme.bg1

            ShellText {
                anchors.centerIn: parent
                text: root.icon
                color: root.active ? Theme.bgDim : Theme.muted
                font.pixelSize: 14
                font.weight: Font.Bold
            }

        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 38 - (root.expandable ? 15 : 0)
            spacing: 2

            ShellText {
                width: parent.width
                text: root.title
                color: root.active ? Theme.bgDim : Theme.foreground
                elide: Text.ElideRight
                font.pixelSize: 12
                font.weight: Font.Bold
            }

            ShellText {
                width: parent.width
                text: root.subtitle
                color: root.active ? Qt.rgba(0.12, 0.14, 0.12, 0.68) : Theme.muted
                elide: Text.ElideRight
                font.pixelSize: 9
            }

        }

        ShellText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.expandable
            text: root.expanded ? "󰅃" : "󰅀"
            color: root.active ? Qt.rgba(0.12, 0.14, 0.12, 0.62) : Theme.mutedDark
            font.pixelSize: 11
        }

    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

}
