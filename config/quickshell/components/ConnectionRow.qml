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
    property int titleFontSize: 10
    property int subtitleFontSize: 8
    property int actionFontSize: 8
    property bool secondaryActionVisible: false
    property string secondaryActionIcon: "󰆴"
    property string secondaryActionName: "Remove"

    signal clicked()
    signal secondaryClicked()

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
            font.pixelSize: root.titleFontSize
            font.weight: Font.DemiBold
        }

        ShellText {
            width: parent.width
            text: root.subtitle
            color: Theme.muted
            elide: Text.ElideRight
            font.pixelSize: root.subtitleFontSize
        }

    }

    ShellText {
        id: actionLabel

        anchors.right: secondaryAction.visible ? secondaryAction.left : parent.right
        anchors.rightMargin: secondaryAction.visible ? 5 : 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.busy ? "Working…" : root.actionText
        color: root.active ? Theme.primary : Theme.aqua
        font.pixelSize: root.actionFontSize
        font.weight: Font.Bold
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    FocusScope {
        id: secondaryAction

        anchors.right: parent.right
        anchors.rightMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        visible: root.secondaryActionVisible
        activeFocusOnTab: visible
        Keys.onReturnPressed: root.secondaryClicked()
        Keys.onEnterPressed: root.secondaryClicked()
        Keys.onSpacePressed: root.secondaryClicked()
        Accessible.role: Accessible.Button
        Accessible.name: root.secondaryActionName

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: secondaryPointer.containsMouse || secondaryAction.activeFocus ? Theme.bg2 : "transparent"
        }

        ShellText {
            anchors.centerIn: parent
            text: root.secondaryActionIcon
            color: secondaryPointer.containsMouse || secondaryAction.activeFocus ? Theme.red : Theme.mutedDark
            font.pixelSize: 10
        }

        MouseArea {
            id: secondaryPointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.secondaryClicked()
        }
    }

}
