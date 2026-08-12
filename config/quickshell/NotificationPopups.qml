import QtQuick
import Quickshell
import qs

PanelWindow {
    id: window

    required property var notificationModel

    implicitWidth: 390
    implicitHeight: Math.min(screen ? screen.height - 40 : popupStack.implicitHeight, popupStack.implicitHeight)
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }

    margins {
        top: 14
        right: 14
    }

    Column {
        id: popupStack

        width: parent.width
        spacing: 8

        Repeater {
            model: window.notificationModel

            delegate: NotificationCard {
                required property var modelData

                width: popupStack.width
                notification: modelData
            }
        }
    }

    mask: Region {
        item: popupStack
    }
}
