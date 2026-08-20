import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Item {
    id: root

    property bool alerted: false
    readonly property real level: UPower.displayDevice ? UPower.displayDevice.percentage : 1
    readonly property bool discharging: UPower.displayDevice && UPower.onBattery

    function checkBattery() {
        if (!discharging || level >= 0.12) {
            alerted = false;
            return;
        }

        if (level < 0.10 && !alerted) {
            alerted = true;
            lowBatteryNotification.command = [
                "gdbus", "call", "--session",
                "--dest", "org.freedesktop.Notifications",
                "--object-path", "/org/freedesktop/Notifications",
                "--method", "org.freedesktop.Notifications.Notify",
                "Power", "0", "battery-caution",
                "Battery level is critical",
                Math.round(level * 100) + "% remaining · connect a charger soon.",
                "[]", "{'urgency': <byte 2>}", "0"
            ];
            lowBatteryNotification.running = true;
        }
    }

    Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.checkBattery()
    }

    Process {
        id: lowBatteryNotification
    }
}
