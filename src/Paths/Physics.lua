--!optimize 2
--!native

local Types = require(script.Parent.Parent.Types)
    type ParticleState = Types.ParticleState

local function CreatePhysics<T>(StartPoint: T, Velocity: T, Acceleration: T?)
    Acceleration = Acceleration or (Velocity - Velocity)

    return function(ParticleState: ParticleState)
        local Completion = ParticleState.Completion
        return StartPoint + (Velocity * Completion) + (Acceleration * (Completion * Completion))
    end
end

return CreatePhysics