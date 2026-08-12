import QtQuick
import qs

Row {
    id: root

    property string title: ""
    property bool showCloseButton: true

    signal closeRequested()

    height: 32
    spacing: 9

    IconButton {
        width: 30
        height: 30
        visible: root.showCloseButton
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
