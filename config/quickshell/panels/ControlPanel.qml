import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.components

FocusScope {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var connectedDevices: adapter ? adapter.devices.values.filter((device) => {
        return device.connected;
    }) : []

    function formatDuration(seconds) {
        if (!Number.isFinite(seconds) || seconds < 0)
            return "0:00";

        const minutes = Math.floor(seconds / 60);
        return minutes + ":" + String(Math.floor(seconds % 60)).padStart(2, "0");
    }

    implicitWidth: 492
    implicitHeight: content.implicitHeight

    PwObjectTracker {
        objects: [root.sink]
    }

    Timer {
        interval: 1000
        running: root.player && root.player.isPlaying
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Column {
        id: content

        width: parent.width
        spacing: 8

        PanelHeader {
            title: "Control Center"
            onCloseRequested: ShellState.close()
        }

        Row {
            width: parent.width
            height: 58
            spacing: 7

            ActionTile {
                width: (parent.width - 14) / 3
                icon: "󰤨"
                title: "Wi-Fi"
                subtitle: Backend.wifiName
                active: Backend.wifiEnabled
                onClicked: Backend.toggleWifi()
            }

            ActionTile {
                width: (parent.width - 14) / 3
                icon: root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾"
                title: "Audio"
                subtitle: root.sink ? (root.sink.description || root.sink.nickname || "Default output") : "No output"
                active: root.sink && root.sink.audio && !root.sink.audio.muted
                onClicked: {
                    if (root.sink && root.sink.audio)
                        root.sink.audio.muted = !root.sink.audio.muted;

                }
            }

            ActionTile {
                width: (parent.width - 14) / 3
                icon: "󰂯"
                title: "Bluetooth"
                subtitle: root.connectedDevices.length > 0 ? root.connectedDevices[0].name : (root.adapter && root.adapter.enabled ? "On" : "Off")
                active: root.adapter && root.adapter.enabled
                onClicked: {
                    if (root.adapter)
                        root.adapter.enabled = !root.adapter.enabled;

                }
            }

        }

        StyledSlider {
            id: volumeSlider

            width: parent.width
            icon: root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾"
            accessibleName: "Volume"
            value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
            onMoved: (value) => {
                if (root.sink && root.sink.audio) {
                    root.sink.audio.volume = value;
                    root.sink.audio.muted = false;
                }
            }
        }

        StyledSlider {
            width: parent.width
            icon: "󰃠"
            accessibleName: "Brightness"
            value: Backend.brightness / 100
            onMoved: (value) => {
                return Backend.setBrightness(value * 100);
            }
        }

        Rectangle {
            width: parent.width
            height: 118
            radius: Theme.radius
            clip: true

            Image {
                anchors.fill: parent
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                opacity: status === Image.Ready ? 0.26 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animationNormal
                    }

                }

            }

            Column {
                anchors.left: parent.left
                anchors.right: controls.left
                anchors.top: parent.top
                anchors.bottom: progress.top
                anchors.margins: 12
                spacing: 3

                ShellText {
                    text: root.sink ? "󰕾  " + (root.sink.description || "Default output") : "󰝟  No audio output"
                    color: Theme.muted
                    font.pixelSize: 9
                    elide: Text.ElideRight
                    width: parent.width
                }

                Item {
                    width: 1
                    height: 5
                }

                ShellText {
                    width: parent.width
                    text: root.player ? (root.player.trackTitle || "Unknown title") : "Nothing playing"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                ShellText {
                    width: parent.width
                    text: root.player ? (root.player.trackArtist || root.player.identity || "Unknown artist") : "Open a media player to begin"
                    color: Theme.muted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

            }

            Row {
                id: controls

                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                IconButton {
                    width: 28
                    height: 28
                    icon: "󰒮"
                    accessibleName: "Previous track"
                    onClicked: {
                        if (root.player && root.player.canGoPrevious)
                            root.player.previous();

                    }
                }

                IconButton {
                    width: 42
                    height: 42
                    icon: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                    accessibleName: root.player && root.player.isPlaying ? "Pause" : "Play"
                    backgroundColor: Theme.foreground
                    foregroundColor: Theme.bgDim
                    onClicked: {
                        if (root.player && root.player.canTogglePlaying)
                            root.player.togglePlaying();

                    }
                }

                IconButton {
                    width: 28
                    height: 28
                    icon: "󰒭"
                    accessibleName: "Next track"
                    onClicked: {
                        if (root.player && root.player.canGoNext)
                            root.player.next();

                    }
                }

            }

            Row {
                id: progress

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                height: 12
                spacing: 8

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.player ? root.formatDuration(root.player.position) : "0:00"
                    color: Theme.muted
                    font.pixelSize: 8
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 68
                    height: 3
                    radius: 2
                    color: Qt.rgba(0.83, 0.78, 0.67, 0.25)

                    Rectangle {
                        width: parent.width * (root.player && root.player.length > 0 ? Math.min(1, root.player.position / root.player.length) : 0)
                        height: parent.height
                        radius: parent.radius
                        color: Theme.foreground
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.player && root.player.positionSupported && root.player.length > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onPressed: (mouse) => {
                            root.player.position = root.player.length * mouse.x / width;
                        }
                    }

                }

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.player ? root.formatDuration(root.player.length) : "0:00"
                    color: Theme.muted
                    font.pixelSize: 8
                }

            }

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: Theme.bgGreen
                }

                GradientStop {
                    position: 1
                    color: Theme.bgYellow
                }

            }

        }

        Row {
            width: parent.width
            height: 31
            spacing: 6

            ShellText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - trayRepeater.count * 31 - (quietState.visible ? quietState.width : 0)
                text: "Long-running apps"
                color: Theme.muted
                font.pixelSize: 10
            }

            Row {
                id: quietState

                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                visible: trayRepeater.count === 0

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.green
                }

                ShellText {
                    text: "all quiet"
                    color: Theme.mutedDark
                    font.pixelSize: 9
                }

            }

            Repeater {
                id: trayRepeater

                model: SystemTray.items

                delegate: IconButton {
                    required property var modelData

                    width: 26
                    height: 26
                    accessibleName: modelData.title || modelData.id
                    onClicked: modelData.activate()

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 16
                        source: modelData.icon
                    }

                }

            }

        }

    }

}
