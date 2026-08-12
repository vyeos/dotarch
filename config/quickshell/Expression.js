.pragma library

function evaluate(source) {
    const input = source.replace(/×/g, "*").replace(/÷/g, "/").replace(/\s+/g, "");
    if (!input || !/^[0-9.+\-*/%()]+$/.test(input))
        return null;

    const tokens = [];
    let index = 0;
    let expectsValue = true;

    while (index < input.length) {
        const char = input[index];
        if (/\d|\./.test(char)) {
            let end = index + 1;
            while (end < input.length && /\d|\./.test(input[end]))
                end++;
            const value = Number(input.slice(index, end));
            if (!Number.isFinite(value))
                return null;
            tokens.push(value);
            index = end;
            expectsValue = false;
        } else if (char === "-" && expectsValue) {
            tokens.push(0);
            tokens.push("-");
            index++;
        } else if ("+-*/%()".includes(char)) {
            tokens.push(char);
            index++;
            expectsValue = char !== ")";
        } else {
            return null;
        }
    }

    const output = [];
    const operators = [];
    const precedence = { "+": 1, "-": 1, "*": 2, "/": 2, "%": 2 };

    for (const token of tokens) {
        if (typeof token === "number") {
            output.push(token);
        } else if (token === "(") {
            operators.push(token);
        } else if (token === ")") {
            while (operators.length && operators[operators.length - 1] !== "(")
                output.push(operators.pop());
            if (operators.pop() !== "(")
                return null;
        } else {
            while (operators.length && precedence[operators[operators.length - 1]] >= precedence[token])
                output.push(operators.pop());
            operators.push(token);
        }
    }

    while (operators.length) {
        const operator = operators.pop();
        if (operator === "(")
            return null;
        output.push(operator);
    }

    const stack = [];
    for (const token of output) {
        if (typeof token === "number") {
            stack.push(token);
            continue;
        }
        if (stack.length < 2)
            return null;
        const right = stack.pop();
        const left = stack.pop();
        if ((token === "/" || token === "%") && right === 0)
            return null;
        if (token === "+") stack.push(left + right);
        if (token === "-") stack.push(left - right);
        if (token === "*") stack.push(left * right);
        if (token === "/") stack.push(left / right);
        if (token === "%") stack.push(left % right);
    }

    if (stack.length !== 1 || !Number.isFinite(stack[0]))
        return null;
    return Math.round(stack[0] * 100000000) / 100000000;
}
