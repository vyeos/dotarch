#!/usr/bin/env python3

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path


NOTES_DIR = Path(os.environ.get("NOTES_DIR", "~/Notes/Quick")).expanduser()
INDEX_FILE = NOTES_DIR / ".notes-index.json"


def ensure_directory():
    NOTES_DIR.mkdir(parents=True, exist_ok=True)


def load_pins():
    try:
        data = json.loads(INDEX_FILE.read_text(encoding="utf-8"))
        return set(data.get("pinned", []))
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return set()


def save_pins(pins):
    ensure_directory()
    temporary = INDEX_FILE.with_suffix(".tmp")
    temporary.write_text(
        json.dumps({"pinned": sorted(pins)}, indent=2) + "\n",
        encoding="utf-8",
    )
    temporary.replace(INDEX_FILE)


def title_for(path):
    try:
        with path.open(encoding="utf-8") as note:
            for line in note:
                title = line.strip()
                if title:
                    return re.sub(r"^#\s+", "", title)
    except OSError:
        pass
    return path.stem.replace("-", " ").strip().title() or "Untitled note"


def note_record(path, pins):
    stat = path.stat()
    try:
        search_text = path.read_text(encoding="utf-8")
    except OSError:
        search_text = ""
    return {
        "name": path.name,
        "path": str(path),
        "title": title_for(path),
        "modified": int(stat.st_mtime),
        "pinned": path.name in pins,
        "searchText": search_text,
    }


def list_notes():
    ensure_directory()
    pins = load_pins()
    notes = [note_record(path, pins) for path in NOTES_DIR.glob("*.md") if path.is_file()]
    notes.sort(key=lambda note: (not note["pinned"], -note["modified"], note["title"].lower()))
    print(json.dumps(notes, ensure_ascii=False))


def create_note():
    ensure_directory()
    timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
    for suffix in range(1000):
        ending = "" if suffix == 0 else f"-{suffix}"
        path = NOTES_DIR / f"{timestamp}-untitled-note{ending}.md"
        try:
            descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            continue
        with os.fdopen(descriptor, "w", encoding="utf-8") as note:
            note.write("Untitled note\n")
        print(json.dumps(note_record(path, load_pins()), ensure_ascii=False))
        return
    raise RuntimeError("Unable to allocate a unique note filename")


def checked_note_path(raw_path):
    path = Path(raw_path).expanduser().resolve()
    directory = NOTES_DIR.resolve()
    if path.parent != directory or path.suffix.lower() != ".md":
        raise ValueError("Note path is outside the notes directory")
    return path


def delete_note(raw_path):
    path = checked_note_path(raw_path)
    path.unlink(missing_ok=True)
    pins = load_pins()
    if path.name in pins:
        pins.remove(path.name)
        save_pins(pins)


def toggle_pin(raw_path):
    path = checked_note_path(raw_path)
    pins = load_pins()
    if path.name in pins:
        pins.remove(path.name)
    else:
        pins.add(path.name)
    save_pins(pins)


def main():
    if len(sys.argv) < 2:
        raise ValueError("Missing command")
    command = sys.argv[1]
    if command == "list":
        list_notes()
    elif command == "create":
        create_note()
    elif command == "delete" and len(sys.argv) == 3:
        delete_note(sys.argv[2])
    elif command == "toggle-pin" and len(sys.argv) == 3:
        toggle_pin(sys.argv[2])
    else:
        raise ValueError("Unknown or incomplete command")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
