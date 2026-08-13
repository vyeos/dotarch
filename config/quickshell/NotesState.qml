import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    readonly property string helper: Quickshell.shellPath("scripts/notes-helper.py")
    property var notes: []
    property string activePath: ""
    property string activeText: ""
    property string saveStatus: ""
    property string lastError: ""
    property int loadRevision: 0

    function refresh() {
        if (!listProcess.running)
            listProcess.running = true;
    }

    function createNote() {
        if (!createProcess.running)
            createProcess.running = true;
    }

    function openNote(path) {
        lastError = "";
        saveStatus = "Loading…";
        activePath = String(path || "");
    }

    function closeNote() {
        activePath = "";
        activeText = "";
        saveStatus = "";
    }

    function save(markdown) {
        if (!activePath)
            return;
        activeText = markdown;
        saveStatus = "Saving…";
        activeFile.setText(markdown);
    }

    function togglePin(path) {
        if (!pinProcess.running)
            pinProcess.exec(["python3", helper, "toggle-pin", path]);
    }

    function deleteNote(path) {
        if (!deleteProcess.running) {
            if (path === activePath)
                closeNote();
            deleteProcess.exec(["python3", helper, "delete", path]);
        }
    }

    Process {
        id: listProcess
        command: ["python3", root.helper, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text || "[]");
                    root.notes = Array.isArray(parsed) ? parsed : [];
                    root.lastError = "";
                } catch (error) {
                    root.lastError = "Unable to read the notes list";
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.lastError = text.trim();
            }
        }
    }

    Process {
        id: createProcess
        command: ["python3", root.helper, "create"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const created = JSON.parse(text);
                    root.openNote(created.path);
                    root.refresh();
                } catch (error) {
                    root.lastError = "Unable to create a note";
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.lastError = text.trim();
            }
        }
    }

    Process {
        id: pinProcess
        onExited: root.refresh()
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.lastError = text.trim();
            }
        }
    }

    Process {
        id: deleteProcess
        onExited: root.refresh()
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.lastError = text.trim();
            }
        }
    }

    FileView {
        id: activeFile
        path: root.activePath
        preload: true
        atomicWrites: true
        blockWrites: true
        watchChanges: false
        onLoaded: {
            root.activeText = activeFile.text();
            root.saveStatus = "Saved";
            root.loadRevision++;
        }
        onSaved: {
            root.saveStatus = "Saved";
            root.refresh();
        }
        onLoadFailed: root.lastError = "Unable to open the note"
        onSaveFailed: {
            root.saveStatus = "Save failed";
            root.lastError = "Unable to save the note";
        }
    }

    Component.onCompleted: refresh()
}
