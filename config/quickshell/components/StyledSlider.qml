import QtQuick
import qs

FocusScope {
    id: root

    property real value: 0
    property string icon: ""
    property string accessibleName: ""

    signal moved(real value)

    function setFromX(x) {
        const next = Math.max(0, Math.min(1, x / track.width));
        value = next;
        moved(next);
    }

    implicitHeight: 40
    activeFocusOnTab: true
    Keys.onLeftPressed: {
        value = Math.max(0, value - 0.05);
        moved(value);
    }
    Keys.onRightPressed: {
        value = Math.min(1, value + 0.05);
        moved(value);
    }
    Accessible.role: Accessible.Slider
    Accessible.name: accessibleName

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.bg0
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.green
    }

    Item {
        id: track

        anchors.fill: parent
        anchors.margins: 4

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(height, parent.width * root.value)
            radius: height / 2
            color: Theme.green
        }

        ShellText {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: Theme.bgDim
            font.weight: Font.Bold
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: (mouse) => {
                return root.setFromX(mouse.x);
            }
            onPositionChanged: (mouse) => {
                if (pressed)
                    root.setFromX(mouse.x);

            }
        }

    }

}
