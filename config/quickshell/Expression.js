.pragma library

function evaluate(source) {
    const input = source.replace(/×/g, "*").replace(/÷/g, "/").replace(/\s+/g, "");
    if (!input || input.length > 256 || !/^[0-9.+\-*/%()]+$/.test(input))
        return null;

    let index = 0;

    function parseNumber() {
        const match = input.slice(index).match(/^(?:\d+(?:\.\d*)?|\.\d+)/);
        if (!match)
            return null;

        index += match[0].length;
        const value = Number(match[0]);
        return Number.isFinite(value) ? value : null;
    }

    function parsePrimary() {
        if (input[index] !== "(")
            return parseNumber();

        index++;
        const value = parseExpression();
        if (value === null || input[index] !== ")")
            return null;

        index++;
        return value;
    }

    function parseUnary() {
        if (input[index] === "+") {
            index++;
            return parseUnary();
        }
        if (input[index] === "-") {
            index++;
            const value = parseUnary();
            return value === null ? null : -value;
        }
        return parsePrimary();
    }

    function parseTerm() {
        let value = parseUnary();
        if (value === null)
            return null;

        while (index < input.length && "*/%".includes(input[index])) {
            const operator = input[index++];
            const right = parseUnary();
            if (right === null || ((operator === "/" || operator === "%") && right === 0))
                return null;

            if (operator === "*") value *= right;
            if (operator === "/") value /= right;
            if (operator === "%") value %= right;
        }
        return value;
    }

    function parseExpression() {
        let value = parseTerm();
        if (value === null)
            return null;

        while (index < input.length && "+-".includes(input[index])) {
            const operator = input[index++];
            const right = parseTerm();
            if (right === null)
                return null;

            value = operator === "+" ? value + right : value - right;
        }
        return value;
    }

    const result = parseExpression();
    if (result === null || index !== input.length || !Number.isFinite(result))
        return null;
    return Math.round(result * 100000000) / 100000000;
}
