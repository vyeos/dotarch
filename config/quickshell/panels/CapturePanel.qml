import QtQuick
import Quickshell.Services.Pipewire
import qs
import qs.components

FocusScope {
    id: root

    property string mode: "region"
    property bool recordingMode: false
    readonly property var source: Pipewire.defaultAudioSource
    readonly property color accent: recordingMode ? Theme.red : Theme.green
    readonly property var currentMode: {
        const modes = {
            "full": {
                "title": "Full screen",
                "shortTitle": "Display",
                "description": "Everything on this display"
            },
            "window": {
                "title": "Window",
                "shortTitle": "Window",
                "description": "Pick an open window"
            },
            "region": {
                "title": "Region",
                "shortTitle": "Area",
                "description": "Draw a frame on screen"
            }
        };
        return modes[mode];
    }

    function takeInitialFocus() {
        if (recordingMode) {
            recordControls.itemAt(0).forceActiveFocus(Qt.TabFocusReason);
            return;
        }
        const modes = ["full", "window", "region"];
        focusScreenshotMode(Math.max(0, modes.indexOf(mode)));
    }

    function focusScreenshotMode(index) {
        const count = screenshotModes.count;
        const next = (index + count) % count;
        const item = screenshotModes.itemAt(next);
        if (item) {
            mode = item.modelData.key;
            item.forceActiveFocus(Qt.TabFocusReason);
        }
    }

    implicitWidth: 367
    implicitHeight: content.implicitHeight

    PwObjectTracker {
        objects: [root.source]
    }

    Timer {
        id: captureDelay

        interval: Theme.animationNormal + 100
        onTriggered: Backend.capture(root.mode)
    }

    Shortcut {
        sequence: "Return"
        enabled: ShellState.panel === "capture"
        onActivated: captureButton.activate()
    }

    Shortcut {
        sequence: "Enter"
        enabled: ShellState.panel === "capture"
        onActivated: captureButton.activate()
    }

    Column {
        id: content

        width: parent.width
        spacing: 9

        Row {
            width: parent.width
            height: 30

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - captureKind.width
                spacing: 0

                ShellText {
                    text: "Capture"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                ShellText {
                    text: root.recordingMode ? (Backend.recording ? "Recording now" : "Screen recording") : "Screen capture"
                    color: root.recordingMode && Backend.recording ? Theme.red : Theme.mutedDark
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                }
            }

            Row {
                id: captureKind

                height: parent.height
                spacing: 2

                Repeater {
                    model: [{
                        "title": "Still",
                        "icon": "󰄀",
                        "recording": false
                    }, {
                        "title": "Record",
                        "icon": "󰑊",
                        "recording": true
                    }]

                    delegate: FocusScope {
                        id: kindButton

                        required property var modelData
                        readonly property bool selected: root.recordingMode === modelData.recording

                        width: 70
                        height: parent.height
                        activeFocusOnTab: true
                        Keys.onReturnPressed: root.recordingMode = modelData.recording
                        Keys.onEnterPressed: root.recordingMode = modelData.recording
                        Keys.onSpacePressed: root.recordingMode = modelData.recording
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.title

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSmall
                            color: kindPointer.containsMouse ? Theme.bg1 : "transparent"
                            border.width: kindButton.activeFocus ? 1 : 0
                            border.color: root.accent

                            Behavior on color {
                                ColorAnimation { duration: Theme.animationFast }
                            }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            ShellText {
                                text: kindButton.modelData.icon
                                color: kindButton.selected ? (kindButton.modelData.recording ? Theme.red : Theme.green) : Theme.mutedDark
                                font.pixelSize: 11
                            }

                            ShellText {
                                text: kindButton.modelData.title
                                color: kindButton.selected ? Theme.foreground : Theme.mutedDark
                                font.pixelSize: 9
                                font.weight: kindButton.selected ? Font.Bold : Font.Medium
                            }
                        }

                        MouseArea {
                            id: kindPointer

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.recordingMode = kindButton.modelData.recording
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: 118
            spacing: 8

            Rectangle {
                width: 105
                height: parent.height
                radius: Theme.radius
                color: Theme.bg0
                border.width: 1
                border.color: Qt.rgba(0.83, 0.78, 0.67, 0.06)

                Column {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 2
                    visible: !root.recordingMode

                    Repeater {
                        id: screenshotModes

                        model: [{
                            "key": "full",
                            "icon": "󰍹",
                            "title": "Display"
                        }, {
                            "key": "window",
                            "icon": "󰖲",
                            "title": "Window"
                        }, {
                            "key": "region",
                            "icon": "󰆞",
                            "title": "Area"
                        }]

                        delegate: FocusScope {
                            id: targetButton

                            required property var modelData
                            required property int index
                            readonly property bool selected: root.mode === modelData.key

                            width: parent.width
                            height: 34
                            activeFocusOnTab: true
                            Keys.onReturnPressed: root.focusScreenshotMode(index)
                            Keys.onEnterPressed: root.focusScreenshotMode(index)
                            Keys.onSpacePressed: root.focusScreenshotMode(index)
                            Keys.onUpPressed: root.focusScreenshotMode(index - 1)
                            Keys.onDownPressed: root.focusScreenshotMode(index + 1)
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.title

                            Rectangle {
                                anchors.fill: parent
                                radius: 5
                                color: targetButton.selected ? Theme.bgGreen : (targetPointer.containsMouse ? Theme.bg1 : "transparent")
                                border.width: targetButton.activeFocus ? 1 : 0
                                border.color: root.accent

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animationFast }
                                }
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 9
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                ShellText {
                                    width: 15
                                    text: targetButton.modelData.icon
                                    color: targetButton.selected ? root.accent : Theme.mutedDark
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                ShellText {
                                    text: targetButton.modelData.title
                                    color: targetButton.selected ? Theme.foreground : Theme.muted
                                    font.pixelSize: 9
                                    font.weight: targetButton.selected ? Font.DemiBold : Font.Medium
                                }
                            }

                            MouseArea {
                                id: targetPointer

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.focusScreenshotMode(targetButton.index)
                            }
                        }
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 2
                    visible: root.recordingMode

                    Repeater {
                        id: recordControls

                        model: [{
                            "key": "display",
                            "icon": "󰍹",
                            "title": "Display"
                        }, {
                            "key": "microphone",
                            "icon": root.source && root.source.audio && root.source.audio.muted ? "󰍭" : "󰍬",
                            "title": "Mic"
                        }]

                        delegate: FocusScope {
                            id: recordControl

                            required property var modelData
                            required property int index
                            readonly property bool microphone: modelData.key === "microphone"
                            readonly property bool enabledState: !microphone || (root.source && root.source.audio && !root.source.audio.muted)

                            width: parent.width
                            height: 51
                            activeFocusOnTab: true
                            Keys.onReturnPressed: activate()
                            Keys.onEnterPressed: activate()
                            Keys.onSpacePressed: activate()
                            Accessible.role: Accessible.Button
                            Accessible.name: microphone ? "Toggle microphone" : "Full display recording"

                            function activate() {
                                if (microphone && root.source && root.source.audio)
                                    root.source.audio.muted = !root.source.audio.muted;
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 5
                                color: recordPointer.containsMouse ? Theme.bg1 : "transparent"
                                border.width: recordControl.activeFocus ? 1 : 0
                                border.color: Theme.red
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                ShellText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: recordControl.modelData.icon
                                    color: recordControl.enabledState ? (recordControl.microphone ? Theme.green : Theme.red) : Theme.mutedDark
                                    font.pixelSize: 14
                                }

                                ShellText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: recordControl.modelData.title
                                    color: recordControl.enabledState ? Theme.foreground : Theme.mutedDark
                                    font.pixelSize: 8
                                    font.weight: Font.DemiBold
                                }
                            }

                            MouseArea {
                                id: recordPointer

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: recordControl.microphone ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: recordControl.activate()
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: viewfinder

                width: parent.width - 113
                height: parent.height
                radius: Theme.radius
                color: Theme.bg0
                border.width: 1
                border.color: Qt.rgba(0.83, 0.78, 0.67, 0.08)
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 9
                    border.color: Qt.rgba(0.12, 0.14, 0.15, 0.18)
                }

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10

                    ShellText {
                        width: parent.width / 2
                        text: root.recordingMode ? "Display" : root.currentMode.shortTitle
                        color: root.accent
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                    }

                    Row {
                        width: parent.width / 2
                        layoutDirection: Qt.RightToLeft
                        spacing: 5
                        visible: root.recordingMode && Backend.recording

                        ShellText {
                            text: "Recording"
                            color: Theme.red
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 5
                            height: 5
                            radius: 3
                            color: Theme.red
                        }
                    }
                }

                Rectangle {
                    id: displayFrame

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 31
                    width: parent.width - 46
                    height: 56
                    radius: 3
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.bg3

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.recordingMode || root.mode === "full" ? parent.width : (root.mode === "window" ? 126 : 111)
                        height: root.recordingMode || root.mode === "full" ? parent.height : (root.mode === "window" ? 48 : 38)
                        radius: root.mode === "window" && !root.recordingMode ? 4 : 1
                        color: root.recordingMode ? Qt.rgba(0.90, 0.49, 0.50, 0.08) : (root.mode === "window" ? Theme.bgGreen : Qt.rgba(0.65, 0.75, 0.50, 0.08))
                        border.width: 1
                        border.color: root.accent

                        Behavior on width {
                            NumberAnimation { duration: Theme.animationNormal; easing.type: Easing.OutCubic }
                        }

                        Behavior on height {
                            NumberAnimation { duration: Theme.animationNormal; easing.type: Easing.OutCubic }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 5
                            spacing: 3
                            visible: root.mode === "window" && !root.recordingMode

                            Repeater {
                                model: 3

                                Rectangle {
                                    width: 3
                                    height: 3
                                    radius: 2
                                    color: index === 0 ? Theme.red : Theme.mutedDark
                                }
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            radius: 9
                            color: Theme.red
                            visible: root.recordingMode

                            Rectangle {
                                anchors.centerIn: parent
                                width: 6
                                height: 6
                                radius: Backend.recording ? 1 : 3
                                color: Theme.bgDim
                            }
                        }

                        Repeater {
                            model: root.mode === "region" && !root.recordingMode ? 4 : 0

                            Rectangle {
                                required property int index

                                x: index % 2 === 0 ? -2 : parent.width - 2
                                y: index < 2 ? -2 : parent.height - 2
                                width: 4
                                height: 4
                                radius: 1
                                color: root.accent
                            }
                        }
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 11
                    anchors.rightMargin: 11
                    anchors.bottomMargin: 8

                    ShellText {
                        width: parent.width
                        text: root.recordingMode ? (root.source ? (root.source.description || "Default microphone") : "No microphone") : root.currentMode.description
                        color: Theme.muted
                        font.pixelSize: 8
                        elide: Text.ElideRight
                    }
                }
            }
        }

        FocusScope {
            id: captureButton

            function activate() {
                if (root.recordingMode) {
                    Backend.toggleRecording();
                } else {
                    ShellState.close();
                    captureDelay.restart();
                }
            }

            width: parent.width
            height: 42
            activeFocusOnTab: true
            Keys.onReturnPressed: activate()
            Keys.onEnterPressed: activate()
            Keys.onSpacePressed: activate()
            Accessible.role: Accessible.Button
            Accessible.name: root.recordingMode ? (Backend.recording ? "Stop recording" : "Start recording") : "Take screenshot"

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: actionPointer.containsMouse ? Theme.bg1 : Theme.bg0
                border.width: parent.activeFocus ? 1 : 0
                border.color: root.accent

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast }
                }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 10

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    text: root.recordingMode ? (Backend.recording ? "󰓛" : "󰑊") : "󰄀"
                    color: root.accent
                    font.pixelSize: 15
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 70
                    spacing: 0

                    ShellText {
                        text: root.recordingMode ? (Backend.recording ? "Stop recording" : "Start recording") : "Capture " + root.currentMode.title.toLowerCase()
                        color: Theme.foreground
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }

                    ShellText {
                        text: root.recordingMode ? "Full display · WebM" : "Saved to Pictures"
                        color: Theme.mutedDark
                        font.pixelSize: 7
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 22
                    radius: 5
                    color: Theme.bg1
                    border.width: 1
                    border.color: Theme.bg2

                    ShellText {
                        anchors.centerIn: parent
                        text: "↵"
                        color: Theme.muted
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }
            }

            MouseArea {
                id: actionPointer

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: captureButton.activate()
            }
        }

        ShellText {
            width: parent.width
            visible: Backend.lastError.length > 0 || Backend.lastCapture.length > 0
            text: Backend.lastError || Backend.lastCapture
            color: Backend.lastError ? Theme.red : Theme.muted
            elide: Text.ElideMiddle
            font.pixelSize: 8
        }
    }
}
