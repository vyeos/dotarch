import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs
import qs.components

Item {
    id: root

    required property var notification
    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property color accent: critical ? Theme.red : (notification.urgency === NotificationUrgency.Low ? Theme.mutedDark : Theme.primary)
    readonly property int timeout: {
        if (critical || notification.expireTimeout === 0)
            return 0;
        if (notification.expireTimeout > 0)
            return notification.expireTimeout;
        return notification.urgency === NotificationUrgency.Low ? 4000 : 6000;
    }

    implicitHeight: cardContent.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.bg0
        border.width: 1
        border.color: root.accent
    }

    Column {
        id: cardContent

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 9

        Row {
            width: parent.width
            spacing: 10

            Rectangle {
                width: 38
                height: 38
                radius: Theme.radiusSmall
                color: Theme.bg1
                clip: true

                ShellText {
                    anchors.centerIn: parent
                    text: "󰂚"
                    color: root.accent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 17
                }

                IconImage {
                    anchors.fill: parent
                    anchors.margins: 6
                    source: root.notification.image || (root.notification.appIcon ? Quickshell.iconPath(root.notification.appIcon) : "")
                }
            }

            Column {
                width: parent.width - 38 - closeButton.width - parent.spacing * 2
                spacing: 3

                ShellText {
                    width: parent.width
                    text: root.notification.appName || "Notification"
                    color: root.accent
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                ShellText {
                    width: parent.width
                    text: root.notification.summary
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            IconButton {
                id: closeButton

                width: 28
                height: 28
                icon: "×"
                accessibleName: "Dismiss notification"
                backgroundColor: Theme.bg1
                onClicked: root.notification.dismiss()
            }
        }

        ShellText {
            width: parent.width
            visible: text.length > 0
            text: root.notification.body
            color: Theme.muted
            font.pixelSize: 11
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        Flow {
            width: parent.width
            visible: actionRepeater.count > 0
            spacing: 6

            Repeater {
                id: actionRepeater

                model: root.notification.actions

                delegate: Rectangle {
                    required property var modelData

                    width: Math.min(actionLabel.implicitWidth + 20, cardContent.width)
                    height: 28
                    radius: Theme.radiusSmall
                    color: actionPointer.containsMouse ? Theme.primaryContainer : Theme.bg1
                    border.width: 1
                    border.color: Theme.bg3

                    ShellText {
                        id: actionLabel

                        anchors.centerIn: parent
                        text: modelData.text
                        color: Theme.foreground
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: actionPointer

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
    }

    Timer {
        interval: root.timeout
        running: root.timeout > 0 && !hoverArea.containsMouse
        onTriggered: root.notification.expire()
    }

    Component.onDestruction: notification.tracked = false
}
