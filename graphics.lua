Graphics = {
    DEFAULT_FONT_SIZE = 26,
    DEFAULT_CODE_FONT_SIZE = 16,
    FONT_NAME = "DejaVuSans.ttf",
    code_font = nil,
    default_font = nil,
}

Graphics.default_font = lyte.load_font(Graphics.FONT_NAME, Graphics.DEFAULT_FONT_SIZE)

function Graphics.set_code_font(size)
    Graphics.code_font = lyte.load_font(Graphics.FONT_NAME, size)
    lyte.set_font(Graphics.code_font)
    collectgarbage("collect")
end

Graphics.set_code_font(Graphics.DEFAULT_CODE_FONT_SIZE)

function Graphics.draw_text(text, x, y, camera)
    lyte.set_font(Graphics.code_font)

    lyte.push_matrix()
    lyte.reset_matrix()
    lyte.translate(x * camera.zoom - camera.x, y * camera.zoom - camera.y)
    lyte.draw_text(text, 0, 0)
    lyte.pop_matrix()
end

function Graphics.set_color(color)
    lyte.set_color(color.R, color.G, color.B, 1)
end