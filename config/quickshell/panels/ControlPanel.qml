import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets
import qs
import qs.components

FocusScope {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var wifiDevice: Networking.devices.values.find((device) => {
        return device.type === DeviceType.Wifi;
    }) || null
    readonly property var wifiNetworks: wifiDevice ? wifiDevice.networks.values.slice().sort((left, right) => {
        if (left.connected !== right.connected)
            return left.connected ? -1 : 1;

        return right.signalStrength - left.signalStrength;
    }) : []
    readonly property var connectedWifi: wifiNetworks.find((network) => {
        return network.connected;
    }) || null
    readonly property var knownWifiNetworks: wifiNetworks.filter((network) => network.known)
    readonly property var availableWifiNetworks: wifiNetworks.filter((network) => !network.known)
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
    readonly property var knownBluetoothDevices: bluetoothDevices.filter((device) => device.paired || device.bonded)
    readonly property var availableBluetoothDevices: bluetoothDevices.filter((device) => !device.paired && !device.bonded)
    readonly property var connectedDevices: adapter ? adapter.devices.values.filter((device) => {
        return device.connected;
    }) : []
    readonly property real batteryLevel: UPower.displayDevice ? UPower.displayDevice.percentage : 0
    readonly property bool batteryCharging: UPower.displayDevice && (!UPower.onBattery || UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.PendingCharge)
    property string expandedSection: ""
    property string displayedSection: ""
    property var pendingWifiNetwork: null
    property string wifiError: ""
    property bool wifiRefreshPending: false
    readonly property bool audioPopoverOpen: expandedSection === "audio"
    readonly property real detailScrollFactor: 2

    function toggleSection(section) {
        const nextSection = expandedSection === section ? "" : section;
        if (expandedSection === "wifi" && nextSection !== "wifi")
            stopWifiScanner();

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
            startWifiScanner();
        else if (nextSection === "bluetooth")
            startBluetoothDiscovery();
    }

    function closeDetails() {
        if (!expandedSection)
            return ;

        toggleSection(expandedSection);
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function toggleAudio() {
        if (sink && sink.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleBluetooth() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }

    function scrollDetailList(list, event) {
        const rawDelta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y * 0.6;
        const minimum = list.originY;
        const maximum = Math.max(minimum, minimum + list.contentHeight - list.height);
        list.contentY = Math.max(minimum, Math.min(maximum, list.contentY - rawDelta * detailScrollFactor));
        event.accepted = true;
    }

    function startWifiScanner() {
        wifiError = "";
        if (!wifiDevice || !Networking.wifiEnabled)
            return ;

        wifiDevice.scannerEnabled = true;
        wifiRefreshPending = true;
        wifiRefreshTimer.restart();
    }

    function restartWifiScanner() {
        if (!wifiDevice || !Networking.wifiEnabled || wifiRefreshPending)
            return ;

        wifiError = "";
        wifiRefreshPending = true;
        wifiDevice.scannerEnabled = false;
        Qt.callLater(() => {
            if (root.wifiDevice && root.expandedSection === "wifi" && Networking.wifiEnabled)
                root.wifiDevice.scannerEnabled = true;

            wifiRefreshTimer.restart();
        });
    }

    function stopWifiScanner() {
        wifiRefreshTimer.stop();
        wifiRefreshPending = false;
        if (wifiDevice && wifiDevice.scannerEnabled)
            wifiDevice.scannerEnabled = false;
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
        if (!network || network.stateChanging)
            return ;

        if (network.connected) {
            network.disconnect();
            return ;
        }
        wifiError = "";
        if (!network.known && wifiUsesPsk(network.security)) {
            pendingWifiNetwork = network;
            Qt.callLater(() => {
                return wifiPasswordInput.forceActiveFocus(Qt.TabFocusReason);
            });
            return ;
        }
        network.connect();
    }

    function connectPendingWifi() {
        if (!pendingWifiNetwork || !wifiPasswordInput.text)
            return ;

        wifiError = "";
        pendingWifiNetwork.connectWithPsk(wifiPasswordInput.text);
        wifiPasswordInput.clear();
        pendingWifiNetwork = null;
    }

    function wifiUsesPsk(security) {
        return security === WifiSecurityType.WpaPsk || security === WifiSecurityType.Wpa2Psk || security === WifiSecurityType.Sae;
    }

    function wifiSecurityLabel(security) {
        switch (security) {
        case WifiSecurityType.Open:
            return "Open network";
        case WifiSecurityType.Sae:
            return "WPA3";
        case WifiSecurityType.Wpa2Psk:
            return "WPA2";
        case WifiSecurityType.WpaPsk:
            return "WPA";
        case WifiSecurityType.Owe:
            return "Enhanced Open";
        case WifiSecurityType.Wpa2Eap:
            return "WPA2 Enterprise";
        case WifiSecurityType.WpaEap:
            return "WPA Enterprise";
        case WifiSecurityType.Wpa3SuiteB192:
            return "WPA3 Enterprise";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:
            return "WEP";
        case WifiSecurityType.Leap:
            return "LEAP";
        default:
            return "Secured";
        }
    }

    function wifiConnectionFailed(network, reason) {
        if (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout)
            wifiError = "Authentication failed for " + network.name;
        else if (reason === ConnectionFailReason.WifiNetworkLost)
            wifiError = "Network lost while connecting";
        else
            wifiError = "Could not connect to " + network.name;
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

    function wifiSignalPercent(signal) {
        const value = Number(signal);
        if (!Number.isFinite(value))
            return null;

        return Math.round(Math.max(0, Math.min(1, value)) * 100);
    }

    function wifiSignalIcon(signal) {
        const strength = Number(signal);
        if (!Number.isFinite(strength))
            return "󰤯";

        if (strength >= 0.7)
            return "󰤨";

        if (strength >= 0.4)
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
    implicitHeight: content.implicitHeight
    onWifiDeviceChanged: {
        if (root.wifiDevice && root.expandedSection === "wifi")
            root.startWifiScanner();
    }
    Component.onDestruction: root.stopWifiScanner()
    Keys.onEscapePressed: (event) => {
        if (root.expandedSection) {
            root.closeDetails();
            event.accepted = true;
        }
    }

    PwObjectTracker {
        objects: root.audioSinks
    }

    Timer {
        id: wifiRefreshTimer

        interval: 1000
        onTriggered: root.wifiRefreshPending = false
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
        function onWifiEnabledChanged() {
            if (Networking.wifiEnabled && root.expandedSection === "wifi")
                Qt.callLater(() => root.startWifiScanner());
            else if (!Networking.wifiEnabled)
                root.stopWifiScanner();
        }

        target: Networking
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
            if (ShellState.panel === "control")
                Backend.refreshQuickControls();

            if (ShellState.panel !== "control") {
                root.closeDetails();
                root.stopBluetoothDiscovery();
            }
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
            id: quickActions

            width: parent.width
            height: 58
            spacing: 7

            ActionTile {
                id: wifiTile

                width: (parent.width - 14) / 3
                icon: "󰤨"
                title: "Wi-Fi"
                subtitle: root.connectedWifi ? root.connectedWifi.name : (Networking.wifiEnabled ? "Not connected" : "Off")
                active: Networking.wifiEnabled
                expandable: true
                expanded: root.expandedSection === "wifi"
                detailAccessibleName: "Show Wi-Fi networks"
                onClicked: root.toggleWifi()
                onDetailClicked: root.toggleSection("wifi")
            }

            ActionTile {
                id: bluetoothTile

                width: (parent.width - 14) / 3
                icon: "󰂯"
                title: "Bluetooth"
                subtitle: root.connectedDevices.length > 0 ? root.connectedDevices[0].name : (root.adapter && root.adapter.enabled ? "On" : "Off")
                active: root.adapter && root.adapter.enabled
                expandable: true
                expanded: root.expandedSection === "bluetooth"
                detailAccessibleName: "Show Bluetooth devices"
                onClicked: root.toggleBluetooth()
                onDetailClicked: root.toggleSection("bluetooth")
            }

            ActionTile {
                id: audioTile

                width: (parent.width - 14) / 3
                icon: root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾"
                title: "Audio"
                subtitle: root.sink ? (root.sink.description || root.sink.nickname || "Default output") : "No output"
                active: root.sink && root.sink.audio && !root.sink.audio.muted
                expandable: true
                expanded: root.expandedSection === "audio"
                detailAccessibleName: "Show sound outputs"
                onClicked: root.toggleAudio()
                onDetailClicked: root.toggleSection("audio")
            }

        }

        Row {
            id: systemActions

            width: parent.width
            height: 58
            spacing: 7

            ActionTile {
                id: nightLightTile

                width: (parent.width - 7) / 2
                icon: "󰖔"
                title: "Night Light"
                subtitle: Backend.nightLightStatus === "unavailable" ? "Not installed" : (Backend.nightLightStatus === "on" ? ShellState.nightLightTemperature + " K" : "Off")
                active: Backend.nightLightStatus === "on"
                expandable: Backend.nightLightStatus !== "unavailable"
                expanded: root.expandedSection === "nightlight"
                detailAccessibleName: "Adjust Night Light temperature"
                onClicked: Backend.toggleNightLight()
                onDetailClicked: root.toggleSection("nightlight")
            }

            ActionTile {
                width: (parent.width - 7) / 2
                icon: root.batteryCharging ? "" : "󰁹"
                title: "Power & Battery"
                subtitle: {
                    const battery = Math.round(root.batteryLevel * 100) + "%" + (root.batteryCharging ? " charging" : "");
                    if (Backend.powerProfile === "unavailable")
                        return battery;
                    const profile = Backend.powerProfile === "power-saver" ? "Power saver" : Backend.powerProfile.charAt(0).toUpperCase() + Backend.powerProfile.slice(1);
                    return battery + "  ·  " + profile;
                }
                active: root.batteryCharging || Backend.powerProfile === "performance"
                onClicked: Backend.cyclePowerProfile()
            }

        }

        Rectangle {
            id: devicePicker

            parent: root
            readonly property bool audioMode: root.displayedSection === "audio"
            readonly property bool nightLightMode: root.displayedSection === "nightlight"
            readonly property bool compactMode: audioMode || nightLightMode
            readonly property real availableHeight: root.height - y

            x: audioMode ? Math.max(0, Math.min(root.width - width, audioTile.x + audioTile.width / 2 - width / 2)) : 0
            y: systemActions.y + systemActions.height + content.spacing
            z: 20
            width: compactMode ? 320 : root.width
            height: nightLightMode ? Math.min(92, availableHeight) : (audioMode ? Math.min(176, availableHeight) : availableHeight)
            radius: Theme.radius
            color: Theme.bg0
            clip: true
            enabled: root.expandedSection !== ""
            visible: opacity > 0
            opacity: root.expandedSection ? 1 : 0

            Rectangle {
                anchors.top: parent.top
                x: {
                    const sourceTile = devicePicker.audioMode ? audioTile : nightLightTile;
                    const centeredX = sourceTile.x + sourceTile.width / 2 - devicePicker.x - width / 2;
                    return Math.max(Theme.radius, Math.min(parent.width - width - Theme.radius, centeredX));
                }
                width: 42
                height: 2
                radius: 1
                visible: devicePicker.compactMode
                color: Theme.primary
            }

            Item {
                id: pickerHeader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                height: 30

                Column {
                    anchors.left: parent.left
                    anchors.right: scanButton.visible ? scanButton.left : (powerButton.visible ? powerButton.left : parent.right)
                    anchors.rightMargin: scanButton.visible || powerButton.visible ? 8 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    ShellText {
                        width: parent.width
                        text: root.displayedSection === "wifi" ? "Wi-Fi networks" : (root.displayedSection === "audio" ? "Sound output" : (root.displayedSection === "nightlight" ? ShellState.nightLightTemperature + " K" : "Bluetooth devices"))
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }

                    ShellText {
                        width: parent.width
                        text: {
                            if (root.displayedSection === "wifi")
                                return root.wifiError || (root.wifiRefreshPending ? "Refreshing…" : root.wifiNetworks.length + " available");

                            if (root.displayedSection === "audio")
                                return root.audioSinks.length + " available";

                            if (root.displayedSection === "nightlight")
                                return "";

                            return root.adapter && root.adapter.discovering ? "Looking for devices…" : root.bluetoothDevices.length + " available";
                        }
                        color: root.wifiError && root.displayedSection === "wifi" ? Theme.red : Theme.muted
                        visible: text.length > 0
                        elide: Text.ElideRight
                        font.pixelSize: 10
                    }

                }

                IconButton {
                    id: powerButton

                    anchors.right: scanButton.visible ? scanButton.left : parent.right
                    anchors.rightMargin: scanButton.visible ? 5 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 25
                    height: 25
                    visible: root.displayedSection === "audio" || root.displayedSection === "nightlight"
                    icon: root.displayedSection === "audio" ? (root.sink && root.sink.audio && root.sink.audio.muted ? "󰝟" : "󰕾") : "󰐥"
                    accessibleName: {
                        if (root.displayedSection === "wifi")
                            return Networking.wifiEnabled ? "Turn Wi-Fi off" : "Turn Wi-Fi on";

                        if (root.displayedSection === "audio")
                            return root.sink && root.sink.audio && root.sink.audio.muted ? "Unmute audio" : "Mute audio";

                        if (root.displayedSection === "nightlight")
                            return Backend.nightLightStatus === "on" ? "Turn Night Light off" : "Turn Night Light on";

                        return root.adapter && root.adapter.enabled ? "Turn Bluetooth off" : "Turn Bluetooth on";
                    }
                    foregroundColor: {
                        if (root.displayedSection === "wifi")
                            return Networking.wifiEnabled ? Theme.primary : Theme.muted;

                        if (root.displayedSection === "audio")
                            return root.sink && root.sink.audio && !root.sink.audio.muted ? Theme.primary : Theme.muted;

                        if (root.displayedSection === "nightlight")
                            return Backend.nightLightStatus === "on" ? Theme.primary : Theme.muted;

                        return root.adapter && root.adapter.enabled ? Theme.primary : Theme.muted;
                    }
                    onClicked: {
                        if (root.displayedSection === "wifi")
                            root.toggleWifi();
                        else if (root.displayedSection === "audio" && root.sink && root.sink.audio)
                            root.sink.audio.muted = !root.sink.audio.muted;
                        else if (root.displayedSection === "nightlight")
                            Backend.toggleNightLight();
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
                    enabled: root.displayedSection === "wifi" ? Networking.wifiEnabled && root.wifiDevice && !root.wifiRefreshPending : root.adapter && root.adapter.enabled && !root.adapter.discovering
                    icon: "󰑐"
                    accessibleName: root.displayedSection === "wifi" ? "Scan for Wi-Fi networks" : "Scan for Bluetooth devices"
                    foregroundColor: enabled ? Theme.foreground : Theme.mutedDark
                    onClicked: {
                        if (root.displayedSection === "wifi")
                            root.restartWifiScanner();
                        else
                            root.startBluetoothDiscovery();
                    }
                }

            }

            StyledSlider {
                id: nightLightSlider

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pickerHeader.bottom
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: 4
                visible: root.displayedSection === "nightlight"
                enabled: visible
                filled: true
                icon: "󰖔"
                accessibleName: "Night Light temperature"
                value: (ShellState.nightLightTemperature - 2500) / 3500
                onMoved: (value) => Backend.setNightLightTemperature(2500 + value * 3500)
            }

            Row {
                id: wifiLists

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pickerHeader.bottom
                anchors.bottom: wifiPasswordRow.top
                anchors.leftMargin: 7
                anchors.rightMargin: 7
                anchors.topMargin: 5
                anchors.bottomMargin: wifiPasswordRow.height > 0 ? 5 : 0
                visible: root.displayedSection === "wifi"
                spacing: 4

                component WifiDelegate: ConnectionRow {
                    required property var modelData
                    readonly property var network: modelData

                    width: ListView.view.width
                    height: 42
                    icon: root.wifiSignalIcon(network.signalStrength)
                    title: network.name
                    subtitle: root.wifiSecurityLabel(network.security) + "  ·  " + root.wifiSignalPercent(network.signalStrength) + "%"
                    titleFontSize: 11
                    subtitleFontSize: 9
                    actionFontSize: 9
                    active: network.connected
                    busy: network.stateChanging
                    actionText: network.connected ? "Disconnect" : (!network.known && root.wifiUsesPsk(network.security) ? "Password" : "Connect")
                    secondaryActionVisible: network.known
                    secondaryActionName: "Forget " + network.name
                    onClicked: root.selectWifi(network)
                    onSecondaryClicked: {
                        if (root.pendingWifiNetwork === network) {
                            root.pendingWifiNetwork = null;
                            wifiPasswordInput.clear();
                        }
                        network.forget();
                    }

                    Connections {
                        function onConnectionFailed(reason) {
                            root.wifiConnectionFailed(network, reason);
                        }

                        function onConnectedChanged() {
                            if (network.connected) {
                                root.wifiError = "";
                                root.pendingWifiNetwork = null;
                                wifiPasswordInput.clear();
                            }
                        }

                        target: network
                    }
                }

                ListView {
                    id: knownWifiList

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    clip: true
                    spacing: 4
                    model: root.knownWifiNetworks
                    delegate: WifiDelegate {}

                    WheelHandler {
                        target: null
                        onWheel: (event) => root.scrollDetailList(knownWifiList, event)
                    }
                }

                ListView {
                    id: availableWifiList

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    clip: true
                    spacing: 4
                    model: root.availableWifiNetworks
                    delegate: WifiDelegate {}

                    WheelHandler {
                        target: null
                        onWheel: (event) => root.scrollDetailList(availableWifiList, event)
                    }
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
                border.color: Theme.primary

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
                    verticalAlignment: TextInput.AlignVCenter
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
                        color: Theme.primary
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

            Row {
                id: bluetoothLists

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pickerHeader.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 7
                anchors.topMargin: 5
                anchors.bottomMargin: 0
                visible: root.displayedSection === "bluetooth"
                spacing: 4

                component BluetoothDelegate: ConnectionRow {
                    required property var modelData
                    readonly property var device: modelData

                    width: ListView.view.width
                    height: 42
                    icon: root.bluetoothIcon(device)
                    title: device.name || device.deviceName || device.address
                    subtitle: device.batteryAvailable ? "Battery " + Math.round(device.battery * 100) + "%" : (device.paired ? "Paired" : "Available")
                    titleFontSize: 11
                    subtitleFontSize: 9
                    actionFontSize: 9
                    active: device.connected
                    busy: device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting
                    actionText: device.connected ? "Disconnect" : (device.paired || device.bonded ? "Connect" : "Pair")
                    secondaryActionVisible: device.paired || device.bonded
                    secondaryActionName: "Remove " + (device.name || device.deviceName || device.address)
                    onClicked: root.activateBluetoothDevice(device)
                    onSecondaryClicked: device.forget()
                }

                ListView {
                    id: knownBluetoothList

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    clip: true
                    spacing: 4
                    model: root.knownBluetoothDevices
                    delegate: BluetoothDelegate {}

                    WheelHandler {
                        target: null
                        onWheel: (event) => root.scrollDetailList(knownBluetoothList, event)
                    }
                }

                ListView {
                    id: availableBluetoothList

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    clip: true
                    spacing: 4
                    model: root.availableBluetoothDevices
                    delegate: BluetoothDelegate {}

                    WheelHandler {
                        target: null
                        onWheel: (event) => root.scrollDetailList(availableBluetoothList, event)
                    }
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
            enabled: root.expandedSection === ""
            filled: true
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
            id: brightnessSlider

            width: parent.width
            enabled: root.expandedSection === ""
            filled: true
            icon: "󰃠"
            accessibleName: "Brightness"
            value: Backend.brightness / 100
            onMoved: (value) => {
                return Backend.setBrightness(value * 100);
            }
        }

        Rectangle {
            id: mediaCard

            width: parent.width
            height: 118
            radius: Theme.radius
            clip: true
            enabled: root.expandedSection === ""

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
                    color: Theme.primaryContainer
                }

                GradientStop {
                    position: 1
                    color: Theme.bgYellow
                }

            }

        }

        Row {
            id: trayRow

            width: parent.width
            height: 31
            spacing: 5
            visible: trayRepeater.count > 0
            enabled: root.expandedSection === ""
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

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        y: quickActions.y + quickActions.height + content.spacing
        height: root.height - y
        z: 19
        visible: root.audioPopoverOpen
        color: Qt.rgba(0.12, 0.14, 0.15, 0.58)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeDetails()
        }

    }

}
