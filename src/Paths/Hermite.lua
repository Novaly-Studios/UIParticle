--!optimize 2
--!native

local Types = require(script.Parent.Parent.Types)
    type ParticleState = Types.ParticleState

local function HermiteInterpolate<T>(P0: T, P1: T, P2: T, P3: T, Mul: number, Tension: number?, Bias: number?): T
    Tension = 1 + (Tension or 0)
    Bias = Bias or 0

    local M0 = (P2 - P0) * Tension * (1 - Bias) / 2
    local M1 = (P3 - P1) * Tension * (1 + Bias) / 2

    local Mul2 = Mul * Mul
    local Mul3 = Mul2 * Mul

    return (2 * Mul3 - 3 * Mul2 + 1) * P1 + (Mul3 - 2 * Mul2 + Mul) * M0 + (-2 * Mul3 + 3 * Mul2) * P2 + (Mul3 - Mul2) * M1
end

local function HermiteInterpolatePiecewise<T>(Points: {T}, Completion: number, Tension: number?, Bias: number?): T?
    local Size = #Points

    if (Completion >= 1) then
        return Points[Size]
    end

    local Inner = Size - 3
    local StartIndex = math.floor(Inner * Completion + 1)
    local SegmentCompletion = (Completion - (StartIndex - 1) / Inner) * Inner

    return HermiteInterpolate(
        Points[StartIndex],
        Points[StartIndex + 1],
        Points[StartIndex + 2],
        Points[StartIndex + 3],
        SegmentCompletion,
        Tension,
        Bias
    )
end

local function CreateHermiteInterpolatePiecewise<T>(Points: {T}, Tension: number?, Bias: number?)
    return function(ParticleState: ParticleState)
        return HermiteInterpolatePiecewise(Points, ParticleState.Completion, Tension, Bias)
    end
end

return CreateHermiteInterpolatePiecewise