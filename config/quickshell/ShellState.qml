import QtQuick
import Quickshell
pragma Singleton

Singleton {
    id: root

    readonly property var panelWidths: ({
        "control": 520,
        "launcher": 410,
        "clipboard": 365,
        "todo": 345,
        "capture": 395,
        "power": 380
    })
    readonly property var panelHeights: ({
        "control": 386,
        "launcher": 290,
        "clipboard": 80,
        "todo": 87,
        "capture": 208,
        "power": 56
    })
    property string panel: "clock"
    readonly property bool expanded: panel !== "clock"
    readonly property int targetWidth: expanded ? panelWidths[panel] : 170
    property alias todos: persistence.todos
    property alias nightLightTemperature: persistence.nightLightTemperature

    function show(name) {
        if (name !== "clock" && panelWidths[name] === undefined)
            return ;

        panel = panel === name ? "clock" : name;
    }

    function close() {
        panel = "clock";
    }

    function cycle(offset) {
        const panels = ["clock", "control", "launcher", "clipboard", "todo", "capture", "power"];
        const current = Math.max(0, panels.indexOf(panel));
        panel = panels[(current + offset + panels.length) % panels.length];
    }

    function addTodo(text) {
        const clean = text.trim();
        if (!clean)
            return ;

        const next = todos.slice();
        next.unshift({
            "text": clean,
            "done": false
        });
        todos = next;
    }

    function toggleTodo(index) {
        const next = todos.slice();
        next[index] = {
            "text": next[index].text,
            "done": !next[index].done
        };
        todos = next;
    }

    PersistentProperties {
        id: persistence

        property var todos: []
        property int nightLightTemperature: 4500

        reloadableId: "everforest-notch-state"
    }

}
