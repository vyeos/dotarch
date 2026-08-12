import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

PanelWindow {
    id: root

    readonly property var visibleCandidates: Backend.windowCandidates.filter((candidate) => {
        if (!root.screen)
            return false;

        return candidate.x < root.screen.x + root.screen.width && candidate.x + candidate.width > root.screen.x && candidate.y < root.screen.y + root.screen.height && candidate.y + candidate.height > root.screen.y;
    })
    readonly property real regionLeft: Math.min(Backend.regionStartX, Backend.regionCurrentX)
    readonly property real regionTop: Math.min(Backend.regionStartY, Backend.regionCurrentY)
    readonly property real regionRight: Math.max(Backend.regionStartX, Backend.regionCurrentX)
    readonly property real regionBottom: Math.max(Backend.regionStartY, Backend.regionCurrentY)
    readonly property real regionWidth: regionRight - regionLeft
    readonly property real regionHeight: regionBottom - regionTop

    visible: Backend.captureSelectionActive
    color: "transparent"
    focusable: visible
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    FocusScope {
        id: selectionFocus

        anchors.fill: parent
        focus: root.visible
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                Backend.cancelCaptureSelection();
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            enabled: Backend.captureSelectionMode === "region"
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            preventStealing: true
            onPressed: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    Backend.cancelCaptureSelection();
                    return ;
                }
                Backend.beginRegionSelection(root.screen.x + mouse.x, root.screen.y + mouse.y);
            }
            onPositionChanged: (mouse) => Backend.updateRegionSelection(root.screen.x + mouse.x, root.screen.y + mouse.y)
            onReleased: (mouse) => Backend.finishRegionSelection(root.screen.x + mouse.x, root.screen.y + mouse.y)
            onCanceled: Backend.cancelCaptureSelection()
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            enabled: Backend.captureSelectionMode === "window"
            onClicked: Backend.cancelCaptureSelection()
        }

        Repeater {
            model: Backend.captureSelectionMode === "window" ? root.visibleCandidates : []

            delegate: Rectangle {
                id: candidateOutline

                required property var modelData
                readonly property real leftEdge: Math.max(modelData.x, root.screen.x)
                readonly property real topEdge: Math.max(modelData.y, root.screen.y)
                readonly property real rightEdge: Math.min(modelData.x + modelData.width, root.screen.x + root.screen.width)
                readonly property real bottomEdge: Math.min(modelData.y + modelData.height, root.screen.y + root.screen.height)

                x: leftEdge - root.screen.x
                y: topEdge - root.screen.y
                width: rightEdge - leftEdge
                height: bottomEdge - topEdge
                radius: modelData.rounded ? Theme.radius : 0
                color: pointer.containsMouse ? "#26a7c080" : "transparent"
                border.width: pointer.containsMouse ? 3 : 1
                border.color: pointer.containsMouse ? Theme.primary : Theme.mutedDark

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animationFast
                    }
                }

                MouseArea {
                    id: pointer

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Backend.captureWindow(candidateOutline.modelData)
                }

            }

        }

        Rectangle {
            id: regionOutline

            readonly property real leftEdge: Math.max(root.regionLeft, root.screen.x)
            readonly property real topEdge: Math.max(root.regionTop, root.screen.y)
            readonly property real rightEdge: Math.min(root.regionRight, root.screen.x + root.screen.width)
            readonly property real bottomEdge: Math.min(root.regionBottom, root.screen.y + root.screen.height)

            x: leftEdge - root.screen.x
            y: topEdge - root.screen.y
            width: Math.max(0, rightEdge - leftEdge)
            height: Math.max(0, bottomEdge - topEdge)
            visible: Backend.captureSelectionMode === "region" && Backend.regionSelectionDragging && width > 0 && height > 0
            radius: 2
            color: "#26a7c080"
            border.width: 2
            border.color: Theme.primary
        }

        Rectangle {
            id: regionDimensions

            readonly property bool pointerOnScreen: Backend.regionCurrentX >= root.screen.x && Backend.regionCurrentX < root.screen.x + root.screen.width && Backend.regionCurrentY >= root.screen.y && Backend.regionCurrentY < root.screen.y + root.screen.height

            x: Math.max(6, Math.min(root.width - width - 6, Backend.regionCurrentX - root.screen.x + 12))
            y: Math.max(6, Math.min(root.height - height - 6, Backend.regionCurrentY - root.screen.y + 12))
            width: dimensionsText.implicitWidth + 12
            height: 24
            visible: Backend.captureSelectionMode === "region" && Backend.regionSelectionDragging && pointerOnScreen && root.regionWidth > 0 && root.regionHeight > 0
            radius: Theme.radiusSmall
            color: Theme.bgDim
            border.width: 1
            border.color: Theme.primary

            ShellText {
                id: dimensionsText

                anchors.centerIn: parent
                text: Math.round(root.regionWidth) + " × " + Math.round(root.regionHeight)
                color: Theme.foreground
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

        }

    }

    Timer {
        interval: 1
        running: root.visible
        onTriggered: selectionFocus.forceActiveFocus(Qt.ActiveWindowFocusReason)
    }

}
