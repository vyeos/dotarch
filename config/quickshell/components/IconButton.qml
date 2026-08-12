import QtQuick
import qs

FocusScope {
    id: root

    property string icon: ""
    property string accessibleName: ""
    property color backgroundColor: Theme.bg0
    property color foregroundColor: Theme.foreground

    signal clicked()

    implicitWidth: 32
    implicitHeight: 32
    activeFocusOnTab: true
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.activeFocus || pointer.containsMouse ? Theme.bg1 : root.backgroundColor
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.green

        Behavior on color {
            ColorAnimation {
                duration: Theme.animationFast
            }

        }

    }

    ShellText {
        anchors.centerIn: parent
        text: root.icon
        color: root.foregroundColor
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

}
