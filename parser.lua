Parser = {
}

function Parser:new(lexer, camera)
    local parser = {
        lexer = lexer,
        camera = camera,
    }

    setmetatable(parser, self)
    self.__index = self

    return parser
end

function Parser:match(token)
    if self.lexer:next() ~= token then
        error("expected \"" .. token .. "\"")
    end
end

function Parser:has(token)
    return self.lexer:peek() == token
end

function Parser:list(parent, parse_function, start_i, finish_token, separator)
    local i = start_i

    while not self:has(finish_token) do
        if separator and i > start_i then
            self:match(separator)
        end

        parent.children[i] = parse_function(self, parent)

        i = i + 1
    end

    self.lexer:next()
end

--- Specific parse functions:

function Parser:parse_do(parent)
    self:match("do")

    local do_block = Block:new(Block.DO, parent)

    local child_i = 1
    while not self:has("end") do
        local statement = self:statement(do_block)
        do_block.children[child_i] = statement
        child_i = child_i + 1
    end

    return do_block
end

function Parser:parse_case(parent)
    local case = Block:new(Block.CASE, parent)
    local condition = self:expression(case)
    case.children[1] = condition
    self:match("then")

    local i = 2
    while not self:has("elseif") and not self:has("else") and not self:has("end") do
        case.children[i] = self:statement(case)

        i = i + 1
    end

    return case
end

function Parser:parse_if_cases(parent)
    local if_cases = Block:new(Block.IF_CASES, parent)

    local i = 1
    while not self:has("else") and not self:has("end") do
        if i == 1 then
            self:match("if")
        else
            self:match("elseif")
        end

        if_cases.children[i] = self:parse_case(if_cases)

        i = i + 1
    end

    return if_cases
end

function Parser:parse_else_case(parent)
    self:match("else")

    local else_case = Block:new(Block.ELSE_CASE, parent)

    self:list(else_case, Parser.statement, 1, "end")

    return else_case
end

function Parser:parse_if(parent)
    local if_block = Block:new(Block.IF, parent)

    if_block.children[1] = self:parse_if_cases(if_block)

    if self:has("else") then
        if_block.children[2] = self:parse_else_case(if_block)
    else
        self:match("end")
    end

    return if_block
end

function Parser:parse_statement_list(parent)
    local statement_list = Block:new(Block.STATEMENT_LIST, parent)

    self:list(statement_list, Parser.statement, 1, "end")

    return statement_list
end

function Parser:parse_function_header(parent)
    local function_header = Block:new(Block.FUNCTION_HEADER, parent)

    self:match("function")

    function_header.children[1] = self:identifier(function_header)

    self:match("(")
    self:list(function_header, Parser.identifier, 2, ")", ",")

    return function_header
end

function Parser:parse_function(parent)
    local function_block = Block:new(Block.FUNCTION, parent)

    function_block.children[1] = self:parse_function_header(function_block)
    function_block.children[2] = self:parse_statement_list(function_block)

    return function_block
end

function Parser:parse_lambda_function_header(parent)
    local lambda_function_header = Block:new(Block.LAMBDA_FUNCTION_HEADER, parent)

    self:match("function")

    self:match("(")
    self:list(lambda_function_header, Parser.identifier, 1, ")", ",")

    return lambda_function_header
end

function Parser:parse_lambda_function(parent)
    local lambda_function = Block:new(Block.LAMBDA_FUNCTION, parent)

    lambda_function.children[1] = self:parse_lambda_function_header(lambda_function)
    lambda_function.children[2] = self:parse_statement_list(lambda_function)

    return lambda_function
end

function Parser:parse_addition(parent)
    local left = self:parse_unary_suffix(parent)

    if not self:has("+") then
        return left
    end

    local add = Block:new(Block.ADD, parent)
    left.parent = add
    add.children[1] = left

    local child_i = 2
    while self:has("+") do
        self.lexer:next()

        local expression = self:parse_unary_suffix(add)

        add.children[child_i] = expression
        child_i = child_i + 1
    end

    return add
end

function Parser:parse_unary_suffix(parent)
    local left = self:parse_primary(parent)

    while self:has("(") do
        -- This is a call.
        self.lexer:next()

        local call = Block:new(Block.CALL, parent)
        left.parent = call
        call.children[1] = left

        local child_i = 2
        while not self:has(")") do
            local expression = self:expression(call)
            call.children[child_i] = expression
            child_i = child_i + 1

            if not self:has(",") then
                break
            end

            self.lexer:next()
        end

        self:match(")")

        left = call
    end

    return left
end

function Parser:parse_primary(parent)
    if self:has("function") then
        return self:parse_lambda_function(parent)
    end

    return self:identifier(parent)
end

local PARSE_FUNCTION_FROM_START = {
    ["do"] = Parser.parse_do,
    ["if"] = Parser.parse_if,
    ["function"] = Parser.parse_function,
}

--- Pin kinds:

function Parser:expression(parent)
    return self:parse_addition(parent)
end

function Parser:statement(parent)
    local start_text = self.lexer:peek()

    local parse_function = PARSE_FUNCTION_FROM_START[start_text]

    if parse_function then
        return parse_function(self, parent)
    end

    local expression = self:expression(parent)

    if not self:has("=") then
        return expression
    end

    self.lexer:next()

    local assignment = Block:new(Block.ASSIGNMENT, parent)
    expression.parent = assignment
    local right_expression = self:expression(assignment)
    assignment.children[1] = expression
    assignment.children[2] = right_expression

    return assignment
end

-- TODO: Simplify identifiers, ie: table.field should not be an identifier, it should be (. table field) where table and field are separate identifiers.
function Parser:identifier(parent)
    local text = self.lexer:next()

    local block = Block:new(Block.IDENTIFIER, parent)
    block.text = text
    block:update_text_size(self.camera)

    return block
end