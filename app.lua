local Camera = {
    ZOOM_STEP = 0.1,
    PAN_SPEED = 150,
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

function Camera:update(dt)
    if lyte.is_key_pressed("page_up") then
        self.zoom = self.zoom + Camera.ZOOM_STEP
    end

    if lyte.is_key_pressed("page_down") then
        self.zoom = self.zoom - Camera.ZOOM_STEP
    end

    local pan_x = 0
    local pan_y = 0
    if lyte.is_key_down("left") then pan_x = pan_x - 1 end
    if lyte.is_key_down("right") then pan_x = pan_x + 1 end
    if lyte.is_key_down("up") then pan_y = pan_y - 1 end
    if lyte.is_key_down("down") then pan_y = pan_y + 1 end

    local pan_magnitude = math.sqrt(pan_x * pan_x + pan_y * pan_y)
    if pan_magnitude ~= 0 then
        pan_x = pan_x / pan_magnitude
        pan_y = pan_y / pan_magnitude
    end

    self.x = self.x + pan_x * Camera.PAN_SPEED * dt
    self.y = self.y + pan_y * Camera.PAN_SPEED * dt
end

local PinKind = {
    TEXT = 1,
    VALUE = 2,
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
    PIN_COLOR = {
        R = 218 / 255,
        G = 218 / 255,
        B = 218 / 255,
    },
    PADDING = 8,

    ASSIGNMENT = {
        TEXT = "=",
        PINS = {
            PinKind.TEXT,
            PinKind.VALUE,
        },
    },
    PIN = {
        TEXT = "?",
        PINS = {},
    }
}

local default_font = lyte.load_font("Roboto-Regular.ttf", 36)
lyte.set_font(default_font)

function Block:new(kind, parent)
    local block = {
        kind = kind,
        parent = parent,
        children = {},
        x = 0,
        y = 0,
        text_width = lyte.get_text_width(kind.TEXT),
        width = 0,
        text_height = lyte.get_text_height(kind.TEXT),
        height = 0,
    }

    for i, _ in ipairs(block.kind.PINS) do
        block.children[i] = Block:new(Block.PIN, block)
    end

    setmetatable(block, self)
    self.__index = self

    return block
end

function Block:update_tree(x, y, to_block)
    -- if self.kind == Block.PIN then return end

    -- for _, child in ipairs(self.children) do
    --     if child == to_block then
    --         self:update_bounds(x, y)
    --         return
    --     end
    -- end

    local child_x = x + self.text_width + Block.PADDING
    local child_y = y + Block.PADDING

    for _, child in ipairs(self.children) do
        child_x = child_x + Block.PADDING

        child:update_tree(child_x, child_y, to_block)

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

function Block:draw(depth)
    if self.kind == Block.PIN then
        lyte.set_color(Block.PIN_COLOR.R, Block.PIN_COLOR.G, Block.PIN_COLOR.G, 1)
    else
        if depth % 2 == 0 then
            lyte.set_color(Block.EVEN_COLOR.R, Block.EVEN_COLOR.G, Block.EVEN_COLOR.G, 1)
        else
            lyte.set_color(Block.ODD_COLOR.R, Block.ODD_COLOR.G, Block.ODD_COLOR.G, 1)
        end
    end

    lyte.draw_rect(self.x - Block.PADDING, self.y - Block.PADDING, self.width, self.height)

    lyte.set_color(Block.TEXT_COLOR.R, Block.TEXT_COLOR.G, Block.TEXT_COLOR.G, 1)

    lyte.draw_text(self.kind.TEXT, self.x, self.y - Block.PADDING)

    for _, child in ipairs(self.children) do
        child:draw(depth + 1)
    end
end

local camera = Camera:new()

local root_block = Block:new(Block.ASSIGNMENT, nil)
local block_2 = Block:new(Block.ASSIGNMENT, root_block)
root_block.children[2] = block_2
local block_2_2 = Block:new(Block.ASSIGNMENT, block_2)
block_2.children[2] = block_2_2

root_block:update_tree(0, 0, block_2_2)

local cursor_block = root_block

function lyte.tick(dt, window_width, window_height)
    -- camera:update(dt)
    camera.x = cursor_block.x - window_width / 2 + cursor_block.width / 2
    camera.y = cursor_block.y - window_height / 2 + cursor_block.height / 2

    lyte.push_matrix()

    lyte.translate(-camera.x, -camera.y)
    lyte.scale(camera.zoom, camera.zoom)

    root_block:draw(0, 0, 0)

    lyte.pop_matrix()

    lyte.set_color(Block.TEXT_COLOR.R, Block.TEXT_COLOR.G, Block.TEXT_COLOR.G, 1)
    lyte.draw_text(camera.zoom * 100 .. "%", 10, 0)
end