import QtQuick
import Quickshell
import qs
import qs.components
import "../MarkdownBlocks.js" as Markdown

FocusScope {
    id: root

    property int editingIndex: -1
    property int recentIndex: NotesState.notes.length > 0 ? 0 : -1
    property int paletteIndex: 0
    property int historyIndex: -1
    property var history: []
    property bool restoringHistory: false
    property bool confirmingDelete: false
    property bool paletteOpen: false
    readonly property bool editorMode: NotesState.activePath.length > 0
    readonly property var paletteNotes: NotesState.notes.filter((note) => {
        const query = paletteInput.text.trim().toLowerCase();
        const searchable = String(note.searchText || note.title || "").toLowerCase();
        return !query || searchable.includes(query);
    })
    readonly property string markdown: serializeModel()
    readonly property int characterCount: Math.max(0, markdown.replace(/\n$/, "").length)
    readonly property int wordCount: {
        const clean = markdown.replace(/[#*+`>\[\]()-]/g, " ").trim();
        return clean ? clean.split(/\s+/).length : 0;
    }
    readonly property var activeNote: {
        for (let index = 0; index < NotesState.notes.length; index++) {
            if (NotesState.notes[index].path === NotesState.activePath)
                return NotesState.notes[index];
        }
        return null;
    }

    function takeInitialFocus() {
        NotesState.refresh();
        if (editorMode)
            focusBlock(Math.max(0, editingIndex));
        else if (NotesState.notes.length > 0)
            selectRecent(Math.max(0, recentIndex));
        else
            root.forceActiveFocus(Qt.TabFocusReason);
    }

    function createAndOpenNote() {
        if (editorMode)
            saveNow();
        paletteOpen = false;
        NotesState.createNote();
    }

    function selectRecent(index) {
        if (NotesState.notes.length === 0) {
            recentIndex = -1;
            return;
        }
        recentIndex = Math.max(0, Math.min(index, NotesState.notes.length - 1));
        notesList.currentIndex = recentIndex;
        notesList.positionViewAtIndex(recentIndex, ListView.Contain);
        Qt.callLater(() => {
            const item = notesList.itemAtIndex(recentIndex);
            if (item)
                item.forceActiveFocus(Qt.OtherFocusReason);
        });
    }

    function moveRecent(offset) {
        selectRecent((recentIndex < 0 ? (offset > 0 ? -1 : NotesState.notes.length) : recentIndex) + offset);
    }

    function openRecent(index) {
        if (index < 0 || index >= NotesState.notes.length)
            return;
        NotesState.openNote(NotesState.notes[index].path);
    }

    function deleteRecent(index) {
        if (index < 0 || index >= NotesState.notes.length)
            return;
        NotesState.deleteNote(NotesState.notes[index].path);
        recentIndex = Math.min(index, NotesState.notes.length - 2);
    }

    function togglePalette() {
        if (!editorMode)
            return;
        paletteOpen = !paletteOpen;
        if (paletteOpen) {
            paletteInput.clear();
            paletteIndex = 0;
            Qt.callLater(() => paletteInput.forceActiveFocus(Qt.ShortcutFocusReason));
        } else {
            focusBlock(Math.max(0, editingIndex));
        }
    }

    function movePalette(offset) {
        if (paletteNotes.length === 0) {
            paletteIndex = -1;
            return;
        }
        paletteIndex = Math.max(0, Math.min(paletteNotes.length - 1, paletteIndex + offset));
        paletteList.positionViewAtIndex(paletteIndex, ListView.Contain);
    }

    function openPaletteNote(index) {
        if (index < 0 || index >= paletteNotes.length)
            return;
        saveNow();
        paletteOpen = false;
        NotesState.openNote(paletteNotes[index].path);
    }

    function blockObject(index) {
        const value = blockModel.get(index);
        return { "kind": value.kind, "content": value.content, "checked": value.checked };
    }

    function snapshot() {
        const values = [];
        for (let index = 0; index < blockModel.count; index++)
            values.push(blockObject(index));
        return JSON.stringify(values);
    }

    function restoreSnapshot(value) {
        restoringHistory = true;
        const values = JSON.parse(value);
        blockModel.clear();
        for (let index = 0; index < values.length; index++)
            blockModel.append(values[index]);
        restoringHistory = false;
        scheduleSave();
        focusBlock(Math.min(Math.max(0, editingIndex), blockModel.count - 1));
    }

    function pushHistory() {
        if (restoringHistory)
            return;
        const next = snapshot();
        if (historyIndex >= 0 && history[historyIndex] === next)
            return;
        const revised = history.slice(0, historyIndex + 1);
        revised.push(next);
        if (revised.length > 200)
            revised.shift();
        history = revised;
        historyIndex = history.length - 1;
    }

    function undo() {
        if (historyIndex <= 0)
            return;
        historyIndex--;
        restoreSnapshot(history[historyIndex]);
    }

    function redo() {
        if (historyIndex < 0 || historyIndex >= history.length - 1)
            return;
        historyIndex++;
        restoreSnapshot(history[historyIndex]);
    }

    function loadMarkdown(markdown) {
        restoringHistory = true;
        blockModel.clear();
        const values = Markdown.parse(markdown);
        for (let index = 0; index < values.length; index++)
            blockModel.append(values[index]);
        restoringHistory = false;
        history = [snapshot()];
        historyIndex = 0;
        confirmingDelete = false;
        Qt.callLater(() => {
            const lastIndex = Math.max(0, blockModel.count - 1);
            editingIndex = lastIndex;
            focusBlock(lastIndex, false, blockModel.get(lastIndex).content.length);
        });
    }

    function serializeModel() {
        const values = [];
        for (let index = 0; index < blockModel.count; index++)
            values.push(blockObject(index));
        return Markdown.serialize(values);
    }

    function scheduleSave() {
        if (!editorMode || restoringHistory)
            return;
        NotesState.saveStatus = "Unsaved";
        autosave.restart();
    }

    function saveNow() {
        autosave.stop();
        if (editorMode)
            NotesState.save(serializeModel());
    }

    function updateBlock(index, value) {
        if (index < 0 || index >= blockModel.count)
            return;
        const current = blockModel.get(index);
        const parsed = Markdown.typedBlock(current.kind, value, current.checked);
        blockModel.set(index, parsed);
        pushHistory();
        scheduleSave();
        if (parsed.kind !== current.kind || parsed.content !== value) {
            Qt.callLater(() => focusBlock(index, false, parsed.content.length));
        }
    }

    function toggleTask(index) {
        if (index < 0 || index >= blockModel.count)
            return;
        blockModel.setProperty(index, "checked", !blockModel.get(index).checked);
        pushHistory();
        scheduleSave();
    }

    function handleReturn(index) {
        const current = blockModel.get(index);
        if ((current.kind === "bullet" || current.kind === "task") && !current.content.trim()) {
            blockModel.set(index, { "kind": "paragraph", "content": "", "checked": false });
            pushHistory();
            scheduleSave();
            focusBlock(index);
            return;
        }
        const nextKind = current.kind === "bullet" || current.kind === "task" ? current.kind : "paragraph";
        blockModel.insert(index + 1, { "kind": nextKind, "content": "", "checked": false });
        pushHistory();
        scheduleSave();
        focusBlock(index + 1);
    }

    function handleBackspace(index) {
        if (index <= 0 || blockModel.get(index).content.length > 0)
            return false;
        const current = blockModel.get(index);
        if (current.kind === "bullet" || current.kind === "task" || /^h[1-3]$/.test(current.kind)) {
            blockModel.set(index, { "kind": "paragraph", "content": "", "checked": false });
            pushHistory();
            scheduleSave();
            focusBlock(index);
            return true;
        }
        blockModel.remove(index);
        pushHistory();
        scheduleSave();
        focusBlock(index - 1, false, blockModel.get(index - 1).content.length);
        return true;
    }

    function focusBlock(index, selectAll, cursorPosition) {
        if (blockModel.count === 0)
            return;
        editingIndex = Math.max(0, Math.min(index, blockModel.count - 1));
        Qt.callLater(() => {
            const item = blockList.itemAtIndex(editingIndex);
            if (!item || typeof item.beginEditing !== "function")
                return;
            blockList.positionViewAtIndex(editingIndex, ListView.Contain);
            item.beginEditing(selectAll === true, cursorPosition);
        });
    }

    function closeEditor() {
        saveNow();
        editingIndex = -1;
        NotesState.closeNote();
        NotesState.refresh();
        Qt.callLater(() => {
            if (NotesState.notes.length > 0)
                selectRecent(Math.max(0, recentIndex));
            else
                root.forceActiveFocus(Qt.OtherFocusReason);
        });
    }

    function copyMarkdown() {
        Quickshell.clipboardText = serializeModel();
        NotesState.saveStatus = "Copied";
        copiedStatusReset.restart();
    }

    implicitWidth: 472
    implicitHeight: 430

    Keys.onPressed: (event) => {
        if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_N) {
            createAndOpenNote();
            event.accepted = true;
        } else if (editorMode && (event.modifiers & Qt.AltModifier) && event.key === Qt.Key_P) {
            togglePalette();
            event.accepted = true;
        } else if (!editorMode && (event.key === Qt.Key_Down || event.key === Qt.Key_J)) {
            moveRecent(1);
            event.accepted = true;
        } else if (!editorMode && (event.key === Qt.Key_Up || event.key === Qt.Key_K)) {
            moveRecent(-1);
            event.accepted = true;
        } else if (!editorMode && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            openRecent(recentIndex);
            event.accepted = true;
        } else if (!editorMode && event.key === Qt.Key_Delete) {
            deleteRecent(recentIndex);
            event.accepted = true;
        } else if (editorMode && (event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
            saveNow();
            event.accepted = true;
        } else if (editorMode && (event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z && (event.modifiers & Qt.ShiftModifier)) {
            redo();
            event.accepted = true;
        } else if (editorMode && (event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
            undo();
            event.accepted = true;
        } else if (editorMode && (event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Y) {
            redo();
            event.accepted = true;
        }
    }

    Connections {
        target: NotesState
        function onNotesChanged() {
            if (NotesState.notes.length === 0)
                root.recentIndex = -1;
            else
                root.recentIndex = Math.max(0, Math.min(root.recentIndex, NotesState.notes.length - 1));
            root.paletteIndex = Math.max(0, Math.min(root.paletteIndex, root.paletteNotes.length - 1));
            if (!root.editorMode && NotesState.notes.length > 0)
                Qt.callLater(() => root.selectRecent(root.recentIndex));
        }
        function onActivePathChanged() {
            if (!NotesState.activePath)
                root.paletteOpen = false;
        }
        function onLoadRevisionChanged() {
            if (NotesState.activePath)
                root.loadMarkdown(NotesState.activeText);
        }
    }

    ListModel { id: blockModel }

    Shortcut {
        sequence: "Alt+N"
        enabled: root.visible
        onActivated: root.createAndOpenNote()
    }

    Shortcut {
        sequence: "Alt+P"
        enabled: root.visible && root.editorMode
        onActivated: root.togglePalette()
    }

    Timer {
        id: autosave
        interval: 400
        onTriggered: root.saveNow()
    }

    Timer {
        id: copiedStatusReset
        interval: 1200
        onTriggered: {
            if (NotesState.saveStatus === "Copied")
                NotesState.saveStatus = "Saved";
        }
    }

    Timer {
        id: deleteConfirmationReset
        interval: 3500
        onTriggered: root.confirmingDelete = false
    }

    Column {
        anchors.fill: parent
        spacing: 8

        Item {
            width: parent.width
            height: 30

            ShellText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.editorMode ? "‹  Quick Notes" : "Quick Notes"
                font.pixelSize: 14
                font.weight: Font.Bold

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    enabled: root.editorMode
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.closeEditor()
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7
                visible: root.editorMode

                ShellText {
                    width: 22
                    height: 22
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.activeNote && root.activeNote.pinned ? "󰐃" : "󰤱"
                    color: root.activeNote && root.activeNote.pinned ? Theme.yellow : Theme.foreground
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 15
                    Accessible.role: Accessible.Button
                    Accessible.name: root.activeNote && root.activeNote.pinned ? "Unpin note" : "Pin note"
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotesState.togglePin(NotesState.activePath)
                    }
                }

                ShellText {
                    width: 22
                    height: 22
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "󰆏"
                    color: Theme.foreground
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 15
                    Accessible.role: Accessible.Button
                    Accessible.name: "Copy as Markdown"
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyMarkdown()
                    }
                }

                ShellText {
                    width: 22
                    height: 22
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "󰆴"
                    color: root.confirmingDelete ? Theme.red : Theme.muted
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 15
                    Accessible.role: Accessible.Button
                    Accessible.name: root.confirmingDelete ? "Confirm delete note" : "Delete note"
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.confirmingDelete) {
                                autosave.stop();
                                NotesState.deleteNote(NotesState.activePath);
                                root.confirmingDelete = false;
                            } else {
                                root.confirmingDelete = true;
                                deleteConfirmationReset.restart();
                            }
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: parent.height - 68
            visible: !root.editorMode

            Column {
                anchors.fill: parent

                ListView {
                    id: notesList
                    width: parent.width
                    height: parent.height
                    model: NotesState.notes
                    currentIndex: root.recentIndex
                    spacing: 3
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ShellText {
                        anchors.centerIn: parent
                        visible: notesList.count === 0
                        text: NotesState.lastError || "No notes yet."
                        color: NotesState.lastError ? Theme.red : Theme.mutedDark
                        font.pixelSize: 10
                    }

                    delegate: FocusScope {
                        id: noteRow
                        required property var modelData
                        required property int index
                        readonly property bool selected: root.recentIndex === index
                        width: ListView.view.width
                        height: 44
                        activeFocusOnTab: true
                        Keys.onReturnPressed: NotesState.openNote(modelData.path)
                        Keys.onEnterPressed: NotesState.openNote(modelData.path)

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSmall
                            color: noteRow.selected || noteRow.activeFocus || notePointer.containsMouse ? Theme.primaryContainer : "transparent"
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.right: pinMark.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            ShellText {
                                width: parent.width
                                text: noteRow.modelData.title
                                elide: Text.ElideRight
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            ShellText {
                                text: Qt.formatDateTime(new Date(noteRow.modelData.modified * 1000), "ddd d MMM · HH:mm")
                                color: Theme.mutedDark
                                font.pixelSize: 8
                            }
                        }

                        ShellText {
                            id: pinMark
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰐃"
                            visible: noteRow.modelData.pinned
                            color: Theme.yellow
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: notePointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.recentIndex = noteRow.index;
                                NotesState.openNote(noteRow.modelData.path);
                            }
                        }
                    }
                }
            }
        }

        ListView {
            id: blockList
            width: parent.width
            height: parent.height - 68
            visible: root.editorMode
            model: blockModel
            spacing: 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: blockRow
                required property string kind
                required property string content
                required property bool checked
                required property int index
                readonly property bool active: root.editingIndex === index
                readonly property int markerWidth: kind === "bullet" || kind === "task" ? 25 : 4
                readonly property int minimumHeight: /^h[1-3]$/.test(kind) ? 23 : 18

                function beginEditing(selectAll, requestedCursor) {
                    root.editingIndex = index;
                    blockEditor.text = content;
                    blockEditor.forceActiveFocus(Qt.OtherFocusReason);
                    if (selectAll)
                        blockEditor.selectAll();
                    else
                        blockEditor.cursorPosition = requestedCursor === undefined ? blockEditor.length : Math.min(requestedCursor, blockEditor.length);
                }

                width: ListView.view.width
                height: Math.max(minimumHeight, blockEditor.contentHeight + 1, renderedText.implicitHeight + 1)

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: "transparent"
                }

                Rectangle {
                    visible: blockRow.kind === "task"
                    x: 5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    radius: 3
                    color: blockRow.checked ? Theme.primary : "transparent"
                    border.width: 1
                    border.color: blockRow.checked ? Theme.primary : Theme.mutedDark

                    ShellText {
                        anchors.centerIn: parent
                        text: blockRow.checked ? "✓" : ""
                        color: Theme.bgDim
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleTask(blockRow.index)
                    }
                }

                ShellText {
                    visible: blockRow.kind === "bullet"
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "•"
                    color: Theme.primary
                    font.pixelSize: 13
                }

                Text {
                    id: renderedText
                    x: blockRow.markerWidth
                    width: parent.width - x - 5
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !blockRow.active
                    text: blockRow.content || "Click to write…"
                    textFormat: Text.MarkdownText
                    wrapMode: Text.Wrap
                    lineHeight: 0.9
                    lineHeightMode: Text.ProportionalHeight
                    color: blockRow.checked ? Theme.mutedDark : (blockRow.content ? Theme.foreground : Theme.mutedDark)
                    font.family: Theme.fontFamily
                    font.pixelSize: blockRow.kind === "h1" ? 20 : (blockRow.kind === "h2" ? 18 : (blockRow.kind === "h3" ? 15 : 12))
                    font.weight: /^h[1-3]$/.test(blockRow.kind) ? Font.Bold : Font.Normal
                    font.strikeout: blockRow.kind === "task" && blockRow.checked
                    linkColor: Theme.blue

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: renderedText.linkAt(mouseX, mouseY) ? Qt.PointingHandCursor : Qt.IBeamCursor
                        onClicked: (mouse) => {
                            const link = renderedText.linkAt(mouse.x, mouse.y);
                            if (link)
                                Qt.openUrlExternally(link);
                            else
                                blockRow.beginEditing(false);
                        }
                    }
                }

                TextEdit {
                    id: blockEditor
                    x: blockRow.markerWidth
                    width: parent.width - x - 5
                    anchors.verticalCenter: parent.verticalCenter
                    visible: blockRow.active
                    text: blockRow.content
                    textFormat: TextEdit.PlainText
                    wrapMode: TextEdit.Wrap
                    color: Theme.foreground
                    selectionColor: Theme.primaryContainer
                    selectedTextColor: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: blockRow.kind === "h1" ? 20 : (blockRow.kind === "h2" ? 18 : (blockRow.kind === "h3" ? 15 : 12))
                    font.weight: /^h[1-3]$/.test(blockRow.kind) ? Font.Bold : Font.Normal
                    onTextEdited: root.updateBlock(blockRow.index, text)

                    Keys.onPressed: (event) => {
                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z && (event.modifiers & Qt.ShiftModifier)) {
                            root.redo();
                            event.accepted = true;
                        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
                            root.undo();
                            event.accepted = true;
                        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Y) {
                            root.redo();
                            event.accepted = true;
                        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
                            root.saveNow();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.handleReturn(blockRow.index);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Backspace && text.length === 0) {
                            event.accepted = root.handleBackspace(blockRow.index);
                        } else if (event.key === Qt.Key_Up && blockRow.index > 0) {
                            root.focusBlock(blockRow.index - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down && blockRow.index < blockModel.count - 1) {
                            root.focusBlock(blockRow.index + 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            root.editingIndex = -1;
                            root.forceActiveFocus(Qt.OtherFocusReason);
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 20
            visible: root.editorMode

            ShellText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: NotesState.saveStatus
                color: NotesState.saveStatus === "Save failed" ? Theme.red : Theme.mutedDark
                font.pixelSize: 8
            }

            ShellText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.wordCount + (root.wordCount === 1 ? " word" : " words") + "  ·  " + root.characterCount + (root.characterCount === 1 ? " character" : " characters")
                color: Theme.mutedDark
                font.pixelSize: 8
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 20
        visible: root.paletteOpen
        radius: Theme.radius
        color: Theme.bgDim

        MouseArea {
            anchors.fill: parent
            onClicked: paletteInput.forceActiveFocus(Qt.MouseFocusReason)
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 9

            Item {
                width: parent.width
                height: 38

                TextInput {
                    id: paletteInput
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 4
                    rightPadding: 4
                    color: Theme.foreground
                    selectionColor: Theme.primaryContainer
                    selectedTextColor: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    activeFocusOnTab: true
                    onTextEdited: {
                        root.paletteIndex = root.paletteNotes.length > 0 ? 0 : -1;
                        paletteList.positionViewAtBeginning();
                    }

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search recent notes…"
                        visible: !parent.text
                        color: Theme.mutedDark
                        font.pixelSize: 11
                    }

                    Keys.onPressed: (event) => {
                        if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_N) {
                            root.createAndOpenNote();
                            event.accepted = true;
                        } else if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_P) {
                            root.togglePalette();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            root.movePalette(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            root.movePalette(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.openPaletteNote(root.paletteIndex);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Delete && !text.length && root.paletteIndex >= 0) {
                            const deleting = root.paletteNotes[root.paletteIndex];
                            NotesState.deleteNote(deleting.path);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            root.togglePalette();
                            event.accepted = true;
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 2
                    color: Theme.primary
                }
            }

            ListView {
                id: paletteList
                width: parent.width
                height: parent.height - 47
                model: root.paletteNotes
                currentIndex: root.paletteIndex
                spacing: 3
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ShellText {
                    anchors.centerIn: parent
                    visible: paletteList.count === 0
                    text: "No matching notes"
                    color: Theme.mutedDark
                    font.pixelSize: 10
                }

                delegate: Item {
                    id: paletteRow
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 42

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: root.paletteIndex === paletteRow.index ? Theme.primaryContainer : "transparent"
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 9
                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        ShellText {
                            width: parent.width
                            text: (paletteRow.modelData.pinned ? "󰐃  " : "") + paletteRow.modelData.title
                            color: paletteRow.modelData.pinned ? Theme.yellow : Theme.foreground
                            elide: Text.ElideRight
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }

                        ShellText {
                            text: Qt.formatDateTime(new Date(paletteRow.modelData.modified * 1000), "ddd d MMM · HH:mm")
                            color: Theme.mutedDark
                            font.pixelSize: 8
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.paletteIndex = paletteRow.index
                        onClicked: root.openPaletteNote(paletteRow.index)
                    }
                }
            }
        }
    }
}
