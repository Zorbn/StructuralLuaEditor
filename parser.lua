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

--- Specific parse functions:

function Parser:parse_do(parent)
    local do_block = Block:new(Block.DO, parent)

    while self.lexer:peek() ~= "end" do
        local statement = self:statement(do_block)
        local child_i = do_block:expand_group(1)
        do_block.child_groups[1][child_i] = statement
    end

    return do_block
end

function Parser:parse_if(parent)
    local if_block = Block:new(Block.IF, parent)
    local condition = self:expression(if_block)
    if_block.child_groups[1][1] = condition

    if self.lexer:next() ~= "then" then
        error("expected \"then\" after if condition")
    end

    local statement = self:statement(if_block)
    if_block.child_groups[1][2] = statement

    local end_or_else = self.lexer:next()
    if end_or_else == "end" then
        return if_block
    elseif end_or_else ~= "else" then
        error("expected \"else\" after if statement")
    end

    local else_statement = self:statement(if_block)
    if_block.child_groups[1][3] = else_statement

    return if_block
end

function Parser:parse_function(parent, is_lambda)
    local function_block = Block:new(Block.FUNCTION, parent)

    if not is_lambda then
        function_block.child_groups[1][1] = self:identifier(function_block)
    end

    if self.lexer:next() ~= "(" then
        error("expected opening ( in function")
    end

    while self.lexer:peek() ~= ")" do
        local identifier = self:identifier(function_block)
        local child_i = function_block:expand_group(1)
        function_block.child_groups[1][child_i] = identifier

        if self.lexer:peek() ~= "," then
            break
        end

        self.lexer:next()
    end

    if self.lexer:next() ~= ")" then
        error("expected closing ) in function")
    end

    while self.lexer:peek() ~= "end" do
        local statement = self:statement(function_block)
        local child_i = function_block:expand_group(2)
        function_block.child_groups[2][child_i] = statement
    end

    self.lexer:next()

    return function_block
end

function Parser:parse_addition(parent)
    local left = self:parse_unary_suffix(parent)

    if self.lexer:peek() ~= "+" then
        return left
    end

    local add = Block:new(Block.ADD, parent)
    left.parent = add
    add.child_groups[1][1] = left

    local i = 2
    while self.lexer:peek() == "+" do
        self.lexer:next() -- "+"

        local expression = self:parse_unary_suffix(add)

        local child_i = i
        if i > 2 then
            child_i = add:expand_group(1)
        end

        add.child_groups[1][child_i] = expression

        i = i + 1
    end

    return add
end

function Parser:parse_unary_suffix(parent)
    local left = self:parse_primary(parent)

    while self.lexer:peek() == "(" do
        -- This is a call.

        self.lexer:next() -- "("

        local call = Block:new(Block.CALL, parent)
        left.parent = call
        call.child_groups[1][1] = left

        while self.lexer:peek() ~= ")" do
            local expression = self:expression(call)
            local child_i = call:expand_group(1)
            call.child_groups[1][child_i] = expression

            if self.lexer:peek() ~= "," then
                break
            end

            self.lexer:next()
        end

        if self.lexer:next() ~= ")" then
            error("expected closing ) in call")
        end

        left = call
    end

    return left
end

function Parser:parse_primary(parent)
    if self.lexer:peek() == "function" then
        return self:parse_function(parent, true)
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
        self.lexer:next()
        return parse_function(self, parent)
    end

    local expression = self:expression(parent)

    if self.lexer:peek() ~= "=" then
        return expression
    end

    self.lexer:next() -- =

    local assignment = Block:new(Block.ASSIGNMENT, parent)
    expression.parent = assignment
    local right_expression = self:expression(assignment)
    assignment.child_groups[1][1] = expression
    assignment.child_groups[1][2] = right_expression

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