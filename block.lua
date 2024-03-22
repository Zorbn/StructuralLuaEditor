PinKind = {
    EXPRESSION = 1,
    STATEMENT = 2,
    IDENTIFIER = 3,
}

local function new_block_group(group)
    group.TEXT_WIDTH = lyte.get_text_width(group.TEXT)
    group.TEXT_HEIGHT = lyte.get_text_height(group.TEXT)

    return group
end

lyte.set_font(Graphics.code_font)

Block = {
    PADDING = 6,
    LINE_WIDTH = 3,
}

Block.PIN = {
    PIN_KIND = nil,
    GROUPS = {
        new_block_group({
            TEXT = ".",
            DEFAULT_CHILDREN = {},
        }),
    },
}

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

Block.DO = {
    PIN_KIND = PinKind.STATEMENT,
    GROUPS = {
        new_block_group({
            TEXT = "do",
            IS_VERTICAL = true,
            IS_GROWABLE = true,
            DEFAULT_CHILDREN = {
                new_default_child_pin(PinKind.STATEMENT),
            },
        }),
    },
}

Block.FUNCTION = {
    PIN_KIND = PinKind.STATEMENT,
    GROUPS = {
        new_block_group({
            TEXT = "fn",
            IS_GROWABLE = true,
            DEFAULT_CHILDREN = {
                new_default_child_pin(PinKind.IDENTIFIER),
                new_default_child_pin(PinKind.IDENTIFIER),
            },
        }),
        new_block_group({
            TEXT = "",
            IS_VERTICAL = true,
            IS_GROWABLE = true,
            DEFAULT_CHILDREN = {
                new_default_child_pin(PinKind.STATEMENT),
            },
        }),
    },
}

Block.LAMBDA_FUNCTION = {
    PIN_KIND = PinKind.EXPRESSION,
    GROUPS = {
        new_block_group({
            TEXT = "fn",
            IS_GROWABLE = true,
            DEFAULT_CHILDREN = {
                new_default_child_pin(PinKind.IDENTIFIER),
            },
        }),
        new_block_group({
            TEXT = "",
            IS_VERTICAL = true,
            IS_GROWABLE = true,
            DEFAULT_CHILDREN = {
                new_default_child_pin(PinKind.STATEMENT),
            },
        }),
    },
}

Block.CASE = {
    PIN_KIND = PinKind.STATEMENT,
    GROUPS = {
        new_block_group({
            TEXT = "case",
            DEFAULT_CHILDREN = {
                new_default_child_pin(PinKind.EXPRESSION),
                new_default_child_pin(PinKind.STATEMENT),
            },
        }),
    },
}

Block.IF = {
    PIN_KIND = PinKind.STATEMENT,
    GROUPS = {
        new_block_group({
            TEXT = "if",
            IS_VERTICAL = true,
            IS_GROWABLE = true,
            DEFAULT_CHILDREN = {
                new_default_child(Block.CASE),
            },
        }),
        new_block_group({
            TEXT = "",
            IS_VERTICAL = true,
            IS_GROWABLE = false,
            DEFAULT_CHILDREN = {
                -- new_default_child_pin(PinKind.STATEMENT),
                new_default_child(Block.CASE),
            },
        }),
    },
}

Block.ASSIGNMENT = {
    PIN_KIND = PinKind.STATEMENT,
    GROUPS = {
        new_block_group({
            TEXT = "=",
            IS_TEXT_INFIX = true,
            DEFAULT_CHILDREN = {
                new_default_child_pin(PinKind.EXPRESSION),
                new_default_child_pin(PinKind.EXPRESSION),
            },
        }),
    },
}

Block.ADD = {
    PIN_KIND = PinKind.EXPRESSION,
    GROUPS = {
        new_block_group({
            TEXT = "+",
            IS_TEXT_INFIX = true,
            IS_GROWABLE = true,
            DEFAULT_CHILDREN = {
                new_default_child_pin(PinKind.EXPRESSION),
                new_default_child_pin(PinKind.EXPRESSION),
                new_default_child_pin(PinKind.EXPRESSION),
            },
        }),
    }
}

Block.CALL = {
    PIN_KIND = PinKind.EXPRESSION,
    GROUPS = {
        new_block_group({
            TEXT = "call",
            IS_GROWABLE = true,
            DEFAULT_CHILDREN = {
                new_default_child_pin(PinKind.EXPRESSION),
                new_default_child_pin(PinKind.EXPRESSION),
            },
        }),
    }
}

Block.IDENTIFIER = {
    PIN_KIND = PinKind.IDENTIFIER,
    GROUPS = {
        new_block_group({
            TEXT = "",
            DEFAULT_CHILDREN = {},
        }),
    }
}

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
        child_groups = {},
        x = 0,
        y = 0,
        width = 0,
        height = 0,
    }

    for group_i, group in ipairs(kind.GROUPS) do
        block.child_groups[group_i] = {}

        for i, default_child in ipairs(group.DEFAULT_CHILDREN) do
            local block_kind = default_child.block_kind

            block.child_groups[group_i][i] = Block:new(block_kind, block)
            block.child_groups[group_i][i].pin_kind = default_child.pin_kind
        end
    end

    setmetatable(block, self)
    self.__index = self

    return block
end

function Block:update_text_size(camera)
    lyte.set_font(Graphics.code_font)
    self.text_width = camera:get_text_width(self.text)
    self.text_height = camera:get_text_height(self.text)
end

function Block:has_child()
    return self.child_groups[1] and self.child_groups[1][1]
end

function Block:update_tree(x, y)
    self.x = x
    self.y = y

    local text_width, text_height
    if self.kind == Block.IDENTIFIER then
        text_width = self.text_width
        text_height = self.text_height
    else
        text_width = self.kind.GROUPS[1].TEXT_WIDTH
        text_height = self.kind.GROUPS[1].TEXT_HEIGHT
    end

    local has_child = self:has_child()

    x = x + Block.PADDING

    if has_child then
        y = y + Block.PADDING
    end

    if not has_child then
        y = y + text_height
    end

    local start_x = x
    local max_width = 0

    for group_i, child_group in ipairs(self.child_groups) do
        local kind_group = self.kind.GROUPS[group_i]

        if group_i > 1 then
            y = y + Block.LINE_WIDTH
        elseif not kind_group.IS_TEXT_INFIX then
            x = x + text_width + Block.PADDING
            start_x = x
        end

        if kind_group.IS_VERTICAL then
            for _, child in ipairs(child_group) do
                child:update_tree(x, y)
                x = x + child.width + Block.PADDING
                y = y + child.height + Block.PADDING

                max_width = math.max(max_width, x - self.x)
                x = start_x
            end
        else
            local max_height = 0

            for i, child in ipairs(child_group) do
                child:update_tree(x, y)
                x = x + child.width + Block.PADDING

                if i < #child_group and kind_group.IS_TEXT_INFIX then
                    x = x + text_width + Block.PADDING
                end

                max_height = math.max(max_height, child.height + Block.PADDING)
            end

            max_width = math.max(max_width, x - self.x)
            x = start_x
            y = y + max_height
        end
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

    -- TODO: Fix this to work for multiple groups.
    local text
    if self.kind == Block.IDENTIFIER then
        text = self.text
    else
        text = self.kind.GROUPS[1].TEXT
    end

    local text_y = self.y - Block.PADDING / 2
    local has_child = self:has_child()

    if not has_child then
        text_y = text_y - Block.PADDING
    end

    for group_i, child_group in ipairs(self.child_groups) do
        local kind_group = self.kind.GROUPS[group_i]

        if group_i == 1 and not kind_group.IS_TEXT_INFIX then
            Graphics.draw_text(text, self.x, text_y, camera)
        end

        for i, child in ipairs(child_group) do
            child:draw(cursor_block, camera, depth + 1)

            if i < #child_group and kind_group.IS_TEXT_INFIX then
                Graphics.draw_text(text, child.x + child.width, text_y, camera)
            end
        end

        if group_i < #self.child_groups and #self.child_groups[group_i + 1] > 0 then
            Graphics.set_color(Block.get_depth_color(depth - 1))
            lyte.draw_rect(self.x, self.child_groups[group_i + 1][1].y - Block.PADDING - Block.LINE_WIDTH,
                self.width - Block.PADDING * 2, Block.LINE_WIDTH)
        end
    end
end

function Block:save_pin(_)
end

function Block:save_do(data)
    data:writeln("do")
    data:indent()

    for _, child_group in ipairs(self.child_groups) do
        for _, child in ipairs(child_group) do
            child:save(data)
        end
    end

    data:unindent()
    data:writeln("end")
end

function Block:save_block_list(data, group_i, first_i, seperator)
    local last_i = #self.child_groups[group_i]

    for i = first_i, #self.child_groups[group_i] do
        local child = self.child_groups[group_i][i]

        child:save(data)

        if i < last_i then
            data:write(seperator)
        end
    end
end

function Block:save_function(data, is_lambda)
    data:write("function ")

    if not is_lambda then
        self.child_groups[1][1]:save(data)
    end

    data:write("(")

    local first_i = is_lambda and 1 or 2
    self:save_block_list(data, 1, first_i, ", ")

    data:writeln(")")
    data:indent()

    for _, child in ipairs(self.child_groups[2]) do
        child:save(data)
    end

    data:unindent()
    data:writeln("end")
end

function Block:save_lambda_function(data)
    self:save_function(data, true)
end

function Block:save_if(data)
    data:write("if ")
    self.child_groups[1][1]:save(data)
    data:writeln(" then")
    self.child_groups[1][2]:save(data)

    if self.child_groups[1][3].kind ~= Block.PIN then
        data:writeln("else")
        self.child_groups[1][3]:save(data)
    end

    data:writeln("end")
end

function Block:save_assignment(data)
    self.child_groups[1][1]:save(data)
    data:write(" = ")
    self.child_groups[1][2]:save(data)
    data:newline()
end

function Block:save_add(data)
    self:save_block_list(data, 1, 1, " + ")
end

function Block:save_call(data)
    self.child_groups[1][1]:save(data)

    data:write("(")

    self:save_block_list(data, 1, 2, ", ")

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