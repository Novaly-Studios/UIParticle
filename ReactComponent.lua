local ReplicatedFirst = game:GetService("ReplicatedFirst")
    local React = require(ReplicatedFirst:WaitForChild("React"))
        local useEffect = React.useEffect
        local useState = React.useState
        local element = React.createElement
        local useRef = React.useRef

local CreateParticleEmitter = require(script.Parent.CreateParticleEmitter)

return function(Props: { Config: CreateParticleEmitter.EmitterConfig, Disabled: boolean? })
    local Emitter, SetEmitter = useState(nil)
    local RootRef = useRef(nil)

    local Disabled = Props.Disabled
    local Config = Props.Config

    useEffect(function()
        local RootValue = RootRef.current

        if (not RootValue) then
            return
        end

        Config.EmitFrom = RootValue

        local EmitterObject = CreateParticleEmitter(Config)
        EmitterObject.SetEnabled(not Disabled)
        SetEmitter(EmitterObject)

        return function()
            EmitterObject.Destroy()
        end
    end, {true})

    useEffect(function()
        if (not Emitter) then
            return
        end

        Emitter.SetEnabled(not Disabled)
    end, {Disabled})

    return element("Frame", {
        BackgroundTransparency = 1;
        Size = UDim2.fromScale(1, 1);

        ref = RootRef;
    })
end