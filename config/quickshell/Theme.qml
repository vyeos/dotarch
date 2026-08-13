import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    property var palette: ({
        "bg_dim": "#232a2e", "bg0": "#2d353b", "bg1": "#343f44",
        "bg2": "#3d484d", "bg3": "#475258", "bg4": "#4f585e",
        "primary_container": "#3c4841", "secondary_container": "#45443c",
        "foreground": "#d3c6aa", "muted": "#9da9a0", "muted_dark": "#7a8478",
        "red": "#e67e80", "yellow": "#dbbc7f", "green": "#a7c080",
        "primary": "#a7c080", "blue": "#7fbbb3", "aqua": "#83c092",
        "orange": "#e69875", "purple": "#d699b6"
    })
    property string name: "Everforest"
    property string slug: "everforest"
    readonly property string helper: Quickshell.shellPath("scripts/theme-system.sh")

    readonly property color bgDim: palette.bg_dim
    readonly property color bg0: palette.bg0
    readonly property color bg1: palette.bg1
    readonly property color bg2: palette.bg2
    readonly property color bg3: palette.bg3
    readonly property color bg4: palette.bg4
    readonly property color bgGreen: palette.primary_container
    readonly property color bgYellow: palette.secondary_container
    readonly property color foreground: palette.foreground
    readonly property color muted: palette.muted
    readonly property color mutedDark: palette.muted_dark
    readonly property color red: palette.red
    readonly property color yellow: palette.yellow
    readonly property color green: palette.green
    readonly property color primary: palette.primary
    readonly property color primaryContainer: palette.primary_container
    readonly property color blue: palette.blue
    readonly property color aqua: palette.aqua
    readonly property color orange: palette.orange
    readonly property color purple: palette.purple
    readonly property color shellBackground: "#000000"
    readonly property color shellForeground: "#ffffff"
    readonly property string fontFamily: "Geist"
    readonly property string iconFontFamily: "JetBrainsMono Nerd Font"
    readonly property int radiusSmall: 10
    readonly property int radius: 15
    readonly property int animationFast: 140
    readonly property int animationNormal: 260

    function reload() {
        if (!loadProcess.running)
            loadProcess.running = true;
    }

    Component.onCompleted: reload()

    Process {
        id: loadProcess
        command: [root.helper, "current-json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const value = JSON.parse(text);
                    root.name = value.name;
                    root.slug = value.slug;
                    root.palette = value.colors;
                } catch (error) {
                    console.warn("Unable to load desktop theme:", error);
                }
            }
        }
    }
}
