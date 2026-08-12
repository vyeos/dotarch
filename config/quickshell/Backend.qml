import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    readonly property string helper: Quickshell.shellPath("scripts/shell-actions.sh")
    property int brightness: 0
    property int brightnessInFlight: -1
    property int nightLightTemperatureInFlight: -1
    property string nightLightStatus: "off"
    property string powerProfile: "unavailable"
    property int keyboardBacklightLevel: -1
    property int keyboardBacklightMaximum: 0
    property bool recording: false
    property var clipboardItems: []
    property string clipboardContents: ""
    property bool clipboardContentsLoading: false
    property string lastCapture: ""
    property string lastError: ""
    property var windowCandidates: []
    property string captureSelectionMode: ""
    readonly property bool captureSelectionActive: captureSelectionMode.length > 0
    property bool regionSelectionDragging: false
    property real regionStartX: 0
    property real regionStartY: 0
    property real regionCurrentX: 0
    property real regionCurrentY: 0
    property var pendingGeometryCapture: null

    function refreshStatus() {
        if (!brightnessCommit.running && !brightnessSetProcess.running)
            brightnessProcess.running = true;
        refreshQuickControls();

    }

    function refreshQuickControls() {
        if (!nightLightStatusProcess.running)
            nightLightStatusProcess.running = true;
        if (!powerProfileStatusProcess.running)
            powerProfileStatusProcess.running = true;
        if (!keyboardBacklightStatusProcess.running)
            keyboardBacklightStatusProcess.running = true;
    }

    function toggleNightLight() {
        if (!nightLightToggleProcess.running)
            nightLightToggleProcess.exec([helper, "night-light-toggle", String(ShellState.nightLightTemperature)]);
    }

    function setNightLightTemperature(value) {
        ShellState.nightLightTemperature = Math.max(2500, Math.min(6000, Math.round(value / 50) * 50));
        if (nightLightStatus === "on")
            nightLightCommit.restart();
    }

    function cyclePowerProfile() {
        if (!powerProfileToggleProcess.running)
            powerProfileToggleProcess.exec([helper, "power-profile-cycle"]);
    }

    function cycleKeyboardBacklight() {
        if (!keyboardBacklightToggleProcess.running)
            keyboardBacklightToggleProcess.exec([helper, "keyboard-backlight-cycle"]);
    }

    function setKeyboardBacklight(value) {
        const level = Math.max(0, Math.min(keyboardBacklightMaximum, Math.round(value)));
        if (level === keyboardBacklightLevel)
            return;

        keyboardBacklightLevel = level;
        keyboardBacklightCommit.restart();
    }

    function setKeyboardBacklightTimeout(value, unit) {
        ShellState.keyboardBacklightTimeoutValue = Math.max(0, Math.min(3600, Math.round(value)));
        ShellState.keyboardBacklightTimeoutUnit = unit === "sec" ? "sec" : "min";
        keyboardBacklightIdleProcess.exec([helper, "keyboard-backlight-idle", String(ShellState.keyboardBacklightTimeoutValue), ShellState.keyboardBacklightTimeoutUnit]);
    }

    function setBrightness(value) {
        brightness = Math.max(0, Math.min(100, Math.round(value)));
        if (!brightnessCommit.running && !brightnessSetProcess.running)
            brightnessCommit.start();
    }

    function commitBrightness() {
        if (brightnessSetProcess.running)
            return;

        brightnessInFlight = brightness;
        brightnessSetProcess.exec([helper, "brightness-set", String(brightnessInFlight)]);
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
        if (mode === "window") {
            windowCandidatesProcess.exec([helper, "window-list"]);
            return ;
        }
        if (mode === "region") {
            windowCandidates = [];
            captureSelectionMode = "region";
            return ;
        }
        captureProcess.exec([helper, "capture", mode]);
    }

    function cancelCaptureSelection() {
        captureSelectionMode = "";
        windowCandidates = [];
        regionSelectionDragging = false;
    }

    function queueGeometryCapture(geometry) {
        pendingGeometryCapture = geometry;
        cancelCaptureSelection();
        geometryCaptureDelay.restart();
    }

    function captureWindow(candidate) {
        queueGeometryCapture(candidate);
    }

    function beginRegionSelection(x, y) {
        if (captureSelectionMode !== "region")
            return ;

        regionStartX = x;
        regionStartY = y;
        regionCurrentX = x;
        regionCurrentY = y;
        regionSelectionDragging = true;
    }

    function updateRegionSelection(x, y) {
        if (!regionSelectionDragging)
            return ;

        regionCurrentX = x;
        regionCurrentY = y;
    }

    function finishRegionSelection(x, y) {
        if (!regionSelectionDragging)
            return ;

        updateRegionSelection(x, y);
        const left = Math.floor(Math.min(regionStartX, regionCurrentX));
        const top = Math.floor(Math.min(regionStartY, regionCurrentY));
        const right = Math.ceil(Math.max(regionStartX, regionCurrentX));
        const bottom = Math.ceil(Math.max(regionStartY, regionCurrentY));
        if (right - left < 2 || bottom - top < 2) {
            cancelCaptureSelection();
            return ;
        }
        queueGeometryCapture({
            "x": left,
            "y": top,
            "width": right - left,
            "height": bottom - top
        });
    }

    function toggleRecording() {
        lastError = "";
        recordingProcess.exec([helper, "record-toggle"]);
    }

    function power(action) {
        actionProcess.exec([helper, "power", action]);
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
            if (exitCode !== 0) {
                brightnessProcess.running = true;
                return;
            }
            if (root.brightness !== root.brightnessInFlight)
                brightnessCommit.start();

        }
    }

    Process {
        id: nightLightStatusProcess

        command: [root.helper, "night-light-status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.nightLightStatus = text.trim() || "off"
        }
    }

    Process {
        id: powerProfileStatusProcess

        command: [root.helper, "power-profile-status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.powerProfile = text.trim() || "unavailable"
        }
    }

    Process {
        id: keyboardBacklightStatusProcess

        command: [root.helper, "keyboard-backlight-status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output === "unavailable") {
                    root.keyboardBacklightLevel = -1;
                    root.keyboardBacklightMaximum = 0;
                    return;
                }
                const values = output.split("/");
                root.keyboardBacklightLevel = Number(values[0]);
                root.keyboardBacklightMaximum = Number(values[1]);
            }
        }
    }

    Process {
        id: nightLightToggleProcess

        onExited: root.refreshQuickControls()
    }

    Process {
        id: powerProfileToggleProcess

        onExited: root.refreshQuickControls()
    }

    Process {
        id: keyboardBacklightToggleProcess

        onExited: root.refreshQuickControls()
    }

    Process {
        id: keyboardBacklightSetProcess

        onExited: root.refreshQuickControls()
    }

    Process {
        id: keyboardBacklightIdleProcess

        command: [root.helper, "keyboard-backlight-idle", String(ShellState.keyboardBacklightTimeoutValue), ShellState.keyboardBacklightTimeoutUnit]
        running: true
    }

    Process {
        id: nightLightSetProcess

        onExited: {
            root.refreshQuickControls();
            if (root.nightLightStatus === "on" && ShellState.nightLightTemperature !== root.nightLightTemperatureInFlight)
                nightLightCommit.restart();
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
        id: windowCandidatesProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const candidates = JSON.parse(text);
                    if (!Array.isArray(candidates) || candidates.length === 0) {
                        root.lastError = "No windows available to capture";
                        return ;
                    }
                    root.windowCandidates = candidates;
                    root.captureSelectionMode = "window";
                } catch (error) {
                    root.lastError = "Could not load windows for capture";
                }
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

    Timer {
        id: geometryCaptureDelay

        interval: Theme.animationFast
        onTriggered: {
            const geometry = root.pendingGeometryCapture;
            if (!geometry)
                return ;

            root.pendingGeometryCapture = null;
            captureProcess.exec([root.helper, "capture-geometry", String(geometry.x), String(geometry.y), String(geometry.width), String(geometry.height)]);
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

        onExited: root.refreshStatus()
    }

    Process {
        id: pasteProcess
    }

    Timer {
        id: brightnessCommit

        interval: 40
        onTriggered: root.commitBrightness()
    }

    Timer {
        id: nightLightCommit

        interval: 120
        onTriggered: {
            if (!nightLightSetProcess.running) {
                root.nightLightTemperatureInFlight = ShellState.nightLightTemperature;
                nightLightSetProcess.exec([root.helper, "night-light-set", String(root.nightLightTemperatureInFlight)]);
            }
        }
    }

    Timer {
        id: keyboardBacklightCommit

        interval: 60
        onTriggered: {
            if (!keyboardBacklightSetProcess.running)
                keyboardBacklightSetProcess.exec([root.helper, "keyboard-backlight-set", String(root.keyboardBacklightLevel)]);
        }
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
