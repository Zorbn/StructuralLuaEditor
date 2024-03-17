--[[

TODO:
- Make text insertion only allow valid characters,
- Make text insertion use space instead of underscores, which will be converted to underscores
  behind the scenes for final Lua code.

]]--

local Camera = {
    ZOOM_STEP = 0.2,
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
    local target_x = cursor_block.x - window_width / 2 + cursor_block.text_width / 2
    local target_y = cursor_block.y - window_height / 2 + cursor_block.text_height / 2

    self.x = self.x + (target_x - self.x) * Camera.PAN_SPEED * dt
    self.y = self.y + (target_y - self.y) * Camera.PAN_SPEED * dt

    if lyte.is_key_pressed("page_up") then
        self.zoom = self.zoom + Camera.ZOOM_STEP
    end

    if lyte.is_key_pressed("page_down") then
        self.zoom = self.zoom - Camera.ZOOM_STEP
    end
end

local PinKind = {
    PIN = 1,
    EXPRESSION = 2,
    STATEMENT = 3,
}

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
        TEXT = "?",
        PIN_KIND = PinKind.PIN,
        PINS = {},
    },
    ASSIGNMENT = {
        TEXT = "=",
        KIND = PinKind.STATEMENT,
        PINS = {
            PinKind.EXPRESSION,
            PinKind.EXPRESSION,
        },
    },
    ADD = {
        TEXT = "+",
        PIN_KIND = PinKind.EXPRESSION,
        PINS = {
            PinKind.EXPRESSION,
            PinKind.EXPRESSION,
        },
    },
    TEXT = {
        TEXT = "",
        PIN_KIND = PinKind.EXPRESSION,
        PINS = {},
    }
}

local PIN_BLOCKS = {
    [PinKind.EXPRESSION] = {
        Block.ADD,
        Block.TEXT,
    },
    [PinKind.STATEMENT] = {
        Block.ASSIGNMENT,
    },
    [PinKind.PIN] = {
        Block.PIN,
    },
}

local function set_color(color)
    lyte.set_color(color.R, color.G, color.B, 1)
end

local default_font = lyte.load_font("Roboto-Regular.ttf", 36)
lyte.set_font(default_font)

function Block:new(kind, parent)
    local block = {
        text = kind.TEXT,
        kind = kind,
        parent = parent,
        children = {},
        x = 0,
        y = 0,
        text_width = 0,
        width = 0,
        text_height = 0,
        height = 0,
    }

    for i, _ in ipairs(block.kind.PINS) do
        block.children[i] = Block:new(Block.PIN, block)
    end

    setmetatable(block, self)
    self.__index = self

    block:update_text_size()

    return block
end

function Block:update_text_size()
    self.text_width = lyte.get_text_width(self.text)
    self.text_height = lyte.get_text_height(self.text)
end

function Block:update_tree(x, y)
    local child_x = x + self.text_width + Block.PADDING
    local child_y = y + Block.PADDING

    for _, child in ipairs(self.children) do
        child_x = child_x + Block.PADDING

        child:update_tree(child_x, child_y)

        child_x = child_x + child.width
    end

    self:update_bounds(x, y)
end

function Block:update_bounds(x, y)
    self.x = x
    self.y = y

    self.width = self.text_width
    self.height = self.text_height

    for _, child in ipairs(self.children) do
        self.width = self.width + Block.PADDING + child.width
        self.height = math.max(self.height, child.height)
    end

    self.width = self.width + Block.PADDING * 2
    self.height = self.height + Block.PADDING * 2
end

function Block:draw(cursor_block, depth)
    if self == cursor_block then
        set_color(Block.CURSOR_COLOR)
    elseif self.kind == Block.PIN then
        set_color(Block.PIN_COLOR)
    else
        if depth % 2 == 0 then
            set_color(Block.EVEN_COLOR)
        else
            set_color(Block.ODD_COLOR)
        end
    end

    lyte.draw_rect(self.x - Block.PADDING, self.y - Block.PADDING, self.width, self.height)

    set_color(Block.TEXT_COLOR)

    lyte.draw_text(self.text, self.x, self.y - Block.PADDING)

    for _, child in ipairs(self.children) do
        child:draw(cursor_block, depth + 1)
    end
end

local camera = Camera:new()

local root_block = Block:new(Block.ASSIGNMENT, nil)
local block_2 = Block:new(Block.ADD, root_block)
root_block.children[2] = block_2
local block_2_2 = Block:new(Block.ADD, block_2)
block_2.children[2] = block_2_2

root_block:update_tree(0, 0)

local cursor_block = root_block

local function try_move_cursor_up()
    if cursor_block.parent then
        cursor_block = cursor_block.parent
        return true
    end

    return false
end

local function try_move_cursor_down()
    if cursor_block.children[1] then
        cursor_block = cursor_block.children[1]
        return true
    end

    return false
end

local function try_move_cursor_left()
    if cursor_block.parent then
        for i, child in ipairs(cursor_block.parent.children) do
            if child == cursor_block and i > 1 then
                cursor_block = cursor_block.parent.children[i - 1]
                return true
            end
        end
    end

    return false
end

local function try_move_cursor_right()
    if cursor_block.parent then
        for i, child in ipairs(cursor_block.parent.children) do
            if child == cursor_block and i < #cursor_block.parent.children then
                cursor_block = cursor_block.parent.children[i + 1]
                return true
            end
        end
    end

    return false
end

local function try_fill_pin(search_text, do_insert)
    if cursor_block.kind ~= Block.PIN then
        return
    end

    if cursor_block.parent == nil then
        return
    end

    local cursor_i = 1
    for i, child in ipairs(cursor_block.parent.children) do
        if child == cursor_block then
            cursor_i = i
            break
        end
    end

    local block_kind_choices = PIN_BLOCKS[cursor_block.parent.kind.PINS[cursor_i]]

    local chosen_block_kind = nil
    if do_insert then
        chosen_block_kind = Block.TEXT
    else
        for _, block_kind in ipairs(block_kind_choices) do
            if block_kind.TEXT == search_text then
                chosen_block_kind = block_kind
            end
        end
    end

    if chosen_block_kind ~= nil then
        cursor_block.parent.children[cursor_i] = Block:new(chosen_block_kind, cursor_block.parent)
        cursor_block = cursor_block.parent.children[cursor_i]

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
    if cursor_block.parent == nil then
        return
    end

    for i, child in ipairs(cursor_block.parent.children) do
        if child == cursor_block then
            cursor_block.parent.children[i] = Block:new(Block.PIN, cursor_block.parent)
            cursor_block = cursor_block.parent.children[i]
        end
    end

    root_block:update_tree(root_block.x, root_block.y)
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
    if lyte.is_key_pressed("up") then
        if not try_move_cursor_up() then
            try_move_cursor_left()
        end
    elseif lyte.is_key_pressed("down") then
        if not try_move_cursor_down() then
            try_move_cursor_right()
        end
    elseif lyte.is_key_pressed("left") then
        if not try_move_cursor_left() then
            try_move_cursor_up()
        end
    elseif lyte.is_key_pressed("right") then
        if not try_move_cursor_right() then
            try_move_cursor_down()
        end
    end

    if lyte.is_key_pressed("space") then
        interaction_state = InteractionState.SEARCH
        return
    end

    if lyte.is_key_pressed("enter") then
        interaction_state = InteractionState.INSERT
        return
    end

    if lyte.is_key_pressed("backspace") then
        try_delete()
    end
end

local function update_text_input(text, do_insert)
    text = text .. lyte.get_textinput()

    if lyte.is_key_pressed("backspace") or lyte.is_key_repeat("backspace") then
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