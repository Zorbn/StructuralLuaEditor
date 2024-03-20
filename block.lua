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
    EVEN_COLOR = {
        R = 247 / 255,
        G = 247 / 255,
        B = 247 / 255,
    },
    ODD_COLOR = {
        R = 240 / 255,
        G = 240 / 255,
        B = 240 / 255,
    },
    TEXT_COLOR = {
        R = 0,
        G = 0,
        B = 0,
    },
    CURSOR_COLOR = {
        R = 0 / 255,
        G = 122 / 255,
        B = 204 / 255,
    },
    PIN_COLOR = {
        R = 218 / 255,
        G = 218 / 255,
        B = 218 / 255,
    },
    PADDING = 8,

    PIN = {
        PIN_KIND = nil,
        GROUPS = {
            new_block_group({
                TEXT = ".",
                PINS = {},
            }),
        },
    },
    EXPANDER = {
        PIN_KIND = nil,
        GROUPS = {
            new_block_group({
                TEXT = ";",
                PINS = {},
            }),
        },
    },
    DO = {
        PIN_KIND = PinKind.STATEMENT,
        GROUPS = {
            new_block_group({
                TEXT = "do",
                IS_VERTICAL = true,
                HAS_EXPANDER = true,
                PINS = {
                    PinKind.STATEMENT,
                },
            }),
        },
    },
    FUNCTION = {
        PIN_KIND = PinKind.STATEMENT,
        GROUPS = {
            new_block_group({
                TEXT = "fn",
                HAS_EXPANDER = true,
                PINS = {
                    PinKind.IDENTIFIER,
                    PinKind.IDENTIFIER,
                },
            }),
            new_block_group({
                TEXT = "",
                IS_VERTICAL = true,
                HAS_EXPANDER = true,
                PINS = {
                    PinKind.STATEMENT,
                },
            }),
        },
    },
    LAMBDA_FUNCTION = {
        PIN_KIND = PinKind.EXPRESSION,
        GROUPS = {
            new_block_group({
                TEXT = "fn",
                HAS_EXPANDER = true,
                PINS = {
                    PinKind.IDENTIFIER,
                },
            }),
            new_block_group({
                TEXT = "",
                IS_VERTICAL = true,
                HAS_EXPANDER = true,
                PINS = {
                    PinKind.STATEMENT,
                },
            }),
        },
    },
    IF = {
        PIN_KIND = PinKind.STATEMENT,
        GROUPS = {
            new_block_group({
                TEXT = "if",
                IS_VERTICAL = true,
                PINS = {
                    PinKind.EXPRESSION,
                    PinKind.STATEMENT,
                    PinKind.STATEMENT,
                },
            }),
        },
    },
    ASSIGNMENT = {
        PIN_KIND = PinKind.STATEMENT,
        GROUPS = {
            new_block_group({
                TEXT = "=",
                PINS = {
                    PinKind.EXPRESSION,
                    PinKind.EXPRESSION,
                },
            }),
        },
    },
    ADD = {
        PIN_KIND = PinKind.EXPRESSION,
        GROUPS = {
            new_block_group({
                TEXT = "+",
                HAS_EXPANDER = true,
                PINS = {
                    PinKind.EXPRESSION,
                    PinKind.EXPRESSION,
                    PinKind.EXPRESSION,
                },
            }),
        }
    },
    CALL = {
        PIN_KIND = PinKind.EXPRESSION,
        GROUPS = {
            new_block_group({
                TEXT = "call",
                HAS_EXPANDER = true,
                PINS = {
                    PinKind.EXPRESSION,
                    PinKind.EXPRESSION,
                },
            }),
        }
    },
    IDENTIFIER = {
        PIN_KIND = PinKind.IDENTIFIER,
        GROUPS = {
            new_block_group({
                TEXT = "",
                PINS = {},
            }),
        }
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

        for i, pin_kind in ipairs(group.PINS) do
            local block_kind = Block.PIN

            if group.HAS_EXPANDER and i == #group.PINS then
                block_kind = Block.EXPANDER
            end

            block.child_groups[group_i][i] = Block:new(block_kind, block)
            block.child_groups[group_i][i].pin_kind = pin_kind
        end
    end

    setmetatable(block, self)
    self.__index = self

    return block
end

function Block:update_text_size()
    lyte.set_font(Graphics.default_font)
    self.text_width = lyte.get_text_width(self.text)
    self.text_height = lyte.get_text_height(self.text)
end

function Block:update_tree(x, y)
    self.x = x
    self.y = y

    local has_child = self.child_groups[1] and self.child_groups[1][1]

    x = x + Block.PADDING

    if has_child then
        y = y + Block.PADDING
    end

    if self.kind == Block.IDENTIFIER then
        x = x + self.text_width

        if not has_child then
            y = y + self.text_height
        end
    else
        x = x + self.kind.GROUPS[1].TEXT_WIDTH

        if not has_child then
            y = y + self.kind.GROUPS[1].TEXT_HEIGHT
        end
    end

    x = x + Block.PADDING

    local start_x = x
    local max_width = 0

    for group_i, child_group in ipairs(self.child_groups) do
        if self.kind.GROUPS[group_i].IS_VERTICAL then
            for _, child in ipairs(child_group) do
                child:update_tree(x, y)
                x = x + child.width + Block.PADDING
                y = y + child.height + Block.PADDING

                max_width = math.max(max_width, x - self.x)
                x = start_x
            end
        else
            local max_height = 0

            for _, child in ipairs(child_group) do
                child:update_tree(x, y)
                x = x + child.width + Block.PADDING
                max_height = math.max(max_height, child.height + Block.PADDING)
            end

            max_width = math.max(max_width, x - self.x)
            x = start_x
            y = y + max_height
        end

        if group_i < #self.child_groups and #self.child_groups[group_i + 1] > 0 then
            y = y + Block.PADDING * 2
        end
    end

    self.width = max_width
    self.height = y - self.y
end

function Block.get_depth_color(depth)
    if depth % 2 == 0 then
        return Block.EVEN_COLOR
    end

    return Block.ODD_COLOR
end

function Block:draw(cursor_block, camera, depth)
    if self == cursor_block then
        Graphics.set_color(Block.CURSOR_COLOR)
        lyte.draw_rect(self.x - Block.PADDING * 1.5, self.y - Block.PADDING * 1.5, self.width + Block.PADDING,
            self.height + Block.PADDING)
    end

    if self.kind == Block.PIN or self.kind == Block.EXPANDER then
        Graphics.set_color(Block.PIN_COLOR)
    else
        Graphics.set_color(Block.get_depth_color(depth))
    end

    lyte.draw_rect(self.x - Block.PADDING, self.y - Block.PADDING, self.width, self.height)

    Graphics.set_color(Block.TEXT_COLOR)

    -- TODO: Fix this to work for multiple groups.
    local text
    if self.kind == Block.IDENTIFIER then
        text = self.text
    else
        text = self.kind.GROUPS[1].TEXT
    end

    local text_y = self.y - Block.PADDING / 2
    local has_child = self.child_groups[1] and self.child_groups[1][1]

    if not has_child then
        text_y = text_y - Block.PADDING
    end

    Graphics.draw_text(text, self.x, text_y, camera)

    for group_i, children in ipairs(self.child_groups) do
        for _, child in ipairs(children) do
            child:draw(cursor_block, camera, depth + 1)
        end

        if group_i < #self.child_groups and #self.child_groups[group_i + 1] > 0 then
            Graphics.set_color(Block.get_depth_color(depth - 1))
            lyte.draw_rect(self.x, self.child_groups[group_i + 1][1].y - Block.PADDING * 2.75,
                self.width - Block.PADDING * 2, Block.PADDING / 2)
        end
    end
end

function Block:expand_group(i)
    local children = self.child_groups[i]
    local pins = self.kind.GROUPS[i].PINS

    local pin = Block:new(Block.PIN, self)
    pin.pin_kind = pins[#pins]

    table.insert(children, #children, pin)
end

function Block:save_pin(_)
end

function Block:save_expander(_)
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

function Block:save_function(data, is_lambda)
    data:write("function ")

    if not is_lambda then
        self.child_groups[1][1]:save(data)
    end

    data:write("(")

    local last_i = #self.child_groups[1] - 1
    local first_i = is_lambda and 1 or 2

    for i = first_i, #self.child_groups[1] do
        local child = self.child_groups[1][i]

        child:save(data)

        if i < last_i then
            data:write(", ")
        end
    end

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
    local last_i = #self.child_groups[1] - 1

    for i, child in ipairs(self.child_groups[1]) do
        child:save(data)

        if i < last_i then
            data:write(" + ")
        end
    end
end

function Block:save_call(data)
    self.child_groups[1][1]:save(data)

    data:write("(")

    local last_i = #self.child_groups[1] - 1
    for i = 2, last_i do
        self.child_groups[1][i]:save(data)

        if i < last_i then
            data:write(", ")
        end
    end

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
    [Block.EXPANDER] = Block.save_expander,
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