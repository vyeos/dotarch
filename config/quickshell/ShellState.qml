import QtQuick
import Quickshell
import Quickshell.Io
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
    property var todos: []
    property alias nightLightTemperature: persistence.nightLightTemperature

    function loadTodos() {
        try {
            const saved = JSON.parse(todoFile.text());
            if (!Array.isArray(saved))
                return ;

            todos = saved.filter((todo) => todo && typeof todo.text === "string").map((todo) => ({
                "text": todo.text,
                "done": todo.done === true
            }));
        } catch (error) {
            console.warn("Unable to load todos.json:", error);
        }
    }

    function saveTodos(next) {
        todos = next;
        todoFile.setText(JSON.stringify(next, null, 2) + "\n");
    }

    function setPanel(name) {
        if (panel === "todo" || name === "todo")
            clearCompletedTodos();

        panel = name;
    }

    function show(name) {
        if (name !== "clock" && panelWidths[name] === undefined)
            return ;

        setPanel(panel === name ? "clock" : name);
    }

    function close() {
        setPanel("clock");
    }

    function cycle(offset) {
        const panels = ["clock", "control", "launcher", "clipboard", "todo", "capture", "power"];
        const current = Math.max(0, panels.indexOf(panel));
        setPanel(panels[(current + offset + panels.length) % panels.length]);
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
        saveTodos(next);
    }

    function toggleTodo(index) {
        const next = todos.slice();
        next[index] = {
            "text": next[index].text,
            "done": !next[index].done
        };
        saveTodos(next);
    }

    function clearCompletedTodos() {
        const next = todos.filter((todo) => !todo.done);
        if (next.length !== todos.length)
            saveTodos(next);
    }

    FileView {
        id: todoFile

        path: Quickshell.shellPath("todos.json")
        preload: true
        atomicWrites: true
        watchChanges: false
        onLoaded: root.loadTodos()
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound)
                todoFile.setText("[]\n");
        }
    }

    PersistentProperties {
        id: persistence

        property int nightLightTemperature: 4500

        reloadableId: "everforest-notch-state"
    }

}
