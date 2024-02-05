--!optimize 2
--!native

local Types = require(script.Parent.Parent.Types)
    type ParticleState = Types.ParticleState

local function Lerp<T>(X: T, Y: T, Completion: number): T
    return X + (Y - X) * Completion
end

local function Bezier<T>(Points: {T}, Completion: number): T?
    local Copy = table.clone(Points)
    Completion = math.clamp(Completion, 0, 1)

    -- Rewrite without creating new point tables
    while (true) do
        local Size = #Copy

        if (Size <= 1) then
            return Copy[1]
        end

        for Point = 1, Size - 1 do
            Copy[Point] = Lerp(Copy[Point], Copy[Point + 1], Completion)
        end

        table.remove(Copy, Size)
    end

    return Copy[1]
end

local function CreateBezier<T>(Points: {T})
    return function(ParticleState: ParticleState)
        return Bezier(Points, ParticleState.Completion)
    end
end

return CreateBezier