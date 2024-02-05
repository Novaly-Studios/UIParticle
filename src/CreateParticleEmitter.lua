--!optimize 2
--!native

-- Allows easy command bar paste.
if (not script) then
	script = game:GetService("ReplicatedFirst").UIParty
end

local RunService = game:GetService("RunService")
local RandomGen = Random.new()

local Types = require(script.Parent.Types)
    type ParticleState = Types.ParticleState
    type Particle = Types.Particle

local DefaultTexture = {ID = "rbxassetid://487481260"}

local function DefaultTransparency()
    return 0
end

local function DefaultRotation()
    return 0
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
    local _Enabled = true

    local _BaseTimeScale = Config.TimeScale or 1

    -- TODO: port all ParticleEmitter Update to one RenderStepped connection.
    local function Update()
        local Cleanup

        -- TODO: can easily be multithreaded, convert.
        for Active, Root in _ActiveParticles do
            local CurrentTime = os.clock()
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
                -- Still simulate the next frame to ensure it reaches its final visual state.
            end

            local PreStep = Base.PreStep

            if (PreStep) then
                PreStep(Active)
            end

            -- Apply new visuals.
            Active.Completion = math.min(1, Elapsed / Lifetime)

            local Transparency = (Base.Transparency or DefaultTransparency)(Active)
            local Position = Base.Position(Active)
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
                local Duration = SpriteSheet.Duration
                local Bounce = SpriteSheet.Bounce
                local Cycle = Elapsed // Duration
                local Cells = SpriteSheet.Cells
                local TotalFrames = SpriteSheet.TotalFrames or (Cells.X * Cells.Y)
                local CellSize = Active.SpriteSheetCellSize
                local Frame = ((Elapsed * TotalFrames) // Duration + Active.SpriteSheetFrameOffset) % TotalFrames

                if (Bounce and Cycle % 2 == 1) then
                    Frame = TotalFrames - Frame - 1
                end

                Root.ImageRectOffset = Vector2.new(
                    (Frame % Cells.X) * CellSize.X,
                    (Frame // Cells.Y) * CellSize.Y
                )
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

    local function CreateParticle(Particle: Particle)
        local StartTime = os.clock()

        local Position = Particle.Position
        local Lifetime = Particle.Lifetime
        local Texture = Particle.Texture or DefaultTexture
            local SpriteSheet = Texture.SpriteSheet

        local ParticleRoot = Instance.new("ImageLabel")
        local FinalParticle = {
            ParticleDefinition = Particle;

            SpriteSheetFrameOffset = (SpriteSheet and (SpriteSheet.RandomStart and RandomGen:NextInteger(0, (SpriteSheet.TotalFrames or SpriteSheet.Cells.X * SpriteSheet.Cells.Y) - 1) or 0) or nil);
            SpriteSheetCellSize = (SpriteSheet and SpriteSheet.Size / SpriteSheet.Cells or nil);
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
        ParticleRoot.Image = Texture.ID

        local InitialPosition = Position(FinalParticle)
        ParticleRoot.Position = UDim2.fromScale(InitialPosition.X, InitialPosition.Y)

        local AspectRatio = (Particle.AspectRatio ~= nil and Particle.AspectRatio or 1)

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
                Child:Clone().Parent = ParticleRoot
            end
        end

        if (SpriteSheet) then
            ParticleRoot.ImageRectSize = FinalParticle.SpriteSheetCellSize
        end

        ParticleRoot.Parent = Config.EmitFrom
        _ActiveParticles[FinalParticle] = ParticleRoot
        _ParticleCount += 1
    end

    local _UpdateConnection = RunService.PostSimulation:Connect(Update)
    local _EmitTime = 1 / Config.Rate / (Config.TimeScale or 0)

    local _Accumulation = _EmitTime
    local _LastTime = os.clock()

    function self.SetEnabled(Enabled: boolean)
        _Enabled = Enabled

        if (Enabled) then
            _LastTime = os.clock()
        end
    end

    local function Emit(Count: number)
        for _ = 1, Count or 1 do
            CreateParticle(_ParticleDefinitionIsFunction and _ParticleDefinition(Config) or _ParticleDefinition)
        end
    end
    self.Emit = Emit

    function self.GetParticleCount()
        return _ParticleCount
    end

    local _EmitTimer = task.spawn(function()
        local InitialEmit = Config.InitialEmit

        if (InitialEmit) then
            Emit(InitialEmit)
        end

        while (true) do
            if ((not _Enabled) or (_EmitTime == math.huge) or (_EmitCount == 0)) then
                task.wait()
                continue
            end

            while (true) do
                local New = _Accumulation - _EmitTime

                if (New < 0) then
                    break
                end

                if (_EmitCount == 0) then
                    _Enabled = false
                    break
                end

                _EmitCount -= 1
                _Accumulation = New
                CreateParticle(_ParticleDefinitionIsFunction and _ParticleDefinition(Config) or _ParticleDefinition)
            end

            local NextTime = os.clock()
            _Accumulation += (NextTime - _LastTime)
            _LastTime = NextTime
            task.wait()
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

--[[ task.defer(function()
    local Paths = require(script.Paths)
    local RandomGen = Random.new()

    if (_G.LastParticleEmitter) then
        pcall(_G.LastParticleEmitter.Destroy)
    end

    local Colors = {
        Paths.Sequence({
            {Time = 0, Value = Color3.fromRGB(251, 206, 100)};
            {Time = 0.5, Value = Color3.fromRGB(251, 206, 100)};
            {Time = 1, Value = Color3.fromRGB(255, 255, 255)};
        }),
        Paths.Sequence({
            {Time = 0, Value = Color3.fromRGB(61, 131, 235)};
            {Time = 0.5, Value = Color3.fromRGB(61, 131, 235)};
            {Time = 1, Value = Color3.fromRGB(255, 255, 255)};
        }),
        Paths.Sequence({
            {Time = 0, Value = Color3.fromRGB(235, 139, 61)};
            {Time = 0.5, Value = Color3.fromRGB(235, 139, 61)};
            {Time = 1, Value = Color3.fromRGB(255, 255, 255)};
        })
    }

    _G.LastParticleEmitter = CreateParticleEmitter({
        TimeScale = 2;
        EmitFrom = game.StarterGui.ScreenGui.Frame;
        Rate = 60;

        ParticleDefinition = function()
            local Angle = RandomGen:NextNumber(0, math.pi * 2)
            local Direction = Vector2.new(math.sin(Angle), math.cos(Angle))

            return {
                Lifetime = 0.75;
                Texture = {
                    ID = "rbxassetid://13367535759";

                    SpriteSheet = {
                        RandomStart = false;
                        Duration = 0.75;
                        Cells = Vector2.new(4, 4);
                        Size = Vector2.new(1024, 1024);
                    };
                };
                Transparency = Paths.Sequence({
                    {Time = 0, Value = 1};
                    {Time = 0.1, Value = 0};
                    {Time = 0.9, Value = 0};
                    {Time = 1, Value = 1};
                });
                Position = Paths.Physics(Vector2.new(0.5, 0.5) + Direction * 0.2, Direction * 0.3, Vector2.zero);
                Rotation = Paths.Single(-math.deg(Angle));
                Color = Colors[RandomGen:NextInteger(1, #Colors)];
                Size = Paths.Sequence({
                    {Time = 0, Value = Vector2.new(0.4, 0.4)};
                    {Time = 1, Value = Vector2.new(0.2, 0.2)};
                });
            };
        end
    })
end) ]]

return CreateParticleEmitter