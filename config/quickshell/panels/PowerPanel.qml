import QtQuick
import qs
import qs.components

FocusScope {
    id: root

    property string pendingAction: ""
    readonly property var actions: [{
        "key": "lock",
        "icon": "󰌾",
        "title": "Lock"
    }, {
        "key": "suspend",
        "icon": "󰤄",
        "title": "Suspend"
    }, {
        "key": "logout",
        "icon": "󰍃",
        "title": "Log out"
    }, {
        "key": "reboot",
        "icon": "󰜉",
        "title": "Reboot"
    }, {
        "key": "shutdown",
        "icon": "󰐥",
        "title": "Power off"
    }]

    function activate(action) {
        const needsConfirmation = action === "reboot" || action === "shutdown";
        if (needsConfirmation && pendingAction !== action) {
            pendingAction = action;
            confirmReset.restart();
            return ;
        }
        Backend.power(action);
        ShellState.close();
    }

    implicitWidth: 352
    implicitHeight: content.implicitHeight

    Timer {
        id: confirmReset

        interval: 3000
        onTriggered: root.pendingAction = ""
    }

    Column {
        id: content

        width: parent.width
        spacing: 8

        Row {
            width: parent.width
            height: 64
            spacing: 8

            Repeater {
                model: root.actions

                delegate: FocusScope {
                    id: actionButton

                    required property var modelData
                    readonly property bool highlighted: activeFocus || pointer.containsMouse

                    width: 64
                    height: parent.height
                    activeFocusOnTab: true
                    Keys.onReturnPressed: root.activate(modelData.key)
                    Keys.onEnterPressed: root.activate(modelData.key)
                    Keys.onSpacePressed: root.activate(modelData.key)
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.title

                    Rectangle {
                        anchors.fill: parent
                        radius: 13
                        color: root.pendingAction === modelData.key ? Theme.yellow : (actionButton.highlighted ? Theme.primary : Theme.bg1)
                        border.width: parent.activeFocus ? 2 : 0
                        border.color: Theme.primary

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.animationFast
                            }

                        }

                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        ShellText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.pendingAction === modelData.key ? "?" : modelData.icon
                            color: root.pendingAction === modelData.key || actionButton.highlighted ? Theme.bgDim : Theme.muted
                            font.pixelSize: 16
                            font.weight: Font.Bold
                        }

                        ShellText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.pendingAction === modelData.key ? "Confirm" : modelData.title
                            color: root.pendingAction === modelData.key || actionButton.highlighted ? Theme.bgDim : Theme.muted
                            font.pixelSize: 8
                            font.weight: Font.Bold
                        }

                    }

                    MouseArea {
                        id: pointer

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activate(modelData.key)
                    }

                }

            }

        }

    }

}
