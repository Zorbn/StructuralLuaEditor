--[[

TODO:
- Make text insertion only allow valid characters,
- Make text insertion use space instead of underscores, which will be converted to underscores
  behind the scenes for final Lua code.
- Have two types of pins, pins that must be filled (highlighted red) "!" and pins that are optional "?".
- Add importing Lua code.
- Support multiple files.

]]--

local Camera = {
    ZOOM_STEP = 0.25,
    PAN_SPEED = 10,
}

function Camera:new()
    local camera = {
        x = 0,
        y = 0,
        zoom = 1,
    }

    setmetatable(camera, self)
    self.__index = self

    return camera
end

function Camera:update(dt, cursor_block, window_width, window_height)
    local target_x = cursor_block.x - window_width / 2 + cursor_block.kind.GROUPS[1].TEXT_WIDTH / 2
    local target_y = cursor_block.y - window_height / 2 + cursor_block.kind.GROUPS[1].TEXT_HEIGHT / 2

    self.x = self.x + (target_x - self.x) * Camera.PAN_SPEED * dt
    self.y = self.y + (target_y - self.y) * Camera.PAN_SPEED * dt

    if lyte.is_key_pressed("page_up") then
        self.zoom = self.zoom + Camera.ZOOM_STEP
    end

    if lyte.is_key_pressed("page_down") then
        self.zoom = self.zoom - Camera.ZOOM_STEP
    end
end

local function set_color(color)
    lyte.set_color(color.R, color.G, color.B, 1)
end

local function is_key_pressed_or_repeat(key)
    return lyte.is_key_pressed(key) or lyte.is_key_repeat(key)
end

local default_font = lyte.load_font("Roboto-Regular.ttf", 26)
lyte.set_font(default_font)

local Writer = {}

function Writer:new()
    local writer = {
        buffer = {},
        is_after_newline = true,
        indent_count = 0,
    }

    setmetatable(writer, self)
    self.__index = self

    return writer
end

function Writer:write(string)
    if self.is_after_newline then
        for _ = 1, self.indent_count do
            table.insert(self.buffer, "    ")
        end

        self.is_after_newline = false
    end

    table.insert(self.buffer, string)
end

function Writer:writeln(string)
    self:write(string)
    self:newline()
end

function Writer:newline()
    table.insert(self.buffer, "\n")
    self.is_after_newline = true
end

function Writer:indent()
    self.indent_count = self.indent_count + 1
end

function Writer:unindent()
    self.indent_count = self.indent_count - 1
end

function Writer:to_string()
    return table.concat(self.buffer)
end

local PinKind = {
    EXPRESSION = 1,
    STATEMENT = 2,
    IDENTIFIER = 3,
}

local function new_block_group(group)
    group.TEXT_WIDTH = lyte.get_text_width(group.TEXT)
    group.TEXT_HEIGHT = lyte.get_text_height(group.TEXT)

    return group
end

local Block = {
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

local PIN_BLOCKS = {
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

function Block:draw(cursor_block, depth)
    if self == cursor_block then
        set_color(Block.CURSOR_COLOR)
        lyte.draw_rect(self.x - Block.PADDING * 1.5, self.y - Block.PADDING * 1.5, self.width + Block.PADDING,
            self.height + Block.PADDING)
    end

    if self.kind == Block.PIN or self.kind == Block.EXPANDER then
        set_color(Block.PIN_COLOR)
    else
        set_color(Block.get_depth_color(depth))
    end

    lyte.draw_rect(self.x - Block.PADDING, self.y - Block.PADDING, self.width, self.height)

    set_color(Block.TEXT_COLOR)

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

    lyte.draw_text(text, self.x, text_y)

    for group_i, children in ipairs(self.child_groups) do
        for _, child in ipairs(children) do
            child:draw(cursor_block, depth + 1)
        end

        if group_i < #self.child_groups and #self.child_groups[group_i + 1] > 0 then
            set_color(Block.get_depth_color(depth - 1))
            lyte.draw_rect(self.x, self.child_groups[group_i + 1][1].y - Block.PADDING * 2.75, self.width - Block.PADDING * 2, Block.PADDING / 2)
        end
    end
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

local camera = Camera:new()

local root_block = Block:new(Block.DO, nil)
root_block:update_tree(0, 0)

local cursor_block = root_block
local cursor_group_i = 0
local cursor_i = 0

-- Determine where the cursor block is stored in its parent's list of children.
local function update_cursor_child_indices()
    cursor_group_i = 1
    cursor_i = 1

    if not cursor_block.parent then
        return
    end

    for group_i, children in ipairs(cursor_block.parent.child_groups) do
        for i, child in ipairs(children) do
            if child == cursor_block then
                cursor_group_i = group_i
                cursor_i = i

                return
            end
        end
    end
end

local function try_move_cursor_up_local()
    if cursor_block.parent then
        cursor_block = cursor_block.parent
        update_cursor_child_indices()
        return true
    end

    return false
end

local function try_move_cursor_down_local()
    if cursor_block.child_groups[1][1] then
        cursor_block = cursor_block.child_groups[1][1]
        update_cursor_child_indices()
        return true
    end

    return false
end

local function try_move_cursor_left_local()
    if cursor_block.parent then
        if cursor_i > 1 then
            cursor_block = cursor_block.parent.child_groups[cursor_group_i][cursor_i - 1]

            update_cursor_child_indices()
            return true
        elseif cursor_group_i > 1 then
            local group = cursor_block.parent.child_groups[cursor_group_i - 1]
            cursor_block = group[#group]

            update_cursor_child_indices()
            return true
        end
    end

    return false
end

local function try_move_cursor_right_local()
    if cursor_block.parent then
        local group = cursor_block.parent.child_groups[cursor_group_i]

        if cursor_i < #group then
            cursor_block = group[cursor_i + 1]

            update_cursor_child_indices()
            return true
        elseif cursor_group_i < #cursor_block.parent.child_groups then
            cursor_block = cursor_block.parent.child_groups[cursor_group_i + 1][1]

            update_cursor_child_indices()
            return true
        end
    end

    return false
end

local function try_move_cursor_up()
    if cursor_block.parent and cursor_block.parent.kind.GROUPS[cursor_group_i].IS_VERTICAL then
        return try_move_cursor_left_local()
    end

    return try_move_cursor_up_local()
end

local function try_move_cursor_down()
    if cursor_block.parent and cursor_block.parent.kind.GROUPS[cursor_group_i].IS_VERTICAL then
        return try_move_cursor_right_local()
    end

    return try_move_cursor_down_local()
end

local function try_move_cursor_left()
    if cursor_block.parent and cursor_block.parent.kind.GROUPS[cursor_group_i].IS_VERTICAL then
        return try_move_cursor_up_local()
    end

    return try_move_cursor_left_local()
end

local function try_move_cursor_right()
    if cursor_block.parent and cursor_block.parent.kind.GROUPS[cursor_group_i].IS_VERTICAL then
        return try_move_cursor_down_local()
    end

    return try_move_cursor_right_local()
end

local function try_fill_pin(search_text, do_insert)
    if cursor_block.kind ~= Block.PIN then
        return
    end

    if cursor_block.parent == nil then
        return
    end

    local block_kind_choices = PIN_BLOCKS[cursor_block.pin_kind]

    local chosen_block_kind = nil
    if do_insert then
        if cursor_block.pin_kind ~= PinKind.IDENTIFIER and cursor_block.pin_kind ~= PinKind.EXPRESSION then
            return false
        end

        chosen_block_kind = Block.IDENTIFIER
    else
        for _, block_kind in ipairs(block_kind_choices) do
            if block_kind.GROUPS[1].TEXT == search_text then
                chosen_block_kind = block_kind
            end
        end
    end

    if chosen_block_kind ~= nil then
        cursor_block.parent.child_groups[cursor_group_i][cursor_i] = Block:new(chosen_block_kind, cursor_block.parent)
        cursor_block = cursor_block.parent.child_groups[cursor_group_i][cursor_i]

        if do_insert then
            cursor_block.text = search_text
            cursor_block:update_text_size()
        end

        root_block:update_tree(root_block.x, root_block.y)
        return true
    end

    return false
end

local function try_delete()
    if cursor_block.parent == nil or cursor_block.kind == Block.EXPANDER then
        return
    end

    if cursor_block.kind == Block.PIN and
        cursor_block.parent.kind.GROUPS[cursor_group_i].HAS_EXPANDER and
        cursor_i >= #cursor_block.parent.kind.GROUPS[cursor_group_i].PINS then

        cursor_block = cursor_block.parent.child_groups[cursor_group_i][cursor_i + 1]
        table.remove(cursor_block.parent.child_groups[cursor_group_i], cursor_i)
    else
        local new_pin = Block:new(Block.PIN, cursor_block.parent)
        local last_pin_i = math.min(cursor_i, #cursor_block.parent.kind.GROUPS[cursor_group_i].PINS)
        new_pin.pin_kind = cursor_block.parent.kind.GROUPS[cursor_group_i].PINS[last_pin_i]
        cursor_block.parent.child_groups[cursor_group_i][cursor_i] = new_pin
        cursor_block = new_pin
    end

    root_block:update_tree(root_block.x, root_block.y)
end

local function try_expand()
    if cursor_block.parent == nil then
        return
    end

    local children = cursor_block.parent.child_groups[cursor_group_i]
    local pin = Block:new(Block.PIN, cursor_block.parent)
    pin.pin_kind = cursor_block.pin_kind
    table.insert(children, #children, pin)

    root_block:update_tree(root_block.x, root_block.y)

    update_cursor_child_indices()
end

local InteractionState = {
    CURSOR = 1,
    SEARCH = 2,
    INSERT = 3,
}

local interaction_state = InteractionState.CURSOR
local search_text = ""
local insert_text = ""

local function update_cursor()
    if lyte.is_key_down("left_control") then
        if lyte.is_key_down("s") then
            local data = Writer:new()
            root_block:save(data)
            local data_string = data:to_string()

            lyte.save_textfile("save.lua", data_string)
        end

        return
    end

    if is_key_pressed_or_repeat("up") or is_key_pressed_or_repeat("e") or is_key_pressed_or_repeat("i") then
        if not try_move_cursor_up() then
            try_move_cursor_left()
        end
    elseif is_key_pressed_or_repeat("down") or is_key_pressed_or_repeat("d") or is_key_pressed_or_repeat("k") then
        if not try_move_cursor_down() then
            try_move_cursor_right()
        end
    elseif is_key_pressed_or_repeat("left") or is_key_pressed_or_repeat("s") or is_key_pressed_or_repeat("j") then
        if not try_move_cursor_left() then
            try_move_cursor_up()
        end
    elseif is_key_pressed_or_repeat("right") or is_key_pressed_or_repeat("f") or is_key_pressed_or_repeat("l") then
        if not try_move_cursor_right() then
            try_move_cursor_down()
        end
    end

    if lyte.is_key_pressed("space") then
        if cursor_block.kind == Block.EXPANDER then
            try_expand()
            try_move_cursor_left_local()
        end

        interaction_state = InteractionState.SEARCH
        return
    end

    if lyte.is_key_pressed("enter") then
        if cursor_block.kind == Block.EXPANDER then
            try_expand()
            try_move_cursor_left_local()
        end

        interaction_state = InteractionState.INSERT
        return
    end

    if is_key_pressed_or_repeat("backspace") then
        try_delete()
    end
end

local function update_text_input(text, do_insert)
    text = text .. lyte.get_textinput()

    if is_key_pressed_or_repeat("backspace") then
        text = text:sub(1, #text - 1)
    end

    if lyte.is_key_pressed("escape") then
        text = ""
        interaction_state = InteractionState.CURSOR

        return text
    end

    if lyte.is_key_pressed("enter") then
        if try_fill_pin(text, do_insert) then
            text = ""
            interaction_state = InteractionState.CURSOR
        end
    end

    return text
end

local function draw_text_input(prefix, text)
    local display_text = prefix .. text
    local display_text_width = lyte.get_text_width(display_text)
    local display_text_height = lyte.get_text_height(display_text)
    lyte.draw_text(display_text, 10, 0)
    set_color(Block.CURSOR_COLOR)
    lyte.draw_rect(display_text_width + 10, 5, 5, display_text_height + 5)
end

local BACKGROUND_COLOR = {
    R = 221 / 255,
    G = 221 / 255,
    B = 221 / 255,
}

function lyte.tick(dt, window_width, window_height)
    if interaction_state == InteractionState.SEARCH then
        search_text = update_text_input(search_text, false)
    elseif interaction_state == InteractionState.INSERT then
        insert_text = update_text_input(insert_text, true)
    else
        update_cursor()
    end

    camera:update(dt, cursor_block, window_width, window_height)

    lyte.push_matrix()

    lyte.translate(-camera.x, -camera.y)
    lyte.scale(camera.zoom, camera.zoom)

    lyte.cls(BACKGROUND_COLOR.R, BACKGROUND_COLOR.G, BACKGROUND_COLOR.B, 1)

    root_block:draw(cursor_block, 0)

    lyte.pop_matrix()

    set_color(Block.TEXT_COLOR)

    if interaction_state == InteractionState.SEARCH then
        draw_text_input("Search: ", search_text)
    elseif interaction_state == InteractionState.INSERT then
        draw_text_input("Insert: ", insert_text)
    else
        lyte.draw_text(camera.zoom * 100 .. "%", 10, 0)
    end
end