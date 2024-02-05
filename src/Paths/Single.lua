--!optimize 2
--!native

local function CreateSingle<T>(Value: T)
    return function(_ParticleState)
        return Value
    end
end

return CreateSingle