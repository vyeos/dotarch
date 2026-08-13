.pragma library

function block(kind, content, checked) {
    return {
        "kind": kind,
        "content": content || "",
        "checked": checked === true
    };
}

function parseLine(line) {
    const value = String(line || "");
    let match = value.match(/^(#{1,3})\s+(.*)$/);
    if (match)
        return block("h" + match[1].length, match[2], false);

    match = value.match(/^\s*(?:[-*+]\s+)?\[([ xX])\]\s*(.*)$/);
    if (match)
        return block("task", match[2], match[1].toLowerCase() === "x");

    match = value.match(/^\s*[-*+]\s+(.*)$/);
    if (match)
        return block("bullet", match[1], false);

    return block("paragraph", value, false);
}

function parse(markdown) {
    const lines = String(markdown || "").replace(/\r\n?/g, "\n").split("\n");
    if (lines.length > 1 && lines[lines.length - 1] === "")
        lines.pop();
    if (lines.length === 0)
        lines.push("Untitled note");

    const blocks = [];
    for (let index = 0; index < lines.length; index++)
        blocks.push(parseLine(lines[index]));
    return blocks;
}

function serializeBlock(value) {
    if (/^h[1-3]$/.test(value.kind))
        return "#".repeat(Number(value.kind.slice(1))) + " " + value.content;
    if (value.kind === "bullet")
        return "- " + value.content;
    if (value.kind === "task")
        return "- [" + (value.checked ? "x" : " ") + "] " + value.content;
    return value.content;
}

function serialize(blocks) {
    const lines = [];
    for (let index = 0; index < blocks.length; index++)
        lines.push(serializeBlock(blocks[index]));
    return lines.join("\n").replace(/\s+$/, "") + "\n";
}

function typedBlock(kind, content, checked) {
    if (kind !== "paragraph")
        return block(kind, content, checked);
    return parseLine(content);
}
