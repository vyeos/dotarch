import "../Expression.js" as Expression
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.components

FocusScope {
    id: root

    property int selectedIndex: 0
    readonly property var answer: Expression.evaluate(searchInput.text)
    readonly property bool hasAnswer: answer !== null

    function takeInitialFocus() {
        searchInput.forceActiveFocus(Qt.TabFocusReason);
    }

    function moveSelection(offset) {
        const count = filteredApps.values.length;
        if (count === 0) {
            selectedIndex = 0;
            return ;
        }

        selectedIndex = Math.max(0, Math.min(count - 1, selectedIndex + offset));
        results.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function resetSelection() {
        selectedIndex = 0;
        Qt.callLater(() => results.positionViewAtBeginning());
    }

    Connections {
        function onPanelChanged() {
            if (ShellState.panel !== "launcher") {
                searchInput.clear();
                root.resetSelection();
            }
        }

        target: ShellState
    }

    function activateSelection() {
        if (hasAnswer) {
            Quickshell.clipboardText = String(answer);
            copiedLabel.opacity = 1;
            copiedTimer.restart();
            return ;
        }
        const values = filteredApps.values;
        if (values.length > 0) {
            values[Math.max(0, Math.min(selectedIndex, values.length - 1))].execute();
            ShellState.close();
        }
    }

    implicitWidth: 382
    implicitHeight: content.implicitHeight

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
                onTextChanged: root.resetSelection()
                Keys.onDownPressed: root.moveSelection(1)
                Keys.onUpPressed: root.moveSelection(-1)
                Keys.onReturnPressed: root.activateSelection()
                Keys.onEnterPressed: root.activateSelection()
                Keys.onEscapePressed: ShellState.close()

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search apps or calculate…"
                    color: Theme.mutedDark
                    visible: !parent.text
                }

            }

        }

        Rectangle {
            width: parent.width
            height: root.hasAnswer ? 64 : 0
            radius: Theme.radiusSmall
            color: Theme.bgGreen
            opacity: root.hasAnswer ? 1 : 0
            clip: true

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                ShellText {
                    text: String(searchInput.text).replace(/\*/g, "×").replace(/\//g, "÷")
                    color: Theme.muted
                    font.pixelSize: 9
                }

                ShellText {
                    text: root.hasAnswer ? String(root.answer) : ""
                    color: Theme.green
                    font.pixelSize: 24
                    font.weight: Font.Bold
                }

            }

            ShellText {
                id: copiedLabel

                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                text: "Copied"
                color: Theme.green
                opacity: 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animationFast
                    }

                }

            }

            Timer {
                id: copiedTimer

                interval: 1200
                onTriggered: copiedLabel.opacity = 0
            }

            Behavior on height {
                NumberAnimation {
                    duration: Theme.animationFast
                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animationFast
                }

            }

        }

        ListView {
            id: results

            width: parent.width
            height: Math.min(5, count) * 48
            spacing: 4
            clip: true
            interactive: contentHeight > height

            model: ScriptModel {
                id: filteredApps

                values: DesktopEntries.applications.values.filter((entry) => {
                    if (entry.noDisplay)
                        return false;

                    const query = searchInput.text.toLowerCase();
                    const name = String(entry.name || "").toLowerCase();
                    const genericName = String(entry.genericName || "").toLowerCase();
                    const keywords = entry.keywords ? entry.keywords.join(" ").toLowerCase() : "";
                    return !query || name.includes(query) || genericName.includes(query) || keywords.includes(query);
                }).sort((left, right) => {
                    const leftName = String(left.name || "").toLowerCase();
                    const rightName = String(right.name || "").toLowerCase();
                    if (leftName < rightName)
                        return -1;

                    if (leftName > rightName)
                        return 1;

                    return String(left.name || "").localeCompare(String(right.name || ""));
                })
            }

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: results.width
                height: 44
                radius: Theme.radiusSmall
                color: index === root.selectedIndex && !root.hasAnswer ? Theme.bg1 : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 9

                    Rectangle {
                        width: 32
                        height: 32
                        color: "transparent"

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 20
                            source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                        }

                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 48
                        spacing: 1

                        ShellText {
                            width: parent.width
                            text: modelData.name
                            elide: Text.ElideRight
                            font.weight: Font.DemiBold
                        }

                        ShellText {
                            width: parent.width
                            text: modelData.genericName || modelData.comment || "Application"
                            elide: Text.ElideRight
                            color: Theme.muted
                            font.pixelSize: 9
                        }

                    }

                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = index
                    onClicked: {
                        modelData.execute();
                        ShellState.close();
                    }
                }

            }

        }

    }

}
