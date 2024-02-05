--!optimize 2
--!native

local Types = require(script.Parent.Parent.Types)
    type ParticleState = Types.ParticleState

type Sequence<T> = {{Time: number, Value: T}}

local function Lerp<T>(X: T, Y: T, Completion: number): T
    if (typeof(X) == "Color3") then
        local Value = X:Lerp(Y, Completion)
        return Value
    end

    return X + (Y - X) * Completion
end

local function GetPairOnSequence<T>(Sequence: Sequence<T>, Completion: number): T
    local Size = #Sequence

    if (Size == 1) then
        return Sequence[1].Value
    end

    Completion = math.clamp(Completion, 0, 1)

    if (Size == 2) then
        return Lerp(Sequence[1].Value, Sequence[2].Value, Completion)
    end

    for Index, Current in Sequence do
        if (Current.Time < Completion) then
            continue
        end

        local Last = Sequence[Index - 1] or Sequence[1]
        local LastTime = Last.Time
        return Lerp(Last.Value, Current.Value, (Completion - LastTime) / (Current.Time - LastTime))
    end

    error("Unreachable")
end

local function CreateSequence<T>(Sequence: Sequence<T>)
    return function(ParticleState: ParticleState): T
        return GetPairOnSequence(Sequence, ParticleState.Completion)
    end
end

return CreateSequence