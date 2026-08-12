import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    readonly property string helper: Quickshell.shellPath("scripts/shell-actions.sh")
    property string wifiName: "Disconnected"
    property bool wifiEnabled: false
    property int brightness: 0
    property bool recording: false
    property var clipboardItems: []
    property string lastCapture: ""

    function refresh() {
        wifiProcess.running = true;
        brightnessProcess.running = true;
    }

    function toggleWifi() {
        actionProcess.exec([helper, "wifi-toggle"]);
    }

    function setBrightness(value) {
        brightnessProcess.running = false;
        actionProcess.exec([helper, "brightness-set", String(Math.round(value))]);
        brightness = Math.round(value);
    }

    function refreshClipboard() {
        clipboardProcess.running = true;
    }

    function copyClipboard(id) {
        actionProcess.exec([helper, "clipboard-copy", String(id)]);
    }

    function capture(mode) {
        captureProcess.exec([helper, "capture", mode]);
    }

    function toggleRecording() {
        captureProcess.exec([helper, "record-toggle"]);
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
        id: brightnessProcess

        command: [root.helper, "brightness-get"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.brightness = Math.max(0, Math.min(100, Number(text.trim()) || 0))
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
                if (output === "recording-started")
                    root.recording = true;
                else if (output === "recording-stopped")
                    root.recording = false;
                else if (output)
                    root.lastCapture = output;
            }
        }

    }

    Process {
        id: actionProcess

        onExited: root.refresh()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

}
