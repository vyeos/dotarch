import QtQuick
import qs

Row {
    id: root

    property string title: ""

    signal closeRequested()

    height: 32
    spacing: 9

    IconButton {
        width: 30
        height: 30
        icon: "←"
        accessibleName: "Close " + root.title
        onClicked: root.closeRequested()
    }

    ShellText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        font.pixelSize: 14
        font.weight: Font.Bold
    }

}
