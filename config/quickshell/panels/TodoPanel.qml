import QtQuick
import qs
import qs.components

FocusScope {
    id: root

    property string currentView: "all"
    property string editingId: ""
    property string detailsId: ""
    property bool textEditorActive: todoInput.activeFocus || categoryInput.activeFocus || dateInput.activeFocus || notesInput.activeFocus || editingId !== ""
    readonly property string today: ShellState.todayKey()
    readonly property string tomorrow: ShellState.tomorrowKey()
    readonly property var visibleTodos: filterTodos(ShellState.todos)
    readonly property int detailsIndex: sourceIndexForId(detailsId)
    readonly property var detailsTask: detailsIndex >= 0 ? ShellState.todos[detailsIndex] : null

    function takeInitialFocus() {
        todoInput.forceActiveFocus(Qt.TabFocusReason);
    }

    function addTodo() {
        ShellState.addTodo(todoInput.text);
        todoInput.clear();
    }

    function filterTodos(todos) {
        const result = [];
        for (let i = 0; i < todos.length; i++) {
            const task = todos[i];
            const due = task.dueDate || "";
            if (currentView === "today" && (!due || due > today))
                continue;
            if (currentView === "tomorrow" && due !== tomorrow)
                continue;
            if (currentView === "scheduled" && !due)
                continue;
            result.push({
                "sourceIndex": i,
                "task": task
            });
        }
        return result;
    }

    function sourceIndexForId(id) {
        if (!id)
            return -1;
        for (let i = 0; i < ShellState.todos.length; i++) {
            if (ShellState.todos[i].id === id)
                return i;
        }
        return -1;
    }

    function selectRow(index) {
        if (visibleTodos.length === 0) {
            taskList.currentIndex = -1;
            return;
        }
        taskList.currentIndex = Math.max(0, Math.min(visibleTodos.length - 1, index));
        taskList.positionViewAtIndex(taskList.currentIndex, ListView.Contain);
        const item = taskList.itemAtIndex(taskList.currentIndex);
        if (item)
            item.forceActiveFocus(Qt.OtherFocusReason);
    }

    function moveSelection(offset) {
        selectRow((taskList.currentIndex < 0 ? (offset > 0 ? -1 : visibleTodos.length) : taskList.currentIndex) + offset);
    }

    function moveView(offset) {
        const views = ["all", "today", "tomorrow", "scheduled"];
        const current = Math.max(0, views.indexOf(currentView));
        setView(views[(current + offset + views.length) % views.length]);
    }

    function setView(view) {
        currentView = view;
        detailsId = "";
        editingId = "";
        Qt.callLater(() => {
            if (visibleTodos.length > 0)
                selectRow(0);
            else
                root.forceActiveFocus(Qt.OtherFocusReason);
        });
    }

    function toggleSelected() {
        if (taskList.currentIndex < 0 || taskList.currentIndex >= visibleTodos.length)
            return;
        ShellState.toggleTodo(visibleTodos[taskList.currentIndex].sourceIndex);
    }

    function reorderSelected(offset) {
        const current = taskList.currentIndex;
        const target = current + offset;
        if (current < 0 || target < 0 || target >= visibleTodos.length)
            return;
        ShellState.swapTodos(visibleTodos[current].sourceIndex, visibleTodos[target].sourceIndex);
        Qt.callLater(() => selectRow(target));
    }

    function beginEditing(id) {
        detailsId = "";
        editingId = id;
    }

    function showDetails(id) {
        editingId = "";
        detailsId = detailsId === id ? "" : id;
    }

    function priorityColor(priority) {
        if (priority === "high")
            return Theme.red;
        if (priority === "medium")
            return Theme.yellow;
        if (priority === "low")
            return Theme.blue;
        return Theme.bg3;
    }

    function dueLabel(dueDate) {
        if (!dueDate)
            return "";
        return displayDate(dueDate);
    }

    function displayDate(isoDate) {
        const parts = String(isoDate || "").split("-");
        if (parts.length !== 3)
            return "";
        return parts[2] + "-" + parts[1] + "-" + parts[0].slice(-2);
    }

    function parseDisplayDate(displayDate) {
        const match = String(displayDate || "").trim().match(/^(\d{2})-(\d{2})-(\d{2})$/);
        if (!match)
            return "";
        const day = Number(match[1]);
        const month = Number(match[2]);
        const year = 2000 + Number(match[3]);
        const candidate = new Date(year, month - 1, day);
        if (candidate.getFullYear() !== year || candidate.getMonth() !== month - 1 || candidate.getDate() !== day)
            return "";
        return year.toString() + "-" + match[2] + "-" + match[1];
    }

    function cyclePriority() {
        if (!detailsTask)
            return;
        const priorities = ["none", "low", "medium", "high"];
        const current = Math.max(0, priorities.indexOf(detailsTask.priority || "none"));
        ShellState.updateTodo(detailsIndex, {
            "priority": priorities[(current + 1) % priorities.length]
        });
    }

    implicitWidth: 392
    implicitHeight: content.implicitHeight

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Slash && !root.textEditorActive) {
            todoInput.forceActiveFocus(Qt.ShortcutFocusReason);
            event.accepted = true;
        } else if (!root.textEditorActive && event.key === Qt.Key_Up && (event.modifiers & Qt.ControlModifier)) {
            root.reorderSelected(-1);
            event.accepted = true;
        } else if (!root.textEditorActive && event.key === Qt.Key_Down && (event.modifiers & Qt.ControlModifier)) {
            root.reorderSelected(1);
            event.accepted = true;
        } else if (!root.textEditorActive && event.key === Qt.Key_Left) {
            root.moveView(-1);
            event.accepted = true;
        } else if (!root.textEditorActive && event.key === Qt.Key_Right) {
            root.moveView(1);
            event.accepted = true;
        } else if (!root.textEditorActive && (event.key === Qt.Key_Down || event.key === Qt.Key_J)) {
            root.moveSelection(1);
            event.accepted = true;
        } else if (!root.textEditorActive && (event.key === Qt.Key_Up || event.key === Qt.Key_K)) {
            root.moveSelection(-1);
            event.accepted = true;
        } else if (!root.textEditorActive && event.key === Qt.Key_Space) {
            root.toggleSelected();
            event.accepted = true;
        } else if (!root.textEditorActive && event.key === Qt.Key_E && taskList.currentIndex >= 0) {
            root.beginEditing(root.visibleTodos[taskList.currentIndex].task.id);
            event.accepted = true;
        } else if (!root.textEditorActive && event.key === Qt.Key_D && taskList.currentIndex >= 0) {
            root.showDetails(root.visibleTodos[taskList.currentIndex].task.id);
            event.accepted = true;
        }
    }

    onVisibleTodosChanged: {
        if (visibleTodos.length === 0)
            taskList.currentIndex = -1;
        else if (taskList.currentIndex >= visibleTodos.length)
            taskList.currentIndex = visibleTodos.length - 1;
    }

    Column {
        id: content

        width: parent.width
        spacing: 8

        Item {
            width: parent.width
            height: 30

            ShellText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Todo"
                font.pixelSize: 14
                font.weight: Font.Bold
            }

        }

        Row {
            width: parent.width
            height: 36
            spacing: 0

            Item {
                width: parent.width
                height: parent.height

                TextInput {
                    id: todoInput

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 2
                    rightPadding: 2
                    color: Theme.foreground
                    selectionColor: Theme.primaryContainer
                    selectedTextColor: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    activeFocusOnTab: true
                    Keys.onReturnPressed: root.addTodo()
                    Keys.onEnterPressed: root.addTodo()
                    Keys.onDownPressed: root.moveSelection(1)

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Add task…  !high  #category  today"
                        color: Theme.mutedDark
                        visible: !parent.text
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: todoInput.activeFocus ? 2 : 1
                    color: todoInput.activeFocus ? Theme.primary : Theme.bg3
                }
            }

        }

        Row {
            id: viewTabs

            width: parent.width
            height: 25
            spacing: 18

            Repeater {
                model: [
                    { "key": "all", "label": "All" },
                    { "key": "today", "label": "Today" },
                    { "key": "tomorrow", "label": "Tomorrow" },
                    { "key": "scheduled", "label": "Scheduled" }
                ]

                delegate: Item {
                    required property var modelData

                    width: tabLabel.implicitWidth
                    height: viewTabs.height

                    ShellText {
                        id: tabLabel

                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: root.currentView === modelData.key ? Theme.foreground : Theme.muted
                        font.pixelSize: 10
                        font.weight: root.currentView === modelData.key ? Font.Bold : Font.Normal
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 2
                        color: Theme.primary
                        visible: root.currentView === modelData.key
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setView(modelData.key)
                    }
                }
            }

            Item { width: 1; height: 1 }

            ShellText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.visibleTodos.length.toString()
                color: Theme.mutedDark
                font.pixelSize: 9
            }
        }

        ListView {
            id: taskList

            width: parent.width
            height: count > 0 ? Math.min(6, count) * 38 : 42
            clip: true
            interactive: count > 6
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: count > 0 ? 0 : -1
            model: root.visibleTodos

            onCurrentIndexChanged: {
                if (root.detailsId && currentIndex >= 0 && currentIndex < root.visibleTodos.length)
                    root.detailsId = root.visibleTodos[currentIndex].task.id;
            }

            ShellText {
                anchors.centerIn: parent
                visible: taskList.count === 0
                text: root.currentView === "all" ? "Nothing here — nice." : "No tasks in this view."
                color: Theme.mutedDark
                font.pixelSize: 10
            }

            delegate: FocusScope {
                id: taskRow

                required property var modelData
                required property int index
                readonly property var task: modelData.task
                readonly property bool selected: taskList.currentIndex === index

                function saveTitle() {
                    const clean = editInput.text.trim();
                    if (clean)
                        ShellState.updateTodo(modelData.sourceIndex, { "text": clean });
                    root.editingId = "";
                    forceActiveFocus(Qt.OtherFocusReason);
                }

                width: ListView.view.width
                height: 38
                activeFocusOnTab: true

                Keys.onReturnPressed: root.showDetails(task.id)
                Keys.onEnterPressed: root.showDetails(task.id)

                onActiveFocusChanged: {
                    if (activeFocus)
                        taskList.currentIndex = index;
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: taskRow.selected ? Theme.primaryContainer : "transparent"
                }

                Connections {
                    target: root
                    function onEditingIdChanged() {
                        if (root.editingId === taskRow.task.id)
                            Qt.callLater(() => editInput.forceActiveFocus(Qt.OtherFocusReason));
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        taskList.currentIndex = index;
                        taskRow.forceActiveFocus(Qt.MouseFocusReason);
                    }
                    onDoubleClicked: root.beginEditing(taskRow.task.id)
                }

                Rectangle {
                    id: checkbox

                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15
                    height: 15
                    radius: 4
                    color: taskRow.task.done ? Theme.primary : "transparent"
                    border.width: 1
                    border.color: taskRow.task.done ? Theme.primary : Theme.mutedDark

                    ShellText {
                        anchors.centerIn: parent
                        text: taskRow.task.done ? "✓" : ""
                        color: Theme.bgDim
                        font.pixelSize: 8
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            taskList.currentIndex = taskRow.index;
                            ShellState.toggleTodo(taskRow.modelData.sourceIndex);
                        }
                    }
                }

                TextInput {
                    id: editInput

                    anchors.left: priorityDot.right
                    anchors.leftMargin: 7
                    anchors.right: metadata.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.editingId === taskRow.task.id
                    text: taskRow.task.text
                    color: Theme.foreground
                    selectionColor: Theme.primaryContainer
                    selectedTextColor: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    Keys.onReturnPressed: taskRow.saveTitle()
                    Keys.onEnterPressed: taskRow.saveTitle()
                    Keys.onEscapePressed: (event) => {
                        root.editingId = "";
                        taskRow.forceActiveFocus(Qt.OtherFocusReason);
                        event.accepted = true;
                    }
                }

                ShellText {
                    anchors.left: priorityDot.right
                    anchors.leftMargin: 7
                    anchors.right: metadata.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.editingId !== taskRow.task.id
                    text: taskRow.task.text
                    color: taskRow.task.done ? Theme.mutedDark : Theme.foreground
                    font.strikeout: taskRow.task.done
                    elide: Text.ElideRight
                    font.pixelSize: 11
                }

                Rectangle {
                    id: priorityDot

                    anchors.left: checkbox.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5
                    height: 5
                    radius: 3
                    color: taskRow.task.priority && taskRow.task.priority !== "none" ? root.priorityColor(taskRow.task.priority) : "transparent"
                }

                Row {
                    id: metadata

                    anchors.right: detailsButton.left
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7

                    ShellText {
                        visible: !!taskRow.task.category
                        text: "#" + (taskRow.task.category || "")
                        color: Theme.blue
                        font.pixelSize: 9
                    }

                    ShellText {
                        visible: !!taskRow.task.dueDate
                        text: root.dueLabel(taskRow.task.dueDate || "")
                        color: taskRow.task.dueDate < root.today ? Theme.red : Theme.muted
                        font.pixelSize: 9
                    }
                }

                Item {
                    id: detailsButton

                    anchors.right: parent.right
                    width: 20
                    height: parent.height

                    ShellText {
                        anchors.centerIn: parent
                        text: root.detailsId === taskRow.task.id ? "⌄" : "›"
                        color: taskRow.selected ? Theme.primary : Theme.mutedDark
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const wasOpenForThisTask = root.detailsId === taskRow.task.id;
                            taskList.currentIndex = taskRow.index;
                            root.detailsId = wasOpenForThisTask ? "" : taskRow.task.id;
                        }
                    }
                }
            }
        }

        Column {
            id: detailsPane

            width: parent.width
            spacing: 7
            visible: root.detailsTask !== null

            Row {
                width: parent.width
                height: 25
                spacing: 8

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "DETAILS"
                    color: Theme.muted
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }

                Item { width: parent.width - 150; height: 1 }

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Delete"
                    color: Theme.red
                    font.pixelSize: 9

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -7
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ShellState.removeTodo(root.detailsIndex);
                            root.detailsId = "";
                        }
                    }
                }

                ShellText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Close"
                    color: Theme.muted
                    font.pixelSize: 9

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -7
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.detailsId = ""
                    }
                }
            }

            Row {
                width: parent.width
                height: 30
                spacing: 12

                FocusScope {
                    id: priorityButton

                    width: 105
                    height: parent.height
                    activeFocusOnTab: true
                    Keys.onReturnPressed: root.cyclePriority()
                    Keys.onEnterPressed: root.cyclePriority()
                    Keys.onSpacePressed: root.cyclePriority()

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: root.detailsTask ? root.priorityColor(root.detailsTask.priority) : Theme.bg3
                    }

                    ShellText {
                        anchors.left: parent.left
                        anchors.leftMargin: 13
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Priority: " + (root.detailsTask ? (root.detailsTask.priority || "none") : "none")
                        color: priorityButton.activeFocus ? Theme.foreground : Theme.muted
                        font.pixelSize: 9
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cyclePriority()
                    }
                }

                Item {
                    width: parent.width - 117
                    height: parent.height

                    ShellText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "#"
                        color: Theme.blue
                        font.pixelSize: 10
                    }

                    TextInput {
                        id: categoryInput

                        anchors.left: parent.left
                        anchors.leftMargin: 13
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.detailsTask ? (root.detailsTask.category || "") : ""
                        color: Theme.foreground
                        selectionColor: Theme.primaryContainer
                        selectedTextColor: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        activeFocusOnTab: true
                        onEditingFinished: {
                            if (root.detailsIndex >= 0)
                                ShellState.updateTodo(root.detailsIndex, { "category": text.trim().replace(/^#/, "") });
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 13
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: categoryInput.activeFocus ? 2 : 1
                        color: categoryInput.activeFocus ? Theme.blue : Theme.bg3
                    }
                }
            }

            Row {
                width: parent.width
                height: 30
                spacing: 7

                Repeater {
                    model: [
                        { "label": "Today", "date": root.today },
                        { "label": "Tomorrow", "date": root.tomorrow },
                        { "label": "Clear", "date": "" }
                    ]

                    delegate: ShellText {
                        required property var modelData

                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: root.detailsTask && root.detailsTask.dueDate === modelData.date ? Theme.primary : Theme.muted
                        font.pixelSize: 9

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ShellState.updateTodo(root.detailsIndex, { "dueDate": modelData.date })
                        }
                    }
                }

                Item { width: 12; height: 1 }

                TextInput {
                    id: dateInput

                    width: 82
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.detailsTask ? root.displayDate(root.detailsTask.dueDate || "") : ""
                    color: Theme.foreground
                    selectionColor: Theme.primaryContainer
                    selectedTextColor: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    activeFocusOnTab: true
                    onEditingFinished: {
                        const clean = text.trim();
                        const parsed = root.parseDisplayDate(clean);
                        if (root.detailsIndex >= 0 && (!clean || parsed))
                            ShellState.updateTodo(root.detailsIndex, { "dueDate": clean ? parsed : "" });
                    }

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "DD-MM-YY"
                        visible: !parent.text
                        color: Theme.mutedDark
                        font.pixelSize: 9
                    }
                }
            }

            Item {
                width: parent.width
                height: 58

                ShellText {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: "Notes"
                    color: Theme.mutedDark
                    font.pixelSize: 9
                }

                TextEdit {
                    id: notesInput

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 15
                    anchors.bottom: parent.bottom
                    text: root.detailsTask ? (root.detailsTask.notes || "") : ""
                    color: Theme.foreground
                    selectionColor: Theme.primaryContainer
                    selectedTextColor: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    wrapMode: TextEdit.Wrap
                    activeFocusOnTab: true
                    onActiveFocusChanged: {
                        if (!activeFocus && root.detailsIndex >= 0)
                            ShellState.updateTodo(root.detailsIndex, { "notes": text.trim() });
                    }
                }

            }
        }

        Item {
            width: parent.width
            height: 16
            visible: root.detailsTask === null && ShellState.todos.some((task) => task.done)

            ShellText {
                anchors.right: parent.right
                text: "Clear completed"
                color: Theme.mutedDark
                font.pixelSize: 8

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShellState.clearCompletedTodos()
                }
            }
        }
    }
}
