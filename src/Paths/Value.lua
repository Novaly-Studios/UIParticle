--!optimize 2
--!native

local function CreateValue<T>(Value: T)
    return function(_ParticleState)
        return Value
    end
end

return CreateValue