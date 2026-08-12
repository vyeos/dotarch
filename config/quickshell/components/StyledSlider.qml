import QtQuick
import qs

FocusScope {
    id: root

    property real value: 0
    property real stepSize: 0
    property int stepCount: 0
    property bool filled: false
    property var levelLabels: []
    property string icon: ""
    property string accessibleName: ""

    signal moved(real value)

    function setFromX(x) {
        const trackX = filled ? filledTrack.x : rail.x;
        const trackWidth = filled ? filledTrack.width : rail.width;
        const rawValue = (x - trackX) / trackWidth;
        const boundedValue = Math.max(0, Math.min(1, rawValue));
        const next = stepSize > 0 ? Math.max(0, Math.min(1, Math.round(boundedValue / stepSize) * stepSize)) : boundedValue;
        moved(next);
    }

    implicitHeight: 40
    activeFocusOnTab: true
    Keys.onLeftPressed: {
        moved(Math.max(0, value - (stepSize > 0 ? stepSize : 0.05)));
    }
    Keys.onRightPressed: {
        moved(Math.min(1, value + (stepSize > 0 ? stepSize : 0.05)));
    }
    Accessible.role: Accessible.Slider
    Accessible.name: accessibleName

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.filled ? Theme.bg2 : Theme.bg0
        border.width: root.filled ? (root.activeFocus ? 2 : 0) : 1
        border.color: root.activeFocus ? Theme.primary : Theme.bg2

        Behavior on border.color {
            ColorAnimation { duration: Theme.animationFast }
        }
    }

    ShellText {
        z: 1
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: root.filled ? Theme.bgDim : (root.enabled ? Theme.muted : Theme.mutedDark)
        font.pixelSize: 14
        font.weight: Font.Bold
    }

    Rectangle {
        id: rail

        anchors.left: parent.left
        anchors.leftMargin: 46
        anchors.right: parent.right
        anchors.rightMargin: 15
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: height / 2
        color: Theme.bg3
        visible: !root.filled

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1, root.value))
            radius: height / 2
            color: Theme.primary
        }

        Repeater {
            model: root.stepCount

            delegate: Rectangle {
                required property int index

                x: root.stepCount > 1 ? (rail.width - width) * index / (root.stepCount - 1) : 0
                anchors.verticalCenter: parent.verticalCenter
                width: 4
                height: 4
                radius: 2
                color: index / Math.max(1, root.stepCount - 1) <= root.value ? Theme.primary : Theme.bg4
            }
        }
    }

    Rectangle {
        x: rail.x + rail.width * Math.max(0, Math.min(1, root.value)) - width / 2
        anchors.verticalCenter: rail.verticalCenter
        width: 14
        height: 14
        radius: width / 2
        color: Theme.primary
        border.width: 3
        border.color: Theme.bg0
        visible: !root.filled

        Behavior on x {
            enabled: !pointer.pressed
            NumberAnimation {
                duration: Theme.animationFast
                easing.type: Easing.OutCubic
            }
        }
    }

    Item {
        id: filledTrack

        anchors.fill: parent
        anchors.margins: 4
        visible: root.filled

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.levelLabels.length > 0 && root.value <= 0 ? 0 : Math.max(height, parent.width * Math.max(0, Math.min(1, root.value)))
            radius: height / 2
            color: Theme.primary
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => root.setFromX(mouse.x)
        onPositionChanged: (mouse) => {
            if (pressed)
                root.setFromX(mouse.x);
        }
    }

    Repeater {
        model: root.levelLabels

        delegate: Item {
            required property int index
            required property var modelData

            z: 2
            x: {
                if (index === 0)
                    return 8;
                if (index === root.levelLabels.length - 1)
                    return root.width - width - 8;
                return root.width * index / (root.levelLabels.length - 1) - width / 2;
            }
            width: 32
            height: root.height

            ShellText {
                anchors.centerIn: parent
                text: parent.modelData
                color: {
                    const target = parent.index / Math.max(1, root.levelLabels.length - 1);
                    if (root.value > 0 && target <= root.value)
                        return Theme.bgDim;
                    return target === root.value ? Theme.foreground : Theme.muted;
                }
                font.pixelSize: 11
                font.weight: Font.Bold
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.moved(parent.index / Math.max(1, root.levelLabels.length - 1))
            }
        }
    }
}
