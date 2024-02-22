--!optimize 2
--!native

local TweenService = game:GetService("TweenService")

local Types = require(script.Parent.Parent.Types)
    type ParticleState = Types.ParticleState

local function CreateTween<T>(Start: T, End: T, Time: number, EasingStyle: Enum.EasingStyle?, EasingDirection: Enum.EasingDirection?)
    EasingStyle = EasingStyle or Enum.EasingStyle.Linear
    EasingDirection = EasingDirection or Enum.EasingDirection.InOut

    return function(ParticleState: ParticleState)
        return Start + (End - Start) * TweenService:GetValue(ParticleState.Completion / Time, EasingStyle, EasingDirection)
    end
end

return CreateTween