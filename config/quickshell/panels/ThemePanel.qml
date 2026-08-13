import QtQuick
import qs
import qs.components

FocusScope {
    id: root

    property int selectedIndex: 0

    function takeInitialFocus() {
        selectedIndex = Math.max(0, AppearanceState.themes.findIndex(theme => theme.slug === Theme.slug));
        const item = themeList.itemAtIndex(selectedIndex);
        if (item)
            item.forceActiveFocus(Qt.TabFocusReason);
    }

    function activate(index) {
        const theme = AppearanceState.themes[index];
        if (!theme)
            return;
        AppearanceState.applyTheme(theme.slug);
        ShellState.close();
    }

    function focusTheme(index) {
        const next = Math.max(0, Math.min(AppearanceState.themes.length - 1, index));
        const item = themeList.itemAtIndex(next);
        if (item)
            item.forceActiveFocus(Qt.TabFocusReason);
        themeList.positionViewAtIndex(next, GridView.Contain);
    }

    implicitWidth: 392
    implicitHeight: 402

    Column {
        anchors.fill: parent
        spacing: 10

        Row {
            width: parent.width
            height: 30

            ShellText {
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                text: "Desktop theme"
                font.pixelSize: 15
                font.weight: Font.Bold
            }
        }

        GridView {
            id: themeList
            width: parent.width
            height: parent.height - 40
            cellWidth: width / 2
            cellHeight: 58
            clip: true
            model: AppearanceState.themes

            delegate: FocusScope {
                id: themeRow
                required property int index
                required property var modelData
                width: themeList.cellWidth
                height: themeList.cellHeight
                activeFocusOnTab: true
                Keys.onReturnPressed: root.activate(index)
                Keys.onEnterPressed: root.activate(index)
                Keys.onSpacePressed: root.activate(index)
                Keys.onLeftPressed: root.focusTheme(index - 1)
                Keys.onRightPressed: root.focusTheme(index + 1)
                Keys.onDownPressed: root.focusTheme(index + 2)
                Keys.onUpPressed: root.focusTheme(index - 2)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: Theme.radiusSmall
                    color: themeRow.activeFocus ? Theme.bg1 : "transparent"
                    border.width: modelData.slug === Theme.slug ? 1 : 0
                    border.color: Theme.primary
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 7

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Repeater {
                            model: [themeRow.modelData.colors.primary, themeRow.modelData.colors.blue, themeRow.modelData.colors.purple]
                            Rectangle {
                                required property var modelData
                                width: 9
                                height: 28
                                radius: 4
                                color: modelData
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 62
                        spacing: 1
                        ShellText { width: parent.width; text: themeRow.modelData.name; elide: Text.ElideRight; font.weight: Font.DemiBold; font.pixelSize: 11 }
                        ShellText { text: themeRow.modelData.slug === Theme.slug ? "Active" : themeRow.modelData.appearance; color: Theme.mutedDark; font.pixelSize: 9 }
                    }

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: themeRow.modelData.slug === Theme.slug ? "󰄬" : ""
                        color: Theme.primary
                    }
                }

                MouseArea {
                    id: pointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activate(themeRow.index)
                }
            }
        }
    }
}
