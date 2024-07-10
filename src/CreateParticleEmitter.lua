--!optimize 2
--!native

-- Allows easy command bar paste.
if (not script) then
	script = game:GetService("ReplicatedFirst").UIParty.CreateParticleEmitter
end

local RunService = game:GetService("RunService")
local RandomGen = Random.new()

local Types = require(script.Parent.Types)
    type ParticleState = Types.ParticleState
    type Particle = Types.Particle

local DefaultTexture = "rbxassetid://487481260"

local function DefaultTransparency()
    return 0
end

local function DefaultRotation()
    return 0
end

local function DefaultPosition()
    return Vector2.new(0.5, 0.5)
end

local function DefaultColor()
    return Color3.new(1, 1, 1)
end

export type EmitterConfig = {
    -- Properties of the particles which will be emitted.
    -- A function can be supplied, useful for controlling
    -- paired properties between a set of variations and
    -- things like emitter shape via initial Position.
    ParticleDefinition: Particle | ((EmitterConfig) -> (Particle));

    InitialEmit: number?;
    EmitCount: number?;
    TimeScale: number?;
    EmitFrom: GuiObject;
    Rate: number;

    -- TODO: Enabled
}

local function CreateParticleEmitter(Config: EmitterConfig)
    local self = {}

    local _ParticleDefinition = Config.ParticleDefinition
    local _ParticleDefinitionIsFunction = (typeof(_ParticleDefinition) == "function")
    local _EmitCount = Config.EmitCount or math.huge

    local _ActiveParticles: {[ParticleState]: ImageLabel} = {}
    local _ParticleCount = 0
    local _VisualEnabled = true
    local _Enabled = true

    local _BaseTimeScale = Config.TimeScale or 1
    local _PreUpdate = Instance.new("BindableEvent")

    -- TODO: port all ParticleEmitter Update to one RenderStepped connection.
    local function Update()
        _PreUpdate:Fire()

        local Cleanup
        local CurrentTime = os.clock()

        -- TODO: can easily be multithreaded, convert.
        for Active, Root in _ActiveParticles do
            local TimeScale = Active.TimeScale
            local Base = Active.ParticleDefinition

            -- Some path controllers need to know TimeScale.
            if (not TimeScale) then
                Active.TimeScale = _BaseTimeScale
                TimeScale = _BaseTimeScale
            end

            local StartTime = Active.StartTime
            local Lifetime = Active.Lifetime
            local Elapsed = (CurrentTime - StartTime) * TimeScale

            if (Elapsed >= Lifetime) then
                Elapsed = Lifetime
                Cleanup = Cleanup or {}
                table.insert(Cleanup, {Active, Root})
                continue
            end

            local PreStep = Base.PreStep

            if (PreStep) then
                PreStep(Active)
            end

            -- Apply new visuals.
            Active.Completion = math.min(1, Elapsed / Lifetime)

            local Transparency = (Base.Transparency or DefaultTransparency)(Active)
            local Position = (Base.Position or DefaultPosition)(Active)
            local Rotation = (Base.Rotation or DefaultRotation)(Active)
            local Color = (Base.Color or DefaultColor)(Active)
            local Size = Base.Size(Active)

            if (Active._LastTransparency ~= Transparency) then
                Active._LastTransparency = Transparency
                Root.ImageTransparency = Transparency
            end

            if (Active._LastColor ~= Color) then
                Active._LastColor = Color
                Root.ImageColor3 = Color
            end

            if (Active._LastRotation ~= Rotation) then
                Active._LastRotation = Rotation
                Root.Rotation = Rotation
            end

            if (Active._LastSize ~= Size) then
                Active._LastSize = Size
                Root.Size = UDim2.fromScale(Size.X, Size.Y)
            end

            if (Active._LastPosition ~= Position) then
                Active._LastPosition = Position
                Root.Position = UDim2.fromScale(Position.X, Position.Y)
            end

            -- Apply sprite sheet texture offset.
            local SpriteSheet = Active.SpriteSheet

            if (SpriteSheet) then
                local Completion = math.min(Active.Completion, 0.99999999) / (SpriteSheet.SpeedMultiplier or 1)

                local Repetitions = SpriteSheet.Repetitions or 1
                local FreezeFrame = SpriteSheet.FreezeFrame
                local ImageSize = SpriteSheet.ImageSize
                local CellSize = SpriteSheet.CellSize
                local Sheets = SpriteSheet.Sheets
                    local SheetCount = #Sheets
                local Cells = ImageSize / CellSize

                local FramesPerRepetition = (Cells.X * Cells.Y) * SheetCount
                local TotalFrames = Repetitions * FramesPerRepetition - (SpriteSheet.SkipLastFrames or 0)
                local CurrentRepetitionFrame = FreezeFrame or (math.floor(Completion * TotalFrames) % FramesPerRepetition)
                local SheetIndex = math.min(math.floor(CurrentRepetitionFrame / FramesPerRepetition * SheetCount) + 1, SheetCount)
                local XOffset = CurrentRepetitionFrame % Cells.X * CellSize.X
                local YOffset = (CurrentRepetitionFrame // Cells.Y) % Cells.Y * CellSize.Y
                Root.Image = Sheets[SheetIndex]
                Root.ImageRectOffset = Vector2.new(XOffset, YOffset)
            end

            local PostStep = Base.PostStep

            if (PostStep) then
                PostStep(Active)
            end
        end

        if (not Cleanup) then
            return
        end

        for _, Pair in Cleanup do
            Pair[2]:Destroy()
            _ActiveParticles[Pair[1]] = nil
            _ParticleCount -= 1
        end
    end

    local function CreateParticle(Particle: Particle?)
        if (not Particle) then
            return
        end

        local StartTime = os.clock()

        local Position = Particle.Position
        local Lifetime = Particle.Lifetime
        local Texture = Particle.Texture or DefaultTexture
        local SpriteSheet = (type(Texture) == "table" and Texture or nil)
            local Cells = (SpriteSheet and SpriteSheet.ImageSize / SpriteSheet.CellSize)

        local ParticleRoot = Instance.new("ImageLabel")
        local FinalParticle = {
            ParticleDefinition = Particle;

            SpriteSheetFrameOffset = (SpriteSheet and (SpriteSheet.RandomStart and RandomGen:NextInteger(0, (SpriteSheet.TotalFrames or (Cells.X * Cells.Y)) - 1) or 0) or nil);
            SpriteSheet = SpriteSheet;

            Completion = 0;
            TimeScale = nil;
            StartTime = StartTime;
            Instance = ParticleRoot;
            Position = Position;
            Lifetime = Lifetime;

            _LastTransparency = nil;
            _LastRotation = nil;
            _LastPosition = nil;
            _LastColor = nil;
            _LastSize = nil;
        }

        ParticleRoot.BackgroundTransparency = 1
        ParticleRoot.ImageTransparency = 1
        ParticleRoot.AnchorPoint = Vector2.new(0.5, 0.5)

        if (not SpriteSheet) then
            ParticleRoot.Image = Texture
        end

        local InitialPosition = Position and Position(FinalParticle) or Vector2.new(0, 0)
        ParticleRoot.Position = UDim2.fromScale(InitialPosition.X, InitialPosition.Y)

        local AspectRatio = (if (Particle.AspectRatio ~= nil) then Particle.AspectRatio else 1)

        if (AspectRatio) then
            local Result = Instance.new("UIAspectRatioConstraint")
            Result.AspectRatio = AspectRatio
            Result.Parent = ParticleRoot
        end

        local RootProperties = Particle.RootProperties

        if (RootProperties) then
            for Key, Value in RootProperties do
                ParticleRoot[Key] = Value
            end
        end

        local RootChildren = Particle.RootChildren

        if (RootChildren) then
            for _, Child in RootChildren do
                Child.Parent = ParticleRoot
            end
        end

        local RootChildrenCopy = Particle.RootChildrenCopy

        if (RootChildrenCopy) then
            for _, Child in RootChildrenCopy do
                Child:Clone().Parent = ParticleRoot
            end
        end

        if (SpriteSheet) then
            ParticleRoot.ImageRectSize = SpriteSheet.CellSize
        end

        ParticleRoot.Parent = Config.EmitFrom
        _ActiveParticles[FinalParticle] = ParticleRoot
        _ParticleCount += 1
    end

    local _UpdateConnection = (RunService:IsRunning() and RunService.PostSimulation or RunService.Heartbeat):Connect(Update)
    local _EmitTime = 1 / Config.Rate / (Config.TimeScale or 1)

    local _Accumulation = _EmitTime
    local _LastTime = os.clock()

    local function Emit(Count: number)
        for _ = 1, Count or 1 do
            CreateParticle(if (_ParticleDefinitionIsFunction) then _ParticleDefinition(Config) else _ParticleDefinition)
        end
    end
    self.Emit = Emit

    function self.SetEnabled(Enabled: boolean)
        _Enabled = Enabled

        if (Enabled) then
            _Accumulation = 0
            _LastTime = os.clock()

            local InitialEmit = Config.InitialEmit

            if (InitialEmit) then
                Emit(InitialEmit)
            end
        end
    end

    function self.GetParticleCount()
        return _ParticleCount
    end

        -- Disable emitter if the GUI is not visible.
        do
            local Connections = {}
            local Visibility = {}
            local Parent = Config.EmitFrom
            local ID = 1
    
            local function _UpdateVisibility()
                local Enabled = true
                
                for _, Visible in Visibility do
                    if (not Visible) then
                        Enabled = false
                        break
                    end
                end
    
                if (Enabled) then
                    _Accumulation = 0
                    _LastTime = os.clock()

                    local InitialEmit = Config.InitialEmit

                    if (InitialEmit) then
                        Emit(InitialEmit)
                    end
                else
                    for _, Root in _ActiveParticles do
                        Root:Destroy()
                    end
    
                    _ActiveParticles = {}
                end
    
                _VisualEnabled = Enabled
            end
    
            while (Parent) do
                local TempParent = Parent
                local TempID = ID
    
                if (TempParent:IsA("GuiObject")) then
                    Visibility[TempID] = TempParent.Visible
    
                    table.insert(Connections, TempParent:GetPropertyChangedSignal("Visible"):Connect(function()
                        Visibility[TempID] = TempParent.Visible
                        _UpdateVisibility()
                    end))
                elseif (TempParent:IsA("GuiBase2d")) then
                    Visibility[TempID] = TempParent.Enabled
    
                    table.insert(Connections, TempParent:GetPropertyChangedSignal("Enabled"):Connect(function()
                        Visibility[TempID] = TempParent.Enabled
                        _UpdateVisibility()
                    end))
                end
    
                ID += 1
                Parent = Parent.Parent
            end
    
            _UpdateVisibility()
        end

    local _EmitTimer = task.spawn(function()
        local InitialEmit = Config.InitialEmit
        local WaitEvent = _PreUpdate.Event

        if (InitialEmit) then
            Emit(InitialEmit)
        end

        while (true) do
            if ((not (_Enabled and _VisualEnabled)) or (_EmitTime == math.huge) or (_EmitCount == 0)) then
                WaitEvent:Wait()
                continue
            end

            while (true) do
                local New = (_Accumulation - _EmitTime)

                if (New < 0) then
                    break
                end

                if (_EmitCount == 0) then
                    _Enabled = false
                    break
                end

                _EmitCount -= 1
                _Accumulation = New
                CreateParticle(if (_ParticleDefinitionIsFunction) then _ParticleDefinition(Config) else _ParticleDefinition)
            end

            local NextTime = os.clock()
            _Accumulation += (NextTime - _LastTime)
            _LastTime = NextTime
            WaitEvent:Wait()
        end
    end)

    function self.Destroy()
        if (not _UpdateConnection) then
            error("Particle system already destroyed")
        end

        task.cancel(_EmitTimer)
        _UpdateConnection:Disconnect()
        _UpdateConnection = nil

        for _, Root in _ActiveParticles do
            Root:Destroy()
        end
    end

    self.Create = CreateParticle
    return self
end

return CreateParticleEmitter