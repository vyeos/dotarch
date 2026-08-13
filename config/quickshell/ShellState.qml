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
        "todo": 420,
        "notes": 500,
        "capture": 395,
        "power": 380
    })
    readonly property var panelHeights: ({
        "control": 386,
        "launcher": 290,
        "clipboard": 80,
        "todo": 87,
        "notes": 430,
        "capture": 208,
        "power": 56
    })
    property string panel: "clock"
    readonly property bool expanded: panel !== "clock"
    readonly property int targetWidth: expanded ? panelWidths[panel] : 145
    property var todos: []
    property alias nightLightTemperature: persistence.nightLightTemperature

    function loadTodos() {
        try {
            const saved = JSON.parse(todoFile.text());
            if (!Array.isArray(saved))
                return ;

            todos = saved.filter((todo) => todo && typeof todo.text === "string").map((todo, index) => ({
                "id": todo.id || "legacy-" + Date.now().toString() + "-" + index.toString(),
                "text": todo.text,
                "done": todo.done === true,
                "priority": ["low", "medium", "high"].includes(todo.priority) ? todo.priority : "none",
                "category": typeof todo.category === "string" ? todo.category : "",
                "dueDate": typeof todo.dueDate === "string" ? todo.dueDate : "",
                "notes": typeof todo.notes === "string" ? todo.notes : ""
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
        const panels = ["clock", "control", "launcher", "clipboard", "todo", "notes", "capture", "power"];
        const current = Math.max(0, panels.indexOf(panel));
        setPanel(panels[(current + offset + panels.length) % panels.length]);
    }

    function addTodo(text) {
        const clean = text.trim();
        if (!clean)
            return ;

        const parsed = parseTodoInput(clean);
        const next = todos.slice();
        next.unshift({
            "id": Date.now().toString() + "-" + Math.floor(Math.random() * 1000000).toString(),
            "text": parsed.text,
            "done": false,
            "priority": parsed.priority,
            "category": parsed.category,
            "dueDate": parsed.dueDate,
            "notes": ""
        });
        saveTodos(next);
    }

    function toggleTodo(index) {
        if (index < 0 || index >= todos.length)
            return ;

        const next = todos.slice();
        next[index] = Object.assign({}, next[index], {
            "done": !next[index].done
        });
        saveTodos(next);
    }

    function updateTodo(index, changes) {
        if (index < 0 || index >= todos.length)
            return ;

        const next = todos.slice();
        next[index] = Object.assign({}, next[index], changes);
        saveTodos(next);
    }

    function removeTodo(index) {
        if (index < 0 || index >= todos.length)
            return ;

        const next = todos.slice();
        next.splice(index, 1);
        saveTodos(next);
    }

    function swapTodos(first, second) {
        if (first < 0 || second < 0 || first >= todos.length || second >= todos.length || first === second)
            return ;

        const next = todos.slice();
        const held = next[first];
        next[first] = next[second];
        next[second] = held;
        saveTodos(next);
    }

    function clearCompletedTodos() {
        const next = todos.filter((todo) => !todo.done);
        if (next.length !== todos.length)
            saveTodos(next);
    }

    function dateKey(date) {
        const year = date.getFullYear().toString();
        const month = (date.getMonth() + 1).toString().padStart(2, "0");
        const day = date.getDate().toString().padStart(2, "0");
        return year + "-" + month + "-" + day;
    }

    function todayKey() {
        return dateKey(new Date());
    }

    function tomorrowKey() {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        return dateKey(tomorrow);
    }

    function parseTodoInput(input) {
        const words = input.split(/\s+/);
        const title = [];
        let priority = "none";
        let category = "";
        let dueDate = "";
        for (let i = 0; i < words.length; i++) {
            const word = words[i];
            const lower = word.toLowerCase();
            if (/^#[A-Za-z0-9_-]+$/.test(word)) {
                category = word.slice(1);
            } else if (lower === "!high" || word === "!!!") {
                priority = "high";
            } else if (lower === "!medium" || lower === "!med" || word === "!!") {
                priority = "medium";
            } else if (lower === "!low" || word === "!") {
                priority = "low";
            } else if (lower === "today" || lower === "@today") {
                dueDate = todayKey();
            } else if (lower === "tomorrow" || lower === "@tomorrow") {
                dueDate = tomorrowKey();
            } else {
                title.push(word);
            }
        }
        return {
            "text": title.join(" ").trim() || input,
            "priority": priority,
            "category": category,
            "dueDate": dueDate
        };
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
