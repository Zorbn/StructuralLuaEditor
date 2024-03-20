Geometry = {}

-- Lerp until you're already close enough.
-- Useful when you're lerping something visual, and you want to avoid artifacts like text jitter.
function Geometry.lazy_lerp(x, target_x, delta, stop_distance)
    local displacement = target_x - x

    if math.abs(displacement) < stop_distance then
        return x
    end

    x = x + displacement * delta
    return x
end