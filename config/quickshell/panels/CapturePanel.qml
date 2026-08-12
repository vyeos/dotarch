import QtQuick
import Quickshell.Services.Pipewire
import qs
import qs.components

FocusScope {
    id: root

    property string mode: "region"
    property bool recordingMode: false
    readonly property var source: Pipewire.defaultAudioSource

    implicitWidth: 367
    implicitHeight: content.implicitHeight

    PwObjectTracker {
        objects: [root.source]
    }

    Timer {
        id: captureDelay

        interval: 260
        onTriggered: Backend.capture(root.mode)
    }

    Column {
        id: content

        width: parent.width
        spacing: 8

        PanelHeader {
            title: "Capture"
            onCloseRequested: ShellState.close()
        }

        Row {
            width: parent.width
            height: 37
            spacing: 4

            Repeater {
                model: [{
                    "title": "Screenshot",
                    "recording": false
                }, {
                    "title": "Screen recording",
                    "recording": true
                }]

                delegate: FocusScope {
                    required property var modelData

                    width: (parent.width - 4) / 2
                    height: parent.height
                    activeFocusOnTab: true
                    Keys.onReturnPressed: root.recordingMode = modelData.recording
                    Keys.onEnterPressed: root.recordingMode = modelData.recording
                    Keys.onSpacePressed: root.recordingMode = modelData.recording

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: root.recordingMode === modelData.recording ? Theme.green : Theme.bg0
                        border.width: parent.activeFocus ? 2 : 0
                        border.color: Theme.foreground
                    }

                    ShellText {
                        anchors.centerIn: parent
                        text: modelData.title
                        color: root.recordingMode === modelData.recording ? Theme.bgDim : Theme.muted
                        font.weight: Font.DemiBold
                        font.pixelSize: 10
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.recordingMode = modelData.recording
                    }

                }

            }

        }

        Row {
            width: parent.width
            height: 66
            spacing: 6
            visible: !root.recordingMode

            Repeater {
                model: [{
                    "key": "full",
                    "icon": "󰍹",
                    "title": "Full screen"
                }, {
                    "key": "window",
                    "icon": "󰖲",
                    "title": "Window"
                }, {
                    "key": "region",
                    "icon": "󰆞",
                    "title": "Region"
                }]

                delegate: ActionTile {
                    required property var modelData

                    width: (parent.width - 12) / 3
                    height: parent.height
                    icon: modelData.icon
                    title: modelData.title
                    subtitle: ""
                    active: root.mode === modelData.key
                    onClicked: root.mode = modelData.key
                }

            }

        }

        Rectangle {
            width: parent.width
            height: root.recordingMode ? 46 : 0
            radius: Theme.radiusSmall
            color: Theme.bg0
            visible: root.recordingMode

            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                IconButton {
                    width: 30
                    height: 30
                    icon: root.source && root.source.audio && root.source.audio.muted ? "󰍭" : "󰍬"
                    accessibleName: "Toggle microphone"
                    onClicked: {
                        if (root.source && root.source.audio)
                            root.source.audio.muted = !root.source.audio.muted;

                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 38
                    spacing: 1

                    ShellText {
                        text: "Microphone"
                        font.weight: Font.DemiBold
                    }

                    ShellText {
                        width: parent.width
                        text: root.source ? (root.source.description || "Default source") : "No source"
                        color: Theme.muted
                        font.pixelSize: 9
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
            height: 40
            activeFocusOnTab: true
            Keys.onReturnPressed: activate()
            Keys.onEnterPressed: activate()
            Keys.onSpacePressed: activate()

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: root.recordingMode && Backend.recording ? Theme.red : Theme.green
                border.width: parent.activeFocus ? 2 : 0
                border.color: Theme.foreground
            }

            ShellText {
                anchors.centerIn: parent
                text: root.recordingMode ? (Backend.recording ? "Stop recording" : "Start recording") : "Take screenshot"
                color: Theme.bgDim
                font.weight: Font.Bold
            }

            MouseArea {
                anchors.fill: parent
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
