import QtQuick
import Quickshell
import Quickshell.Io
import qs

ShellRoot {
    id: root

    property string pendingCaptureMode: ""

    Variants {
        model: Quickshell.screens

        Notch {
            required property var modelData

            screen: modelData
        }

    }

    Variants {
        model: Quickshell.screens

        CaptureSelector {
            required property var modelData

            screen: modelData
        }

    }

    IpcHandler {
        function toggle(panel: string) {
            ShellState.show(panel);
        }

        function close() {
            ShellState.close();
        }

        function next() {
            ShellState.cycle(1);
        }

        function previous() {
            ShellState.cycle(-1);
        }

        target: "notch"
    }

    IpcHandler {
        function screenshot(mode: string) {
            if (!["full", "window", "region"].includes(mode))
                return;

            root.pendingCaptureMode = mode;
            ShellState.close();
            captureShortcutDelay.restart();
        }

        function toggleRecording() {
            if (Backend.recording) {
                Backend.toggleRecording();
                return;
            }

            ShellState.close();
            recordingShortcutDelay.restart();
        }

        target: "capture"
    }

    Timer {
        id: captureShortcutDelay

        interval: Theme.animationNormal + 100
        onTriggered: {
            Backend.capture(root.pendingCaptureMode);
            root.pendingCaptureMode = "";
        }
    }

    Timer {
        id: recordingShortcutDelay

        interval: Theme.animationNormal + 100
        onTriggered: Backend.toggleRecording()
    }

}
