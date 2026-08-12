import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.components
import qs.panels

PanelWindow {
    id: window

    readonly property int contentPadding: 14
    readonly property int collapsedHeight: 36
    readonly property int cornerWing: 16
    readonly property int canvasWidth: 552
    readonly property int canvasHeight: 600
    readonly property int requestedBottomPadding: contentPadding
    readonly property int displayedBottomPadding: contentPadding
    readonly property real targetVisualWidth: ShellState.targetWidth + cornerWing * 2
    readonly property real targetVisualHeight: ShellState.expanded ? panelContentHeight + contentPadding + requestedBottomPadding : collapsedHeight
    readonly property real panelContentHeight: ShellState.expanded ? Math.max(ShellState.panelHeights[ShellState.panel] || 0, requestedPanel ? requestedPanel.implicitHeight : 0) : 0
    readonly property real batteryLevel: UPower.displayDevice ? UPower.displayDevice.percentage : 0
    readonly property bool batteryCharging: UPower.displayDevice && (!UPower.onBattery || UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.PendingCharge)
    property bool contentRevealed: false
    property bool clockRevealed: true
    property string displayedPanel: "control"
    readonly property Item activePanel: {
        const panels = {
            "control": controlPanel,
            "launcher": launcherPanel,
            "clipboard": clipboardPanel,
            "todo": todoPanel,
            "capture": capturePanel,
            "power": powerPanel
        };
        return panels[displayedPanel] || null;
    }
    readonly property Item requestedPanel: {
        const panels = {
            "control": controlPanel,
            "launcher": launcherPanel,
            "clipboard": clipboardPanel,
            "todo": todoPanel,
            "capture": capturePanel,
            "power": powerPanel
        };
        return panels[ShellState.panel] || null;
    }

    function focusInitialControl() {
        if (!ShellState.expanded || !activePanel)
            return ;

        if (typeof activePanel.takeInitialFocus === "function") {
            activePanel.takeInitialFocus();
            return ;
        }
        activePanel.forceActiveFocus(Qt.TabFocusReason);
        const firstControl = activePanel.nextItemInFocusChain(true);
        if (firstControl && firstControl !== activePanel)
            firstControl.forceActiveFocus(Qt.TabFocusReason);

    }

    function moveFocus(forward) {
        const current = window.activeFocusItem;
        if (!current) {
            focusInitialControl();
            return ;
        }
        const target = current.nextItemInFocusChain(forward);
        if (target)
            target.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);

    }

    margins.left: Math.round((screen.width - canvasWidth) / 2)
    implicitWidth: canvasWidth
    implicitHeight: canvasHeight
    color: "transparent"
    aboveWindows: true
    focusable: ShellState.expanded
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left: true
    }

    Connections {
        function onPanelChanged() {
            window.contentRevealed = ShellState.expanded;
            if (ShellState.expanded) {
                clockRevealTimer.stop();
                window.clockRevealed = false;
                window.displayedPanel = ShellState.panel;
                focusTimer.restart();
            } else {
                clockRevealTimer.restart();
            }
        }

        target: ShellState
    }

    FocusScope {
        id: notchSurface

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: window.targetVisualWidth
        height: window.targetVisualHeight
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                ShellState.close();
                event.accepted = true;
                return ;
            }
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                window.moveFocus(true);
                event.accepted = true;
                return ;
            }
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                window.moveFocus(false);
                event.accepted = true;
                return ;
            }
        }

        Rectangle {
            id: notchBody

            x: window.cornerWing
            y: -15
            width: parent.width - window.cornerWing * 2
            height: parent.height + 15
            radius: 15
            color: Theme.bgDim
        }

        Shape {
            x: 0
            width: window.cornerWing
            height: window.cornerWing
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                id: leftShoulderPath

                readonly property real size: window.cornerWing

                strokeWidth: 0
                fillColor: Theme.bgDim
                startX: 0
                startY: 0

                PathLine {
                    x: leftShoulderPath.size
                    y: 0
                }

                PathLine {
                    x: leftShoulderPath.size
                    y: leftShoulderPath.size
                }

                PathCubic {
                    control1X: leftShoulderPath.size
                    control1Y: leftShoulderPath.size * 0.448
                    control2X: leftShoulderPath.size * 0.552
                    control2Y: 0
                    x: 0
                    y: 0
                }

            }

        }

        Shape {
            x: parent.width - width
            width: window.cornerWing
            height: window.cornerWing
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                id: rightShoulderPath

                readonly property real size: window.cornerWing

                strokeWidth: 0
                fillColor: Theme.bgDim
                startX: rightShoulderPath.size
                startY: 0

                PathLine {
                    x: 0
                    y: 0
                }

                PathLine {
                    x: 0
                    y: rightShoulderPath.size
                }

                PathCubic {
                    control1X: 0
                    control1Y: rightShoulderPath.size * 0.448
                    control2X: rightShoulderPath.size * 0.448
                    control2Y: 0
                    x: rightShoulderPath.size
                    y: 0
                }

            }

        }

        Row {
            anchors.left: notchBody.left
            anchors.right: notchBody.right
            anchors.top: parent.top
            height: window.collapsedHeight
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            visible: opacity > 0
            opacity: window.clockRevealed ? 1 : 0

            ShellText {
                width: parent.width / 3
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: (window.batteryCharging ? "" : "󰁹") + " " + Math.round(window.batteryLevel * 100) + "%"
                color: window.batteryLevel < 0.2 ? Theme.red : Theme.green
                font.pixelSize: 11
            }

            ShellText {
                width: parent.width / 3
                height: parent.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            ShellText {
                width: parent.width / 3
                height: parent.height
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"][clock.date.getDay()] + " " + Qt.formatDateTime(clock.date, "d/M")
                color: Theme.foreground
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 90
                    easing.type: Easing.OutCubic
                }

            }

        }

        MouseArea {
            anchors.fill: parent
            enabled: !ShellState.expanded
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ShellState.show("control")
        }

        Item {
            id: panelHost

            anchors.left: notchBody.left
            anchors.right: notchBody.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: window.contentPadding
            anchors.rightMargin: window.contentPadding
            anchors.topMargin: window.contentPadding
            anchors.bottomMargin: window.displayedBottomPadding
            visible: opacity > 0
            opacity: window.contentRevealed ? 1 : 0
            clip: true

            ControlPanel {
                id: controlPanel

                width: parent.width
                visible: window.displayedPanel === "control"
            }

            LauncherPanel {
                id: launcherPanel

                width: parent.width
                visible: window.displayedPanel === "launcher"
            }

            ClipboardPanel {
                id: clipboardPanel

                width: parent.width
                visible: window.displayedPanel === "clipboard"
            }

            TodoPanel {
                id: todoPanel

                width: parent.width
                visible: window.displayedPanel === "todo"
            }

            CapturePanel {
                id: capturePanel

                width: parent.width
                visible: window.displayedPanel === "capture"
            }

            PowerPanel {
                id: powerPanel

                width: parent.width
                visible: window.displayedPanel === "power"
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animationNormal
                    easing.type: Easing.OutCubic
                }

            }

        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.animationNormal
                easing.type: Easing.OutCubic
            }

        }

        Behavior on height {
            enabled: !clipboardPanel.previewTransitionActive

            NumberAnimation {
                duration: Theme.animationNormal
                easing.type: Easing.OutCubic
            }

        }

    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    HyprlandFocusGrab {
        windows: [window]
        active: ShellState.expanded
        onCleared: {
            if (ShellState.expanded)
                ShellState.close();

        }
    }

    Timer {
        id: focusTimer

        interval: 35
        onTriggered: window.focusInitialControl()
    }

    Timer {
        id: clockRevealTimer

        interval: 150
        onTriggered: {
            if (!ShellState.expanded)
                window.clockRevealed = true;

        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: ShellState.expanded
        onActivated: ShellState.close()
    }

    mask: Region {
        item: notchBody
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 15
        bottomRightRadius: 15
    }

}
