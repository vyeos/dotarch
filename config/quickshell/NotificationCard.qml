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
    readonly property bool batteryNotification: (notification.appName || "").toLowerCase() === "power"
        || (notification.summary || "").toLowerCase().includes("battery")
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
        radius: 24
        color: Qt.rgba(Theme.bg0.r, Theme.bg0.g, Theme.bg0.b, 0.86)
        border.width: 1
        border.color: root.critical ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.7) : Qt.rgba(1, 1, 1, 0.12)
        z: -1
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
                radius: 12
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.13)
                clip: true

                ShellText {
                    anchors.centerIn: parent
                    text: root.batteryNotification ? "󰂃" : "󰂚"
                    color: root.accent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: root.batteryNotification ? 19 : 17
                }

                IconImage {
                    anchors.fill: parent
                    anchors.margins: 6
                    visible: !root.batteryNotification
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
                z: 2
                icon: "×"
                accessibleName: "Dismiss notification"
                backgroundColor: Qt.rgba(Theme.bg1.r, Theme.bg1.g, Theme.bg1.b, 0.72)
                foregroundColor: Theme.muted
                hoverBackgroundColor: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                hoverForegroundColor: root.accent
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
