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
    SEARCH_TEXT = "+",
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
        kind = kind,
        parent = parent,
        x = 0,
        y = 0,
        width = 0,
        height = 0,
    }

    if #kind.DEFAULT_CHILDREN > 0 then
        block.children = {}

        for i, default_child in ipairs(kind.DEFAULT_CHILDREN) do
            local block_kind = default_child.block_kind

            block.children[i] = Block:new(block_kind, block)
        end
    end

    setmetatable(block, self)
    self.__index = self

    return block
end

function Block:get_text()
    if self.text then
        return self.text
    end

    return self.kind.TEXT
end

function Block:get_text_width()
    if self.text_width then
        return self.text_width
    end

    return self.kind.TEXT_WIDTH
end

function Block:get_text_height()
    if self.text_height then
        return self.text_height
    end

    return self.kind.TEXT_HEIGHT
end

-- Deep copy.
function Block:copy()
    local copy_block = {
        kind = self.kind,
        parent = self.parent,
        x = self.x,
        y = self.y,
        width = self.width,
        height = self.height,
    }

    if self.text then
        copy_block.text = self.text
    end

    if self.text_width then
        copy_block.text_width = self.text_width
    end

    if self.text_height then
        copy_block.text_height = self.text_height
    end

    setmetatable(copy_block, Block)
    Block.__index = Block

    if self.children then
        copy_block.children = {}

        for i, child in ipairs(self.children) do
            copy_block.children[i] = child:copy()
        end
    end

    return copy_block
end

function Block:can_swap_with(other)
    return self.kind == other.kind or (self.kind.PIN_KIND ~= nil and self.kind.PIN_KIND == other.kind.PIN_KIND)
end

function Block:contains_non_pin()
    if not self.children then
        return false
    end

    for _, child in ipairs(self.children) do
        if child.kind ~= Block.PIN then
            return true
        end
    end

    return false
end

function Block:update_text_size(camera)
    lyte.set_font(Graphics.code_font)
    self.text_width = camera:get_text_width(self:get_text())
    self.text_height = camera:get_text_height(self:get_text())
end

function Block:update_tree(x, y)
    self.x = x
    self.y = y

    local has_child = self.children and #self.children > 0

    x = x + Block.PADDING

    if has_child then
        y = y + Block.PADDING
    end

    if not has_child then
        y = y + self:get_text_height()
    end

    if not self.kind.IS_TEXT_INFIX then
        x = x + self:get_text_width() + Block.PADDING
    end

    local start_x = x
    local max_width = 0

    if self.kind.IS_VERTICAL then
        if has_child then
            for _, child in ipairs(self.children) do
                child:update_tree(x, y)
                x = x + child.width + Block.PADDING
                y = y + child.height + Block.PADDING

                max_width = math.max(max_width, x - self.x)
                x = start_x
            end
        end
    else
        local max_height = 0

        if has_child then
            for i, child in ipairs(self.children) do
                child:update_tree(x, y)
                x = x + child.width + Block.PADDING

                if i < #self.children and self.kind.IS_TEXT_INFIX then
                    x = x + self:get_text_width() + Block.PADDING
                end

                max_height = math.max(max_height, child.height + Block.PADDING)
            end
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

function Block:draw(cursor_block, camera, window_height, depth)
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

    local text_y = self.y - Block.PADDING / 2
    local has_child = self.children and #self.children > 0

    if not has_child then
        text_y = text_y - Block.PADDING
    end

    if not self.kind.IS_TEXT_INFIX then
        Graphics.draw_text(self:get_text(), self.x, text_y, camera)
    end

    if not has_child then
        return
    end

    -- if self.y * camera.zoom > camera.y + window_height or (self.y + self.height) * camera.zoom < camera.y then
    --     return
    -- end

    local first_visible_i = nil

    -- TODO: This will only be useful if self.IS_VERTICAL is true, make it work for horizontal layouts as well.
    do
        local min_i = 1
        local max_i = #self.children

        if max_i == 0 then
            return
        end

        while min_i ~= max_i do
            local i = math.floor((min_i + max_i) / 2)

            local child = self.children[i]

            if (child.y + child.height) * camera.zoom < camera.y then
                -- This child is after the camera's vision.
                min_i = i + 1
            else
                -- This child is before the  camera's vision.
                max_i = i
            end
        end

        if (self.children[min_i].y + self.children[min_i].height) * camera.zoom < camera.y then
            return
        end

        first_visible_i = min_i
    end

    for i = first_visible_i, #self.children do
        local child = self.children[i]

        if child.y * camera.zoom > camera.y + window_height then
            break
        end

        child:draw(cursor_block, camera, window_height, depth + 1)

        if i < #self.children and self.kind.IS_TEXT_INFIX then
            Graphics.draw_text(self:get_text(), child.x + child.width, text_y, camera)
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

function Block:save_block_list(data, first_i, separator)
    local last_i = #self.children

    for i = first_i, #self.children do
        local child = self.children[i]

        child:save(data)

        if i < last_i then
            data:write(separator)
        end
    end
end

function Block:save_statement_list(data)
    for _, child in ipairs(self.children) do
        child:save(data)
    end
end

function Block:save_function_header(data)
    data:write("function ")
    self.children[1]:save(data)
    data:write("(")
    self:save_block_list(data, 2, ", ")
    data:writeln(")")
end

function Block:save_function(data, is_lambda)
    self.children[1]:save(data)
    data:indent()
    self.children[2]:save(data)
    data:unindent()
    data:writeln("end")
end

function Block:save_lambda_function_header(data)
    data:write("function ")
    data:write("(")
    self:save_block_list(data, 1, ", ")
    data:writeln(")")
end

function Block:save_lambda_function(data)
    self.children[1]:save(data)
    data:indent()
    self.children[2]:save(data)
    data:unindent()
    data:writeln("end")
end

function Block:save_case(data)
    self.children[1]:save(data)
    data:writeln(" then")

    data:indent()

    for i = 2, #self.children do
        self.children[i]:save(data)
    end

    data:unindent()
end

function Block:save_if_cases(data)
    for i, child in ipairs(self.children) do
        if i == 1 then
            data:write("if ")
        else
            data:write("elseif ")
        end

        child:save(data)
    end
end

function Block:save_else_case(data)
    data:writeln("else")

    data:indent()

    for _, child in ipairs(self.children) do
        child:save(data)
    end

    data:unindent()
end

function Block:save_if(data)
    self.children[1]:save(data)

    if self.children[2]:contains_non_pin() then
        self.children[2]:save(data)
    end

    data:writeln("end")
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
    local text = self:get_text()

    if text:sub(1, 1) ~= "\"" then
        text = self:get_text():gsub(" ", "_")
    end

    data:write(text)
end

local BLOCK_SAVE_FUNCTIONS = {
    [Block.PIN] = Block.save_pin,
    [Block.DO] = Block.save_do,
    [Block.STATEMENT_LIST] = Block.save_statement_list,
    [Block.FUNCTION_HEADER] = Block.save_function_header,
    [Block.FUNCTION] = Block.save_function,
    [Block.LAMBDA_FUNCTION_HEADER] = Block.save_lambda_function_header,
    [Block.LAMBDA_FUNCTION] = Block.save_lambda_function,
    [Block.CASE] = Block.save_case,
    [Block.IF_CASES] = Block.save_if_cases,
    [Block.ELSE_CASE] = Block.save_else_case,
    [Block.IF] = Block.save_if,
    [Block.ASSIGNMENT] = Block.save_assignment,
    [Block.ADD] = Block.save_add,
    [Block.CALL] = Block.save_call,
    [Block.IDENTIFIER] = Block.save_identifier,
}

function Block:save(data)
    BLOCK_SAVE_FUNCTIONS[self.kind](self, data)
end