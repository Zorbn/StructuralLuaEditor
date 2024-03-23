Lexer = {}

function Lexer:new(data)
    local lexer = {
        data = data,
        current = "",
        position = 1,
    }

    setmetatable(lexer, self)
    self.__index = self

    lexer.current = lexer:read()

    return lexer
end

function Lexer:char()
    return self.data:sub(self.position, self.position)
end

function Lexer:peek()
    return self.current
end

function Lexer:next()
    local token = self.current
    self.current = self:read()

    return token
end

function Lexer:read()
    while self:char():match("%s") do
        self.position = self.position + 1
    end

    if self:char():match("%a") then
        -- This is an identifier.
        -- TODO: Identifiers should not contain ., :, etc. I'm just doing this right now as a quick hack. Those should be blocks, ie: (. a b c d) == a.b.c.d

        local start = self.position

        while self:char():match("%w") or self:char() == "_" or self:char() == "." or self:char() == ":" do
            self.position = self.position + 1
        end

        local finish = self.position - 1

        return self.data:sub(start, finish):gsub("_", " ")
    end

    if self:char() == "\"" then
        -- This is a string.

        local start = self.position
        self.position = self.position + 1

        while self:char() ~= "\"" do
            self.position = self.position + 1
        end

        local finish = self.position
        self.position = self.position + 1

        return self.data:sub(start, finish)
    end

    if self:char():match("%d") then
        -- This is a number.

        local start = self.position
        local has_decimal = false

        while self:char():match("%d") or (not has_decimal and self:char() == ".") do
            if self:char() == "." then
                has_decimal = true
            end

            self.position = self.position + 1
        end

        local finish = self.position - 1

        return self.data:sub(start, finish)
    end

    -- TODO:
    -- if self.position < #self.data then
    --     -- Check if this is a two character operator.
    -- end

    -- This is a single character.
    local char = self:char()
    self.position = self.position + 1
    return char
end