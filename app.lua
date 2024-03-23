require("geometry")
require("graphics")
require("block")
require("parser")
require("lexer")
require("theme")

--[[

TODO:
- Make text insertion only allow valid characters.
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

-- Change scaling method, don't use lyte.scale, do things manually to ensure consistent pixel sizes at all scales, ie: outlines should be the same width on all sides, even at 75%.

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
    DO_PAN_HORIZONTALLY = false,
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

function Camera:update(dt, cursor_block, root_block, window_width, window_height)
    local block_text_width, block_text_height

    if cursor_block.kind == Block.IDENTIFIER then
        block_text_width = cursor_block.text_width
        block_text_height = cursor_block.text_height
    else
        block_text_width = cursor_block.kind.TEXT_WIDTH
        block_text_height = cursor_block.kind.TEXT_HEIGHT
    end

    local target_x
    if Camera.DO_PAN_HORIZONTALLY then
        target_x = cursor_block.x * self.zoom - window_width / 2 + block_text_width * self.zoom / 2
    else
        target_x = -Block.PADDING * self.zoom * 2
        target_x = math.min(target_x, root_block.x * self.zoom + root_block.width * self.zoom / 2 - window_width / 2)
    end
    local target_y = cursor_block.y * self.zoom - window_height / 2 + block_text_height * self.zoom / 2

    -- Stop once the camera is close enough, otherwise lerping would end with the camera moving tiny subpixel amounts
    -- each frame, which would be mostly unoticable except they cause text to jitter as it tries to snap to screen pixels.
    local stop_distance = math.ceil(self.zoom)
    self.x = Geometry.lazy_lerp(self.x, target_x, Camera.PAN_SPEED * dt, stop_distance)
    self.y = Geometry.lazy_lerp(self.y, target_y, Camera.PAN_SPEED * dt, stop_distance)

    if is_key_pressed_or_repeat("page_up") then
        self:set_zoom(self.zoom + Camera.ZOOM_STEP)
    end

    if is_key_pressed_or_repeat("page_down") then
        self:set_zoom(self.zoom - Camera.ZOOM_STEP)
    end
end

function Camera:set_zoom(zoom)
    self.zoom = math.max(zoom, 0.1)
    Graphics.set_code_font(Graphics.DEFAULT_CODE_FONT_SIZE * self.zoom)
end

function Camera:get_text_width(text)
    return lyte.get_text_width(text) / self.zoom
end

function Camera:get_text_height(text)
    return lyte.get_text_height(text) / self.zoom
end

local camera = Camera:new()

local root_block

do
    local data = lyte.load_textfile("save.lua")
    if data then
        local lexer = Lexer:new(data)
        local parser = Parser:new(lexer, camera)
        root_block = parser:statement(nil)
        collectgarbage("collect")
    else
        root_block = Block:new(Block.DO, nil)
    end
end

root_block:update_tree(0, 0)

local cursor_block = root_block
local clipboard_block = nil
local cursor_i = 0

-- Determine where the cursor block is stored in its parent's list of children.
local function update_cursor_child_indices()
    cursor_i = 1

    if not cursor_block.parent then
        return
    end

    for i, child in ipairs(cursor_block.parent.children) do
        if child == cursor_block then
            cursor_i = i

            return
        end
    end
end

local function try_cursor_ascend()
    if cursor_block.parent then
        cursor_block = cursor_block.parent
        update_cursor_child_indices()
        return true
    end

    return false
end

local function try_cursor_descend()
    if cursor_block.children[1] then
        cursor_block = cursor_block.children[1]
        update_cursor_child_indices()
        return true
    end

    return false
end

local function try_cursor_previous()
    if cursor_block.parent then
        if cursor_i > 1 then
            cursor_block = cursor_block.parent.children[cursor_i - 1]
            update_cursor_child_indices()

            return true
        end
    end

    return try_cursor_ascend()
end

local function try_cursor_next()
    if cursor_block.parent then
        if cursor_i < #cursor_block.parent.children then
            cursor_block = cursor_block.parent.children[cursor_i + 1]
            update_cursor_child_indices()

            return true
        end
    end

    return try_cursor_ascend()
end

local function is_cursor_vertical()
    return not cursor_block.parent or cursor_block.parent.kind.IS_VERTICAL
end

local function try_move_cursor_up()
    if is_cursor_vertical() then
        return try_cursor_previous()
    end

    return try_cursor_ascend()
end

local function try_move_cursor_down()
    if is_cursor_vertical() then
        return try_cursor_next()
    end

    return try_cursor_descend()
end

local function try_move_cursor_left()
    if is_cursor_vertical() then
        return try_cursor_ascend()
    end

    return try_cursor_previous()
end

local function try_move_cursor_right()
    if is_cursor_vertical() then
        return try_cursor_descend()
    end

    return try_cursor_next()
end

local Direction = {
    UP = 1,
    DOWN = 2,
    LEFT = 3,
    RIGHT = 4,
}

local function get_insert_target_i(direction)
    local target_i = cursor_i

    if is_cursor_vertical() then
        if direction == Direction.DOWN then
            target_i = target_i + 1
        elseif direction and direction ~= Direction.UP then
            return nil
        end
    else
        if direction == Direction.RIGHT then
            target_i = target_i + 1
        elseif direction and direction ~= Direction.LEFT then
            return nil
        end
    end

    return target_i
end

local function get_insert_default_child(target_i)
    if not cursor_block.parent then
        return nil
    end

    local default_children = cursor_block.parent.kind.DEFAULT_CHILDREN
    local default_child_i = math.min(target_i, #default_children)

    return default_children[default_child_i]
end

local function is_insert_target_valid(direction, target_i)
    if not cursor_block.parent or (direction and not cursor_block.parent.kind.IS_GROWABLE) then
        return false
    end

    if direction and target_i < #cursor_block.parent.kind.DEFAULT_CHILDREN then
        return false
    end

    return true
end

local function try_insert(search_text, direction)
    local target_i = get_insert_target_i(direction)
    if not target_i or not is_insert_target_valid(direction, target_i) then
        return
    end

    local default_child = get_insert_default_child(target_i)
    if not default_child then
        return
    end

    local pin_kind = default_child.pin_kind
    local block_kind_choices = PIN_BLOCKS[pin_kind]

    local chosen_block_kind = default_child.block_kind ~= Block.PIN and default_child.block_kind or nil

    if not chosen_block_kind then
        if #search_text == 0 then
            chosen_block_kind = Block.PIN
        else
            for _, block_kind in ipairs(block_kind_choices) do
                if block_kind.SEARCH_TEXT == search_text then
                    chosen_block_kind = block_kind
                end
            end
        end
    end

    if not chosen_block_kind then
        if pin_kind ~= PinKind.IDENTIFIER and pin_kind ~= PinKind.EXPRESSION then
            return false
        end

        chosen_block_kind = Block.IDENTIFIER
    end

    local do_replace = not direction

    local block = Block:new(chosen_block_kind, cursor_block.parent)
    block.pin_kind = pin_kind

    if do_replace then
        cursor_block.parent.children[target_i] = block
    else
        table.insert(cursor_block.parent.children, target_i, block)
    end

    cursor_i = target_i
    cursor_block = cursor_block.parent.children[cursor_i]

    if chosen_block_kind == Block.IDENTIFIER then
        cursor_block.text = search_text
        cursor_block:update_text_size(camera)
    end

    root_block:update_tree(root_block.x, root_block.y)

    return true
end

local function try_delete()
    if not cursor_block.parent then
        return false
    end

    local default_children = cursor_block.parent.kind.DEFAULT_CHILDREN

    if cursor_block.parent.kind.IS_GROWABLE and cursor_i > 1 then
        -- This is a pin wasn't default, so we can fully remove it.

        local delete_i = cursor_i

        if cursor_i + 1 <= #cursor_block.parent.children then
            cursor_block = cursor_block.parent.children[cursor_i + 1]
        elseif cursor_i > 1 then
            cursor_i = cursor_i - 1
            cursor_block = cursor_block.parent.children[cursor_i]
        else
            cursor_block = cursor_block.parent
        end

        table.remove(cursor_block.parent.children, delete_i)
    else
        local default_child_i = math.min(cursor_i, #default_children)
        local default_child = default_children[default_child_i]

        local child = Block:new(default_child.block_kind, cursor_block.parent)
        child.pin_kind = default_child.pin_kind
        cursor_block.parent.children[cursor_i] = child
        cursor_block = child
    end

    root_block:update_tree(root_block.x, root_block.y)

    return true
end

local function get_swap_target_i(direction)
    local target_i = cursor_i

    if is_cursor_vertical() then
        if direction == Direction.DOWN then
            target_i = target_i + 1
        elseif direction == Direction.UP then
            target_i = target_i - 1
        else
            return nil
        end
    else
        if direction == Direction.RIGHT then
            target_i = target_i + 1
        elseif direction == Direction.LEFT then
            target_i = target_i - 1
        else
            return nil
        end
    end

    return target_i
end

local function try_swap(direction)
    if not cursor_block.parent then
        return
    end

    local target_i = get_swap_target_i(direction)
    if not target_i then
        return
    end

    target_i = math.min(target_i, #cursor_block.parent.children)
    target_i = math.max(target_i, 1)

    local other = cursor_block.parent.children[target_i]

    if cursor_block:can_swap_with(other) then
        cursor_block.parent.children[cursor_i] = other
        cursor_block.parent.children[target_i] = cursor_block
        cursor_i = target_i

        root_block:update_tree(root_block.x, root_block.y)
    end
end

local function try_cut()
    local cut_block = cursor_block

    if not try_delete() then
        return
    end

    clipboard_block = cut_block:copy()
end

local function try_copy()
    if not cursor_block.parent then
        return
    end

    clipboard_block = cursor_block:copy()
end

local function try_paste()
    if not cursor_block.parent or not clipboard_block then
        return
    end

    if clipboard_block:can_swap_with(cursor_block) then
        cursor_block.parent.children[cursor_i] = clipboard_block:copy()
        cursor_block = cursor_block.parent.children[cursor_i]
    end

    root_block:update_tree(root_block.x, root_block.y)
end

local InteractionState = {
    CURSOR = 1,
    INSERT = 2,
}

local interaction_state = InteractionState.CURSOR
local insert_text = ""
local insert_direction = nil

local function start_insert_mode(direction)
    interaction_state = InteractionState.INSERT
    insert_direction = direction

    local target_i = get_insert_target_i(insert_direction)
    if not target_i or not is_insert_target_valid(direction, target_i) then
        interaction_state = InteractionState.CURSOR
        return
    end

    local default_child = get_insert_default_child(target_i)
    if not default_child then
        interaction_state = InteractionState.CURSOR
        return
    end

    if default_child.block_kind ~= Block.PIN then
        try_insert("", insert_direction)
        interaction_state = InteractionState.CURSOR
    end
end

local function update_cursor()
    local is_control_held = lyte.is_key_down("left_control") or lyte.is_key_down("right_control")
    local is_shift_held = lyte.is_key_down("left_shift") or lyte.is_key_down("right_shift")

    if is_control_held then
        if lyte.is_key_down("s") then
            local data = Writer:new()
            root_block:save(data)
            local data_string = data:to_string()

            lyte.save_textfile("save.lua", data_string)
        end

        return
    end

    if is_shift_held then
        if is_key_pressed_or_repeat("e") then
            try_swap(Direction.UP)
        elseif is_key_pressed_or_repeat("d") then
            try_swap(Direction.DOWN)
        elseif is_key_pressed_or_repeat("s") then
            try_swap(Direction.LEFT)
        elseif is_key_pressed_or_repeat("f") then
            try_swap(Direction.RIGHT)
        end
    else
        if is_key_pressed_or_repeat("e") then
            try_move_cursor_up()
        elseif is_key_pressed_or_repeat("d") then
            try_move_cursor_down()
        elseif is_key_pressed_or_repeat("s") then
            try_move_cursor_left()
        elseif is_key_pressed_or_repeat("f") then
            try_move_cursor_right()
        end
    end

    if is_key_pressed_or_repeat("i") then
        start_insert_mode(Direction.UP)
        return
    elseif is_key_pressed_or_repeat("k") then
        start_insert_mode(Direction.DOWN)
        return
    elseif is_key_pressed_or_repeat("j") then
        start_insert_mode(Direction.LEFT)
        return
    elseif is_key_pressed_or_repeat("l") then
        start_insert_mode(Direction.RIGHT)
        return
    end

    if lyte.is_key_pressed("x") then
        try_cut()
    end

    if lyte.is_key_pressed("c") then
        try_copy()
    end

    if lyte.is_key_pressed("v") then
        try_paste()
    end

    if lyte.is_key_pressed("space") then
        start_insert_mode(nil)
        return
    end

    if is_key_pressed_or_repeat("backspace") then
        try_delete()
    end
end

local function update_text_input(text)
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
        if try_insert(text, insert_direction) then
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
    Graphics.set_color(Theme.CURSOR_COLOR)
    lyte.draw_rect(display_text_width + 10, 5, Block.LINE_WIDTH, display_text_height)
end

function lyte.tick(dt, window_width, window_height)
    if interaction_state == InteractionState.INSERT then
        insert_text = update_text_input(insert_text)
    else
        update_cursor()
    end

    camera:update(dt, cursor_block, root_block, window_width, window_height)

    lyte.push_matrix()

    lyte.translate(-camera.x, -camera.y)
    lyte.scale(camera.zoom, camera.zoom)

    lyte.cls(Theme.BACKGROUND_COLOR.R, Theme.BACKGROUND_COLOR.G, Theme.BACKGROUND_COLOR.B, 1)

    root_block:draw(cursor_block, camera, window_height, 0)

    lyte.pop_matrix()

    Graphics.set_color(Theme.TEXT_COLOR)

    if interaction_state == InteractionState.INSERT then
        draw_text_input("Insert: ", insert_text)
    else
        lyte.set_font(Graphics.default_font)
        lyte.draw_text(camera.zoom * 100 .. "%", 10, 0)
    end
end