import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    readonly property string helper: Quickshell.shellPath("scripts/shell-actions.sh")
    property string wifiName: "Disconnected"
    property bool wifiEnabled: false
    property var wifiNetworks: []
    property bool wifiScanning: false
    property string wifiConnecting: ""
    property string wifiError: ""
    property int brightness: 0
    property bool recording: false
    property var clipboardItems: []
    property string clipboardContents: ""
    property bool clipboardContentsLoading: false
    property string lastCapture: ""
    property string lastError: ""

    function refreshStatus() {
        wifiProcess.running = true;
        if (!brightnessCommit.running && !brightnessSetProcess.running)
            brightnessProcess.running = true;

    }

    function refresh() {
        refreshStatus();
        wifiNetworksProcess.running = true;
    }

    function toggleWifi() {
        actionProcess.exec([helper, "wifi-toggle"]);
    }

    function scanWifi() {
        if (!wifiEnabled || wifiScanning)
            return ;

        wifiError = "";
        wifiScanning = true;
        wifiScanProcess.exec([helper, "wifi-scan"]);
    }

    function connectWifi(name, passphrase) {
        wifiError = "";
        wifiConnecting = name;
        wifiConnectionProcess.exec([helper, "wifi-connect", name, passphrase || ""]);
    }

    function disconnectWifi() {
        wifiError = "";
        wifiConnecting = wifiName;
        wifiConnectionProcess.exec([helper, "wifi-disconnect"]);
    }

    function setBrightness(value) {
        brightness = Math.max(0, Math.min(100, Math.round(value)));
        brightnessCommit.restart();
    }

    function refreshClipboard() {
        clipboardProcess.running = true;
    }

    function pasteClipboard(id) {
        pasteProcess.exec([helper, "clipboard-paste", String(id)]);
    }

    function loadClipboardContents(id, itemPreview) {
        if (itemPreview.startsWith("[[ binary data")) {
            clipboardContents = itemPreview;
            clipboardContentsLoading = false;
            return ;
        }
        clipboardContents = "";
        clipboardContentsLoading = true;
        clipboardContentsProcess.exec([helper, "clipboard-decode", String(id)]);
    }

    function capture(mode) {
        lastError = "";
        captureProcess.exec([helper, "capture", mode]);
    }

    function toggleRecording() {
        lastError = "";
        recordingProcess.exec([helper, "record-toggle"]);
    }

    function power(action) {
        actionProcess.exec([helper, "power", action]);
    }

    Process {
        id: wifiProcess

        command: [root.helper, "wifi-status"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("\t");
                root.wifiEnabled = parts[0] === "on";
                root.wifiName = parts[1] || (root.wifiEnabled ? "Not connected" : "Wi-Fi off");
            }
        }

    }

    Process {
        id: wifiNetworksProcess

        command: [root.helper, "wifi-list"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiNetworks = text.trim().split("\n").filter((line) => {
                    return line.length > 0;
                }).map((line) => {
                    const parts = line.split("\t");
                    return {
                        "name": parts[0],
                        "security": parts[1] || "open",
                        "signal": Number(parts[2]) || -10000,
                        "connected": parts[3] === "true",
                        "known": parts[4] === "true"
                    };
                });
            }
        }

    }

    Process {
        id: wifiScanProcess

        onExited: (exitCode) => {
            root.wifiScanning = false;
            if (exitCode !== 0)
                root.wifiError = "Could not scan for networks";

            wifiNetworksProcess.running = true;
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.wifiError = text.trim().split("\n").pop();

            }
        }

    }

    Process {
        id: wifiConnectionProcess

        onExited: (exitCode) => {
            root.wifiConnecting = "";
            if (exitCode !== 0 && !root.wifiError)
                root.wifiError = "Could not connect to the network";

            root.refresh();
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.wifiError = text.trim().split("\n").pop();

            }
        }

    }

    Process {
        id: brightnessProcess

        command: [root.helper, "brightness-get"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.brightness = Math.max(0, Math.min(100, Number(text.trim()) || 0))
        }

    }

    Process {
        id: brightnessSetProcess

        onExited: (exitCode) => {
            if (exitCode !== 0)
                brightnessProcess.running = true;

        }
    }

    Process {
        id: clipboardProcess

        command: [root.helper, "clipboard-list"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.clipboardItems = text.trim().split("\n").filter((line) => {
                    return line.length > 0;
                }).map((line) => {
                    const separator = line.indexOf("\t");
                    return {
                        "id": separator < 0 ? line : line.slice(0, separator),
                        "preview": separator < 0 ? line : line.slice(separator + 1).replace(/\t/g, " ")
                    };
                });
            }
        }

    }

    Process {
        id: captureProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output)
                    root.lastCapture = output;

            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output)
                    root.lastError = output;

            }
        }

    }

    Process {
        id: recordingProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output === "recording-started")
                    root.recording = true;
                else if (output === "recording-stopped")
                    root.recording = false;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output)
                    root.lastError = output;

            }
        }

    }

    Process {
        id: recordingStatusProcess

        command: [root.helper, "record-status"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.recording = text.trim() === "recording-active"
        }

    }

    Process {
        id: clipboardContentsProcess

        onExited: root.clipboardContentsLoading = false

        stdout: StdioCollector {
            onStreamFinished: root.clipboardContents = text
        }

    }

    Process {
        id: actionProcess

        onExited: root.refresh()
    }

    Process {
        id: pasteProcess
    }

    Timer {
        id: brightnessCommit

        interval: 75
        onTriggered: brightnessSetProcess.exec([root.helper, "brightness-set", String(root.brightness)])
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refreshStatus()
    }

    Timer {
        interval: 2000
        running: root.recording
        repeat: true
        onTriggered: recordingStatusProcess.running = true
    }

}
