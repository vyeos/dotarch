import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    readonly property string helper: Quickshell.shellPath("scripts/theme-system.sh")
    property var themes: []
    property var wallpapers: []
    property string error: ""
    property bool busy: applyProcess.running || wallpaperProcess.running
    property bool wallpaperRefreshPending: false

    function refreshThemes() {
        if (!themeListProcess.running)
            themeListProcess.running = true;
    }

    function refreshWallpapers() {
        if (wallpaperListProcess.running) {
            wallpaperRefreshPending = true;
            return;
        }
        wallpaperListProcess.running = true;
    }

    function applyTheme(slug) {
        if (!busy)
            applyProcess.exec([helper, "apply", slug]);
    }

    function setWallpaper(path) {
        if (!busy)
            wallpaperProcess.exec([helper, "wallpaper", path]);
    }

    function openWallpaperFolder() {
        if (!folderProcess.running)
            folderProcess.exec([helper, "open-wallpapers"]);
    }

    Component.onCompleted: {
        refreshThemes();
        refreshWallpapers();
    }

    Process {
        id: themeListProcess
        command: [root.helper, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.themes = JSON.parse(text || "[]");
                    root.error = "";
                } catch (error) {
                    root.error = "Unable to read themes";
                }
            }
        }
    }

    Process {
        id: wallpaperListProcess
        command: [root.helper, "wallpapers"]
        onExited: {
            if (root.wallpaperRefreshPending) {
                root.wallpaperRefreshPending = false;
                wallpaperListProcess.running = true;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.wallpapers = JSON.parse(text || "[]");
                    root.error = "";
                } catch (error) {
                    root.error = "Unable to read wallpapers";
                }
            }
        }
    }

    Process {
        id: applyProcess
        onExited: (exitCode) => {
            if (exitCode === 0) {
                Theme.reload();
                root.refreshWallpapers();
            } else {
                root.error = "Theme switch failed";
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = text.trim()
        }
    }

    Process {
        id: wallpaperProcess
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.error = "Wallpaper switch failed";
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = text.trim()
        }
    }

    Process {
        id: folderProcess
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = text.trim()
        }
    }
}
