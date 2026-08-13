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
            cellWidth: width / 3
            cellHeight: 90
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
                Keys.onDownPressed: root.focusTheme(index + 3)
                Keys.onUpPressed: root.focusTheme(index - 3)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: Theme.radius
                    color: themeRow.activeFocus ? modelData.colors.bg1 : modelData.colors.bg0
                    border.width: modelData.slug === Theme.slug ? 2 : 0
                    border.color: Theme.primary
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 5

                        Repeater {
                            model: [themeRow.modelData.colors.primary, themeRow.modelData.colors.blue, themeRow.modelData.colors.purple]

                            Rectangle {
                                required property var modelData
                                width: 25
                                height: 7
                                radius: height / 2
                                color: modelData
                            }
                        }
                    }

                    ShellText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: themeList.cellWidth - 20
                        horizontalAlignment: Text.AlignHCenter
                        text: themeRow.modelData.name
                        color: themeRow.modelData.colors.foreground
                        elide: Text.ElideRight
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
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
