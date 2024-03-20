require("block")
require("graphics")

--[[

TODO:
- Make text insertion only allow valid characters,
- Make text insertion use space instead of underscores, which will be converted to underscores
  behind the scenes for final Lua code.
- Have two types of pins, pins that must be filled (highlighted red) "!" and pins that are optional "?".
- Add importing Lua code.
- Support multiple files.

- if should look like
(if
    (case condition statement)
    ...
    optional else statement)

if condition then
    statement
... -- else ifs generated from any additional cases
-- else generated if else statement exists

]]--

local function is_key_pressed_or_repeat(key)
    return lyte.is_key_pressed(key) or lyte.is_key_repeat(key)
end

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
    local block_text_width, block_text_height

    if cursor_block.kind == Block.IDENTIFIER then
        block_text_width = cursor_block.text_width
        block_text_height = cursor_block.text_height
    else
        block_text_width = cursor_block.kind.GROUPS[1].TEXT_WIDTH
        block_text_height = cursor_block.kind.GROUPS[1].TEXT_HEIGHT
    end

    local target_x = cursor_block.x * self.zoom - window_width / 2 + block_text_width * self.zoom / 2
    local target_y = cursor_block.y * self.zoom - window_height / 2 + block_text_height * self.zoom / 2

    self.x = self.x + (target_x - self.x) * Camera.PAN_SPEED * dt
    self.y = self.y + (target_y - self.y) * Camera.PAN_SPEED * dt

    if is_key_pressed_or_repeat("page_up") then
        self.zoom = self.zoom + Camera.ZOOM_STEP

        Graphics.set_default_font(Graphics.DEFAULT_FONT_SIZE * self.zoom)
    end

    if is_key_pressed_or_repeat("page_down") then
        self.zoom = self.zoom - Camera.ZOOM_STEP
        self.zoom = math.max(self.zoom, 0.1)

        Graphics.set_default_font(Graphics.DEFAULT_FONT_SIZE * self.zoom)
    end
end

function Camera:get_text_height(text)
    return lyte.get_text_height(text) / self.zoom
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
    lyte.set_font(Graphics.default_font)

    local display_text = prefix .. text
    local display_text_width = lyte.get_text_width(display_text)
    local display_text_height = lyte.get_text_height(display_text)
    lyte.draw_text(display_text, 10, 0)
    Graphics.set_color(Block.CURSOR_COLOR)
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

    root_block:draw(cursor_block, camera, 0)

    lyte.pop_matrix()

    Graphics.set_color(Block.TEXT_COLOR)

    if interaction_state == InteractionState.SEARCH then
        draw_text_input("Search: ", search_text)
    elseif interaction_state == InteractionState.INSERT then
        draw_text_input("Insert: ", insert_text)
    else
        lyte.set_font(Graphics.default_font)
        lyte.draw_text(camera.zoom * 100 .. "%", 10, 0)
    end
end