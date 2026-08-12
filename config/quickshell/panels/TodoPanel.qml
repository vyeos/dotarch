import QtQuick
import qs
import qs.components

FocusScope {
    id: root

    function takeInitialFocus() {
        todoInput.forceActiveFocus(Qt.TabFocusReason);
    }

    implicitWidth: 317
    implicitHeight: content.implicitHeight

    Column {
        id: content

        width: parent.width
        spacing: 8

        PanelHeader {
            title: "Todo"
            onCloseRequested: ShellState.close()
        }

        Row {
            width: parent.width
            height: 39
            spacing: 6

            Rectangle {
                width: parent.width - addButton.width - 6
                height: parent.height
                radius: Theme.radiusSmall
                color: Theme.bg0
                border.width: todoInput.activeFocus ? 2 : 1
                border.color: todoInput.activeFocus ? Theme.green : Theme.bg2

                TextInput {
                    id: todoInput

                    anchors.fill: parent
                    anchors.margins: 10
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    activeFocusOnTab: true
                    Keys.onReturnPressed: addButton.add()
                    Keys.onEnterPressed: addButton.add()

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Add a small thing…"
                        color: Theme.mutedDark
                        visible: !parent.text
                    }

                }

            }

            FocusScope {
                id: addButton

                function add() {
                    ShellState.addTodo(todoInput.text);
                    todoInput.clear();
                }

                width: 52
                height: parent.height
                activeFocusOnTab: true
                Keys.onReturnPressed: add()
                Keys.onEnterPressed: add()
                Keys.onSpacePressed: add()

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: Theme.green
                    border.width: parent.activeFocus ? 2 : 0
                    border.color: Theme.foreground
                }

                ShellText {
                    anchors.centerIn: parent
                    text: "Add"
                    color: Theme.bgDim
                    font.weight: Font.Bold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: addButton.add()
                }

            }

        }

        Column {
            width: parent.width
            spacing: 5

            Repeater {
                model: ShellState.todos

                delegate: FocusScope {
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 38
                    activeFocusOnTab: true
                    Keys.onReturnPressed: ShellState.toggleTodo(index)
                    Keys.onEnterPressed: ShellState.toggleTodo(index)
                    Keys.onSpacePressed: ShellState.toggleTodo(index)

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: Theme.bg0
                        opacity: modelData.done ? 0.62 : 1
                        border.width: parent.activeFocus ? 2 : 0
                        border.color: Theme.green
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 5
                        color: modelData.done ? Theme.green : "transparent"
                        border.width: 2
                        border.color: modelData.done ? Theme.green : Theme.mutedDark

                        ShellText {
                            anchors.centerIn: parent
                            text: modelData.done ? "✓" : ""
                            color: Theme.bgDim
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }

                    }

                    ShellText {
                        anchors.left: parent.left
                        anchors.leftMargin: 36
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text
                        color: modelData.done ? Theme.muted : Theme.foreground
                        font.strikeout: modelData.done
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.toggleTodo(index)
                    }

                }

            }

        }

    }

}
