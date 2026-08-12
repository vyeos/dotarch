import QtQuick
import Quickshell
import qs
import qs.components

FocusScope {
    id: root

    property int selectedIndex: 0

    function takeInitialFocus() {
        Backend.refreshClipboard();
        searchInput.forceActiveFocus(Qt.TabFocusReason);
    }

    function activateSelection() {
        if (filteredItems.values.length === 0)
            return ;

        Backend.copyClipboard(filteredItems.values[Math.min(selectedIndex, filteredItems.values.length - 1)].id);
        ShellState.close();
    }

    implicitWidth: 337
    implicitHeight: content.implicitHeight

    Column {
        id: content

        width: parent.width
        spacing: 8

        PanelHeader {
            title: "Clipboard"
            onCloseRequested: ShellState.close()
        }

        Rectangle {
            width: parent.width
            height: 40
            radius: Theme.radiusSmall
            color: Theme.bg0
            border.width: searchInput.activeFocus ? 2 : 1
            border.color: searchInput.activeFocus ? Theme.green : Theme.bg2

            ShellText {
                anchors.left: parent.left
                anchors.leftMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍉"
                color: Theme.muted
            }

            TextInput {
                id: searchInput

                anchors.left: parent.left
                anchors.leftMargin: 35
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 12
                clip: true
                activeFocusOnTab: true
                onTextChanged: root.selectedIndex = 0
                Keys.onDownPressed: root.selectedIndex = Math.min(filteredItems.values.length - 1, root.selectedIndex + 1)
                Keys.onUpPressed: root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                Keys.onReturnPressed: root.activateSelection()
                Keys.onEnterPressed: root.activateSelection()
                Keys.onEscapePressed: ShellState.close()

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search clipboard history…"
                    color: Theme.mutedDark
                    visible: !parent.text
                }

            }

        }

        ListView {
            id: clipboardList

            width: parent.width
            height: Math.min(5, count) * 48
            spacing: 4
            clip: true

            ShellText {
                anchors.centerIn: parent
                visible: clipboardList.count === 0
                text: "Clipboard history is empty"
                color: Theme.muted
            }

            model: ScriptModel {
                id: filteredItems

                objectProp: "id"
                values: Backend.clipboardItems.filter((item) => {
                    return !searchInput.text || item.preview.toLowerCase().includes(searchInput.text.toLowerCase());
                }).slice(0, 5)
            }

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: clipboardList.width
                height: 44
                radius: Theme.radiusSmall
                color: index === root.selectedIndex ? Theme.bgGreen : Theme.bg0
                border.width: index === root.selectedIndex ? 1 : 0
                border.color: Theme.blue

                ShellText {
                    anchors.left: parent.left
                    anchors.right: keyHint.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.preview
                    elide: Text.ElideRight
                    font.pixelSize: 10
                }

                ShellText {
                    id: keyHint

                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    text: index === root.selectedIndex ? "↵ paste" : ""
                    color: Theme.muted
                    font.pixelSize: 8
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = index
                    onClicked: root.activateSelection()
                }

            }

        }

    }

}
