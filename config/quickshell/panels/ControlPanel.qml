import QtQuick
import QtQuick.Effects
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
    readonly property var audioSinks: Pipewire.nodes.values.filter((node) => {
        return node.isSink && !node.isStream && node.audio;
    })
    readonly property var bluetoothDevices: adapter ? adapter.devices.values.filter((device) => {
        return device.name || device.deviceName;
    }).slice().sort((left, right) => {
        if (left.connected !== right.connected)
            return left.connected ? -1 : 1;

        if (left.paired !== right.paired)
            return left.paired ? -1 : 1;

        return (left.name || left.deviceName).localeCompare(right.name || right.deviceName);
    }) : []
    readonly property var connectedDevices: adapter ? adapter.devices.values.filter((device) => {
        return device.connected;
    }) : []
    property string expandedSection: ""
    property string displayedSection: ""
    property var pendingWifiNetwork: null

    function toggleSection(section) {
        const nextSection = expandedSection === section ? "" : section;
        if (expandedSection === "bluetooth" && nextSection !== "bluetooth")
            stopBluetoothDiscovery();

        expandedSection = nextSection;
        if (nextSection) {
            sectionCloseTimer.stop();
            displayedSection = nextSection;
        } else {
            sectionCloseTimer.restart();
        }
        pendingWifiNetwork = null;
        if (nextSection === "wifi")
            Backend.scanWifi();
        else if (nextSection === "bluetooth")
            startBluetoothDiscovery();
    }

    function startBluetoothDiscovery() {
        if (!adapter || !adapter.enabled)
            return ;

        adapter.discovering = true;
        bluetoothScanTimer.restart();
    }

    function stopBluetoothDiscovery() {
        bluetoothScanTimer.stop();
        if (adapter && adapter.discovering)
            adapter.discovering = false;

    }

    function selectWifi(network) {
        if (Backend.wifiConnecting)
            return ;

        if (network.connected) {
            Backend.disconnectWifi();
            return ;
        }
        if (network.security !== "open" && !network.known) {
            pendingWifiNetwork = network;
            Qt.callLater(() => {
                return wifiPasswordInput.forceActiveFocus(Qt.TabFocusReason);
            });
            return ;
        }
        Backend.connectWifi(network.name, "");
    }

    function connectPendingWifi() {
        if (!pendingWifiNetwork || !wifiPasswordInput.text)
            return ;

        Backend.connectWifi(pendingWifiNetwork.name, wifiPasswordInput.text);
        wifiPasswordInput.clear();
        pendingWifiNetwork = null;
    }

    function activateBluetoothDevice(device) {
        if (device.connected) {
            device.disconnect();
        } else if (device.paired || device.bonded) {
            device.connect();
        } else {
            device.trusted = true;
            device.pair();
        }
    }

    function bluetoothIcon(device) {
        const iconName = (device.icon || "").toLowerCase();
        if (iconName.indexOf("head") >= 0 || iconName.indexOf("audio") >= 0)
            return "󰋋";

        if (iconName.indexOf("mouse") >= 0)
            return "󰍽";

        if (iconName.indexOf("keyboard") >= 0)
            return "󰌌";

        return "󰂯";
    }

    function wifiSignalDbm(signal) {
        const value = Number(signal);
        if (!Number.isFinite(value))
            return null;

        return Math.round(value < -200 ? value / 100 : value);
    }

    function wifiSignalIcon(signal) {
        const dbm = wifiSignalDbm(signal);
        if (dbm === null)
            return "󰤯";

        if (dbm >= -55)
            return "󰤨";

        if (dbm >= -70)
            return "󰤢";

        return "󰤟";
    }

    function formatDuration(seconds) {
        if (!Number.isFinite(seconds) || seconds < 0)
            return "0:00";

        const minutes = Math.floor(seconds / 60);
        return minutes + ":" + String(Math.floor(seconds % 60)).padStart(2, "0");
    }

    implicitWidth: 492
    readonly property real collapsedImplicitHeight: content.implicitHeight - devicePicker.height - (devicePicker.visible ? content.spacing : 0)
    implicitHeight: collapsedImplicitHeight + (root.expandedSection ? devicePicker.expandedHeight + content.spacing : 0)

    PwObjectTracker {
        objects: root.audioSinks
    }

    Timer {
        id: bluetoothScanTimer

        interval: 12000
        onTriggered: root.stopBluetoothDiscovery()
    }

    Timer {
        id: sectionCloseTimer

        interval: Theme.animationNormal
        onTriggered: {
            if (!root.expandedSection)
                root.displayedSection = "";
        }
    }

    Connections {
        function onEnabledChanged() {
            if (root.adapter && root.adapter.enabled && root.expandedSection === "bluetooth")
                root.startBluetoothDiscovery();

        }

        target: root.adapter
    }

    Connections {
        function onPanelChanged() {
            if (ShellState.panel !== "control")
                root.stopBluetoothDiscovery();
            else if (root.expandedSection === "bluetooth")
                root.startBluetoothDiscovery();
        }

        target: ShellState
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
            showCloseButton: false
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
                expandable: true
                expanded: root.expandedSection === "wifi"
                onClicked: root.toggleSection("wifi")
            }

            ActionTile {
                width: (parent.width - 14) / 3
                icon: root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾"
                title: "Audio"
                subtitle: root.sink ? (root.sink.description || root.sink.nickname || "Default output") : "No output"
                active: root.sink && root.sink.audio && !root.sink.audio.muted
                expandable: true
                expanded: root.expandedSection === "audio"
                onClicked: {
                    root.toggleSection("audio");
                }
            }

            ActionTile {
                width: (parent.width - 14) / 3
                icon: "󰂯"
                title: "Bluetooth"
                subtitle: root.connectedDevices.length > 0 ? root.connectedDevices[0].name : (root.adapter && root.adapter.enabled ? "On" : "Off")
                active: root.adapter && root.adapter.enabled
                expandable: true
                expanded: root.expandedSection === "bluetooth"
                onClicked: {
                    root.toggleSection("bluetooth");
                }
            }

        }

        Rectangle {
            id: devicePicker

            readonly property int expandedHeight: 204

            width: parent.width
            height: root.expandedSection ? expandedHeight : 0
            radius: Theme.radius
            color: Theme.bg0
            clip: true
            enabled: root.expandedSection !== ""
            visible: height > 0
            opacity: root.expandedSection ? 1 : 0

            Item {
                id: pickerHeader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                height: 30

                Column {
                    anchors.left: parent.left
                    anchors.right: powerButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    ShellText {
                        width: parent.width
                        text: root.displayedSection === "wifi" ? "Wi-Fi networks" : (root.displayedSection === "audio" ? "Sound output" : "Bluetooth devices")
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }

                    ShellText {
                        width: parent.width
                        text: {
                            if (root.displayedSection === "wifi")
                                return Backend.wifiError || (Backend.wifiScanning ? "Scanning…" : Backend.wifiNetworks.length + " available");

                            if (root.displayedSection === "audio")
                                return root.audioSinks.length + " available";

                            return root.adapter && root.adapter.discovering ? "Looking for devices…" : root.bluetoothDevices.length + " available";
                        }
                        color: Backend.wifiError && root.displayedSection === "wifi" ? Theme.red : Theme.muted
                        elide: Text.ElideRight
                        font.pixelSize: 8
                    }

                }

                IconButton {
                    id: powerButton

                    anchors.right: scanButton.visible ? scanButton.left : parent.right
                    anchors.rightMargin: scanButton.visible ? 5 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 25
                    height: 25
                    icon: root.displayedSection === "audio" ? (root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾") : "󰐥"
                    accessibleName: {
                        if (root.displayedSection === "wifi")
                            return Backend.wifiEnabled ? "Turn Wi-Fi off" : "Turn Wi-Fi on";

                        if (root.displayedSection === "audio")
                            return root.sink && root.sink.audio && root.sink.audio.muted ? "Unmute audio" : "Mute audio";

                        return root.adapter && root.adapter.enabled ? "Turn Bluetooth off" : "Turn Bluetooth on";
                    }
                    foregroundColor: {
                        if (root.displayedSection === "wifi")
                            return Backend.wifiEnabled ? Theme.green : Theme.muted;

                        if (root.displayedSection === "audio")
                            return root.sink && root.sink.audio && !root.sink.audio.muted ? Theme.green : Theme.muted;

                        return root.adapter && root.adapter.enabled ? Theme.green : Theme.muted;
                    }
                    onClicked: {
                        if (root.displayedSection === "wifi")
                            Backend.toggleWifi();
                        else if (root.displayedSection === "audio" && root.sink && root.sink.audio)
                            root.sink.audio.muted = !root.sink.audio.muted;
                        else if (root.adapter)
                            root.adapter.enabled = !root.adapter.enabled;
                    }
                }

                IconButton {
                    id: scanButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 25
                    height: 25
                    visible: root.displayedSection === "wifi" || root.displayedSection === "bluetooth"
                    enabled: root.displayedSection === "wifi" ? Backend.wifiEnabled && !Backend.wifiScanning : root.adapter && root.adapter.enabled && !root.adapter.discovering
                    icon: "󰑐"
                    accessibleName: root.displayedSection === "wifi" ? "Scan for Wi-Fi networks" : "Scan for Bluetooth devices"
                    foregroundColor: enabled ? Theme.foreground : Theme.mutedDark
                    onClicked: {
                        if (root.displayedSection === "wifi")
                            Backend.scanWifi();
                        else
                            root.startBluetoothDiscovery();
                    }
                }

            }

            ListView {
                id: wifiList

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pickerHeader.bottom
                anchors.bottom: wifiPasswordRow.top
                anchors.leftMargin: 7
                anchors.rightMargin: 7
                anchors.topMargin: 5
                anchors.bottomMargin: wifiPasswordRow.height > 0 ? 5 : 7
                visible: root.displayedSection === "wifi"
                clip: true
                spacing: 4
                model: Backend.wifiNetworks

                delegate: ConnectionRow {
                    required property var modelData

                    width: wifiList.width
                    icon: root.wifiSignalIcon(modelData.signal)
                    title: modelData.name
                    subtitle: (modelData.security === "open" ? "Open network" : modelData.security.toUpperCase()) + "  ·  " + (root.wifiSignalDbm(modelData.signal) === null ? "Signal unknown" : root.wifiSignalDbm(modelData.signal) + " dBm")
                    active: modelData.connected
                    busy: Backend.wifiConnecting === modelData.name
                    actionText: modelData.connected ? "Disconnect" : (modelData.security !== "open" && !modelData.known ? "Password" : "Connect")
                    onClicked: root.selectWifi(modelData)
                }

            }

            Rectangle {
                id: wifiPasswordRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: pendingWifiNetwork ? 7 : 0
                height: pendingWifiNetwork ? 39 : 0
                visible: height > 0 && root.displayedSection === "wifi"
                radius: Theme.radiusSmall
                color: Theme.bg1
                border.width: wifiPasswordInput.activeFocus ? 1 : 0
                border.color: Theme.green

                TextInput {
                    id: wifiPasswordInput

                    anchors.left: parent.left
                    anchors.right: wifiConnectButton.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    activeFocusOnTab: visible
                    Keys.onReturnPressed: root.connectPendingWifi()
                    Keys.onEnterPressed: root.connectPendingWifi()

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !parent.text
                        text: "Password for " + (root.pendingWifiNetwork ? root.pendingWifiNetwork.name : "network")
                        color: Theme.mutedDark
                        font.pixelSize: 9
                    }

                }

                FocusScope {
                    id: wifiConnectButton

                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 67
                    activeFocusOnTab: visible
                    Keys.onReturnPressed: root.connectPendingWifi()
                    Keys.onEnterPressed: root.connectPendingWifi()
                    Keys.onSpacePressed: root.connectPendingWifi()

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: Theme.green
                    }

                    ShellText {
                        anchors.centerIn: parent
                        text: "Connect"
                        color: Theme.bgDim
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.connectPendingWifi()
                    }

                }

            }

            ListView {
                id: audioList

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pickerHeader.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 7
                anchors.topMargin: 5
                visible: root.displayedSection === "audio"
                clip: true
                spacing: 4
                model: root.audioSinks

                delegate: ConnectionRow {
                    required property var modelData
                    readonly property bool isDefault: root.sink && modelData.id === root.sink.id

                    width: audioList.width
                    icon: isDefault ? "󰕾" : "󰓃"
                    title: modelData.description || modelData.nickname || modelData.name
                    subtitle: modelData.nickname && modelData.nickname !== title ? modelData.nickname : "Audio output"
                    active: isDefault
                    actionText: isDefault ? "Connected" : "Switch"
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }

            }

            ListView {
                id: bluetoothList

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pickerHeader.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 7
                anchors.topMargin: 5
                visible: root.displayedSection === "bluetooth"
                clip: true
                spacing: 4
                model: root.bluetoothDevices

                delegate: ConnectionRow {
                    required property var modelData

                    width: bluetoothList.width
                    icon: root.bluetoothIcon(modelData)
                    title: modelData.name || modelData.deviceName || modelData.address
                    subtitle: modelData.batteryAvailable ? "Battery " + Math.round(modelData.battery * 100) + "%" : (modelData.paired ? "Paired" : "Available")
                    active: modelData.connected
                    busy: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                    actionText: modelData.connected ? "Disconnect" : (modelData.paired || modelData.bonded ? "Connect" : "Pair")
                    onClicked: root.activateBluetoothDevice(modelData)
                }

            }

            Behavior on height {
                NumberAnimation {
                    duration: Theme.animationNormal
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animationNormal
                    easing.type: Easing.OutCubic
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
                id: mediaArtwork

                anchors.fill: parent
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                opacity: status === Image.Ready ? 0.26 : 0
                layer.enabled: status === Image.Ready

                layer.effect: MultiEffect {
                    autoPaddingEnabled: false
                    maskEnabled: true

                    maskSource: Rectangle {
                        width: mediaArtwork.width
                        height: mediaArtwork.height
                        radius: Theme.radius
                        layer.enabled: mediaArtwork.status === Image.Ready
                    }

                }

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
            spacing: 5
            visible: trayRepeater.count > 0
            layoutDirection: Qt.RightToLeft

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
