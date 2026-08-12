import QtQuick
import qs

FocusScope {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string actionText: "Connect"
    property bool active: false
    property bool busy: false

    signal clicked()

    implicitHeight: 42
    activeFocusOnTab: true
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
    Accessible.role: Accessible.Button
    Accessible.name: title + ", " + subtitle + ", " + actionText

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: pointer.containsMouse || root.activeFocus ? Theme.primaryContainer : Theme.bg0
        border.width: root.active ? 1 : 0
        border.color: Theme.primary

        Behavior on color {
            ColorAnimation {
                duration: Theme.animationFast
            }

        }

    }

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 27
        height: 27
        radius: 9
        color: root.active ? Theme.primary : Theme.bg2

        ShellText {
            anchors.centerIn: parent
            text: root.icon
            color: root.active ? Theme.bgDim : Theme.muted
            font.pixelSize: 13
            font.weight: Font.Bold
        }

    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 43
        anchors.right: actionLabel.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        ShellText {
            width: parent.width
            text: root.title
            elide: Text.ElideRight
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }

        ShellText {
            width: parent.width
            text: root.subtitle
            color: Theme.muted
            elide: Text.ElideRight
            font.pixelSize: 8
        }

    }

    ShellText {
        id: actionLabel

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.busy ? "Working…" : root.actionText
        color: root.active ? Theme.primary : Theme.aqua
        font.pixelSize: 8
        font.weight: Font.Bold
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

}
