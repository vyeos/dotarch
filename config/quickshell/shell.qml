import Quickshell
import Quickshell.Io
import qs

ShellRoot {
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

}
