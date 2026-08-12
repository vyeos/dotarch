import QtQuick
import Quickshell
import qs
import qs.components

FocusScope {
    id: root

    property int selectedIndex: 0
    property bool previewVisible: false
    property bool previewTransitionActive: false
    property string previewItemId: ""

    function takeInitialFocus() {
        selectedIndex = 0;
        previewVisible = false;
        previewItemId = "";
        Backend.refreshClipboard();
        searchInput.forceActiveFocus(Qt.TabFocusReason);
    }

    Connections {
        function onPanelChanged() {
            if (ShellState.panel !== "clipboard") {
                searchInput.clear();
                root.selectedIndex = 0;
                root.previewVisible = false;
                root.previewItemId = "";
            }
        }

        target: ShellState
    }

    function selectedItem() {
        if (filteredItems.values.length === 0)
            return null;

        return filteredItems.values[Math.min(selectedIndex, filteredItems.values.length - 1)];
    }

    function moveSelection(offset) {
        const count = filteredItems.values.length;
        if (count === 0)
            return;

        selectedIndex = Math.max(0, Math.min(count - 1, selectedIndex + offset));
        clipboardList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function togglePreview() {
        const item = selectedItem();
        if (!item)
            return ;

        previewTransitionActive = true;
        previewTransitionTimer.restart();
        if (previewVisible && previewItemId === item.id) {
            previewVisible = false;
            return ;
        }
        previewItemId = item.id;
        previewVisible = true;
        Backend.loadClipboardContents(item.id, item.preview);
    }

    function activateSelection() {
        const item = selectedItem();
        if (!item)
            return ;

        Backend.pasteClipboard(item.id);
        ShellState.close();
    }

    implicitWidth: 337
    implicitHeight: content.implicitHeight

    Timer {
        id: previewTransitionTimer

        interval: Theme.animationFast
        onTriggered: root.previewTransitionActive = false
    }

    Column {
        id: content

        width: parent.width
        spacing: 8

        Rectangle {
            width: parent.width
            height: 42
            color: "transparent"

            ShellText {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍉"
                color: Theme.muted
                font.pixelSize: 14
            }

            TextInput {
                id: searchInput

                anchors.left: parent.left
                anchors.leftMargin: 38
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                activeFocusOnTab: true
                onTextChanged: root.selectedIndex = 0
                Keys.onDownPressed: root.moveSelection(1)
                Keys.onUpPressed: root.moveSelection(-1)
                Keys.onReturnPressed: root.activateSelection()
                Keys.onEnterPressed: root.activateSelection()
                Keys.onSpacePressed: root.togglePreview()
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
                })
            }

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: clipboardList.width
                height: 44
                radius: Theme.radiusSmall
                color: index === root.selectedIndex ? Theme.primaryContainer : Theme.bg0
                border.width: index === root.selectedIndex ? 1 : 0
                border.color: Theme.primary

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
                    text: index === root.selectedIndex ? "↵ paste  ·  space view" : ""
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

        Rectangle {
            width: parent.width
            height: root.previewVisible ? 156 : 0
            radius: Theme.radiusSmall
            color: Theme.bg0
            border.width: 1
            border.color: Theme.bg2
            clip: true
            visible: height > 0

            ShellText {
                id: previewLabel

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 11
                anchors.topMargin: 9
                text: "Full content"
                color: Theme.primary
                font.pixelSize: 9
                font.weight: Font.Bold
            }

            ShellText {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 11
                anchors.topMargin: 9
                text: "space close"
                color: Theme.mutedDark
                font.pixelSize: 8
            }

            Flickable {
                id: previewViewport

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: previewLabel.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 11
                anchors.topMargin: 8
                contentWidth: width
                contentHeight: Math.max(height, previewText.implicitHeight)
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ShellText {
                    id: previewText

                    width: previewViewport.width
                    text: Backend.clipboardContentsLoading ? "Loading…" : Backend.clipboardContents
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Backend.clipboardContentsLoading ? Theme.muted : Theme.foreground
                    font.pixelSize: 10
                }

            }

            Behavior on height {
                NumberAnimation {
                    duration: Theme.animationFast
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

}
