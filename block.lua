PinKind = {
    EXPRESSION = 1,
    STATEMENT = 2,
    IDENTIFIER = 3,
}

local function new_block(block)
    block.TEXT_WIDTH = lyte.get_text_width(block.TEXT)
    block.TEXT_HEIGHT = lyte.get_text_height(block.TEXT)

    return block
end

lyte.set_font(Graphics.code_font)

Block = {
    PADDING = 6,
    LINE_WIDTH = 3,
}

Block.PIN = new_block({
    PIN_KIND = nil,
    TEXT = ".",
    DEFAULT_CHILDREN = {},
})

local function new_default_child(block_kind)
    return {
        block_kind = block_kind,
        pin_kind = block_kind.PIN_KIND,
    }
end

local function new_default_child_pin(pin_kind)
    return {
        block_kind = Block.PIN,
        pin_kind = pin_kind,
    }
end

Block.DO = new_block({
    PIN_KIND = PinKind.STATEMENT,
    SEARCH_TEXT = "do",
    TEXT = "do",
    IS_VERTICAL = true,
    IS_GROWABLE = true,
    DEFAULT_CHILDREN = {
        new_default_child_pin(PinKind.STATEMENT),
    },
})

Block.STATEMENT_LIST = new_block({
    PIN_KIND = nil,
    TEXT = "",
    IS_VERTICAL = true,
    IS_GROWABLE = true,
    DEFAULT_CHILDREN = {
        new_default_child_pin(PinKind.STATEMENT),
    },
})

Block.FUNCTION_HEADER = new_block({
    PIN_KIND = nil,
    TEXT = "fn",
    IS_GROWABLE = true,
    DEFAULT_CHILDREN = {
        new_default_child_pin(PinKind.IDENTIFIER),
        new_default_child_pin(PinKind.IDENTIFIER),
    },
})

Block.FUNCTION = new_block({
    PIN_KIND = PinKind.STATEMENT,
    SEARCH_TEXT = "fn",
    TEXT = "",
    IS_VERTICAL = true,
    DEFAULT_CHILDREN = {
        new_default_child(Block.FUNCTION_HEADER),
        new_default_child(Block.STATEMENT_LIST),
    },
})

Block.LAMBDA_FUNCTION_HEADER = new_block({
    PIN_KIND = nil,
    TEXT = "fn",
    IS_GROWABLE = true,
    DEFAULT_CHILDREN = {
        new_default_child_pin(PinKind.IDENTIFIER),
    },
})

Block.LAMBDA_FUNCTION = new_block({
    PIN_KIND = PinKind.EXPRESSION,
    SEARCH_TEXT = "fn",
    TEXT = "",
    IS_VERTICAL = true,
    DEFAULT_CHILDREN = {
        new_default_child(Block.LAMBDA_FUNCTION_HEADER),
        new_default_child(Block.STATEMENT_LIST),
    },
})

Block.CASE = new_block({
    PIN_KIND = nil,
    TEXT = "case",
    IS_VERTICAL = true,
    IS_GROWABLE = true,
    DEFAULT_CHILDREN = {
        new_default_child_pin(PinKind.EXPRESSION),
        new_default_child_pin(PinKind.STATEMENT),
    },
})

Block.IF_CASES = new_block({
    PIN_KIND = nil,
    TEXT = "if",
    IS_VERTICAL = true,
    IS_GROWABLE = true,
    DEFAULT_CHILDREN = {
        new_default_child(Block.CASE),
    },
})

Block.ELSE_CASE = new_block({
    PIN_KIND = nil,
    TEXT = "else",
    IS_VERTICAL = true,
    IS_GROWABLE = true,
    DEFAULT_CHILDREN = {
        new_default_child_pin(PinKind.STATEMENT),
    },
})

Block.IF = new_block({
    PIN_KIND = PinKind.STATEMENT,
    SEARCH_TEXT = "if",
    TEXT = "",
    IS_VERTICAL = true,
    DEFAULT_CHILDREN = {
        new_default_child(Block.IF_CASES),
        new_default_child(Block.ELSE_CASE),
    },
})

Block.ASSIGNMENT = new_block({
    PIN_KIND = PinKind.STATEMENT,
    SEARCH_TEXT = "=",
    TEXT = "=",
    IS_TEXT_INFIX = true,
    DEFAULT_CHILDREN = {
        new_default_child_pin(PinKind.EXPRESSION),
        new_default_child_pin(PinKind.EXPRESSION),
    },
})

Block.ADD = new_block({
    PIN_KIND = PinKind.EXPRESSION,
    TEXT = "+",
    IS_TEXT_INFIX = true,
    IS_GROWABLE = true,
    DEFAULT_CHILDREN = {
        new_default_child_pin(PinKind.EXPRESSION),
        new_default_child_pin(PinKind.EXPRESSION),
        new_default_child_pin(PinKind.EXPRESSION),
    },
})

Block.CALL = new_block({
    PIN_KIND = PinKind.EXPRESSION,
    SEARCH_TEXT = "call",
    TEXT = "call",
    IS_GROWABLE = true,
    DEFAULT_CHILDREN = {
        new_default_child_pin(PinKind.EXPRESSION),
        new_default_child_pin(PinKind.EXPRESSION),
    },
})

Block.IDENTIFIER = new_block({
    PIN_KIND = PinKind.IDENTIFIER,
    TEXT = "",
    DEFAULT_CHILDREN = {},
})

PIN_BLOCKS = {
    [PinKind.EXPRESSION] = {
        Block.LAMBDA_FUNCTION,
        Block.ADD,
        Block.CALL,
    },
    [PinKind.STATEMENT] = {
        Block.ASSIGNMENT,
        Block.DO,
        Block.FUNCTION,
        Block.IF,
        Block.CALL,
    },
    [PinKind.IDENTIFIER] = {
        Block.IDENTIFIER,
    },
}

function Block:new(kind, parent)
    local block = {
        text = "",
        text_width = 0,
        text_height = 0,
        pin_kind = kind.PIN_KIND,
        kind = kind,
        parent = parent,
        children = {},
        x = 0,
        y = 0,
        width = 0,
        height = 0,
    }

    for i, default_child in ipairs(kind.DEFAULT_CHILDREN) do
        local block_kind = default_child.block_kind

        block.children[i] = Block:new(block_kind, block)
        block.children[i].pin_kind = default_child.pin_kind
    end

    setmetatable(block, self)
    self.__index = self

    return block
end

function Block:can_swap_with(other)
    return self.kind == other.kind or (self.pin_kind ~= nil and self.pin_kind == other.pin_kind)
end

function Block:update_text_size(camera)
    lyte.set_font(Graphics.code_font)
    self.text_width = camera:get_text_width(self.text)
    self.text_height = camera:get_text_height(self.text)
end

function Block:update_tree(x, y)
    self.x = x
    self.y = y

    local text_width, text_height
    if self.kind == Block.IDENTIFIER then
        text_width = self.text_width
        text_height = self.text_height
    else
        text_width = self.kind.TEXT_WIDTH
        text_height = self.kind.TEXT_HEIGHT
    end

    local has_child = #self.children > 0

    x = x + Block.PADDING

    if has_child then
        y = y + Block.PADDING
    end

    if not has_child then
        y = y + text_height
    end

    if not self.kind.IS_TEXT_INFIX then
        x = x + text_width + Block.PADDING
    end

    local start_x = x
    local max_width = 0

    if self.kind.IS_VERTICAL then
        for _, child in ipairs(self.children) do
            child:update_tree(x, y)
            x = x + child.width + Block.PADDING
            y = y + child.height + Block.PADDING

            max_width = math.max(max_width, x - self.x)
            x = start_x
        end
    else
        local max_height = 0

        for i, child in ipairs(self.children) do
            child:update_tree(x, y)
            x = x + child.width + Block.PADDING

            if i < #self.children and self.kind.IS_TEXT_INFIX then
                x = x + text_width + Block.PADDING
            end

            max_height = math.max(max_height, child.height + Block.PADDING)
        end

        max_width = math.max(max_width, x - self.x)
        x = start_x
        y = y + max_height
    end

    self.width = max_width
    self.height = y - self.y
end

function Block.get_depth_color(depth)
    if depth % 2 == 0 then
        return Theme.EVEN_COLOR
    end

    return Theme.ODD_COLOR
end

function Block:draw(cursor_block, camera, depth)
    if self == cursor_block then
        Graphics.set_color(Theme.CURSOR_COLOR)

        lyte.draw_rect(self.x - Block.PADDING - Block.LINE_WIDTH, self.y - Block.PADDING - Block.LINE_WIDTH, self.width + Block.LINE_WIDTH * 2,
            self.height + Block.LINE_WIDTH * 2)
    end

    if self.kind == Block.PIN then
        Graphics.set_color(Theme.PIN_COLOR)
    else
        Graphics.set_color(Block.get_depth_color(depth))
    end

    lyte.draw_rect(self.x - Block.PADDING, self.y - Block.PADDING, self.width, self.height)

    Graphics.set_color(Theme.TEXT_COLOR)

    local text
    if self.kind == Block.IDENTIFIER then
        text = self.text
    else
        text = self.kind.TEXT
    end

    local text_y = self.y - Block.PADDING / 2
    local has_child = #self.children > 0

    if not has_child then
        text_y = text_y - Block.PADDING
    end

    if not self.kind.IS_TEXT_INFIX then
        Graphics.draw_text(text, self.x, text_y, camera)
    end

    for i, child in ipairs(self.children) do
        child:draw(cursor_block, camera, depth + 1)

        if i < #self.children and self.kind.IS_TEXT_INFIX then
            Graphics.draw_text(text, child.x + child.width, text_y, camera)
        end
    end
end

function Block:save_pin(_)
end

function Block:save_do(data)
    data:writeln("do")
    data:indent()

    for _, child in ipairs(self.children) do
        child:save(data)
    end

    data:unindent()
    data:writeln("end")
end

function Block:save_block_list(data, first_i, seperator)
    local last_i = #self.children

    for i = first_i, #self.children do
        local child = self.children[i]

        child:save(data)

        if i < last_i then
            data:write(seperator)
        end
    end
end

function Block:save_function(data, is_lambda)
    error("saving function not reimplemented yet")
--     data:write("function ")
--
--     if not is_lambda then
--         self.child_groups[1][1]:save(data)
--     end
--
--     data:write("(")
--
--     local first_i = is_lambda and 1 or 2
--     self:save_block_list(data, first_i, ", ")
--
--     data:writeln(")")
--     data:indent()
--
--     for _, child in ipairs(self.child_groups[2]) do
--         child:save(data)
--     end
--
--     data:unindent()
--     data:writeln("end")
end

function Block:save_lambda_function(data)
    self:save_function(data, true)
end

function Block:save_if(data)
    error("saving if not reimplemented yet")
--     data:write("if ")
--     self.child_groups[1][1]:save(data)
--     data:writeln(" then")
--     self.child_groups[1][2]:save(data)
--
--     if self.child_groups[1][3].kind ~= Block.PIN then
--         data:writeln("else")
--         self.child_groups[1][3]:save(data)
--     end
--
--     data:writeln("end")
end

function Block:save_assignment(data)
    self.children[1]:save(data)
    data:write(" = ")
    self.children[2]:save(data)
    data:newline()
end

function Block:save_add(data)
    self:save_block_list(data, 1, " + ")
end

function Block:save_call(data)
    self.children[1]:save(data)

    data:write("(")

    self:save_block_list(data, 2, ", ")

    data:writeln(")")
end

function Block:save_identifier(data)
    local text = self.text

    if text:sub(1, 1) ~= "\"" then
        text = self.text:gsub(" ", "_")
    end

    data:write(text)
end

local BLOCK_SAVE_FUNCTIONS = {
    [Block.PIN] = Block.save_pin,
    [Block.DO] = Block.save_do,
    [Block.FUNCTION] = Block.save_function,
    [Block.LAMBDA_FUNCTION] = Block.save_lambda_function,
    [Block.IF] = Block.save_if,
    [Block.ASSIGNMENT] = Block.save_assignment,
    [Block.ADD] = Block.save_add,
    [Block.CALL] = Block.save_call,
    [Block.IDENTIFIER] = Block.save_identifier,
}

function Block:save(data)
    BLOCK_SAVE_FUNCTIONS[self.kind](self, data)
end