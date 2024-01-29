--!optimize 2
--!native

local RunService = game:GetService("RunService")
local RandomGen = Random.new()

local function Lerp(X, Y, T)
    if (typeof(X) == "Color3") then
        local Value = X:Lerp(Y, T)
        return Value
    end

    return X + (Y - X) * T
end

local function GetPairOnSequence<T>(Sequence: Sequence<T>, Time: number): T
    local Size = #Sequence

    if (Size == 1) then
        return Sequence[1].Value
    end

    if (Size == 2) then
        return Lerp(Sequence[1].Value, Sequence[2].Value, Time)
    end

    local Last = Sequence[1]
    local Next = Sequence[2]

    -- Will use binary search in future.
    for Index = 2, Size do
        local Current = Sequence[Index]

        if (Current.Time >= Time) then
            local LastTime = Last.Time
            return Lerp(Last.Value, Next.Value, (Time - LastTime) / (Next.Time - LastTime))
        end

        Last = Current
        Next = Sequence[Index + 1]
    end

    local LastTime = Last.Time
    return Lerp(Last.Value, Next.Value, (Time - LastTime) / (Next.Time - LastTime))
end

local PARTICLE_DEFAULTS = {
    Acceleration = {Min = Vector2.zero, Max = Vector2.zero};
    Transparency = {{Time = 0, Value = 0}};
    Velocity = {Min = Vector2.zero, Max = Vector2.zero};
    Rotation = {{Time = 0, Value = 0}};
    Texture = {ID = "rbxassetid://487481260"};
    Color = {{Time = 0, Value = Color3.new(1, 1, 1)}};
}

local function GetProperty(Particle: Particle, Key: string)
    return Particle[Key] or PARTICLE_DEFAULTS[Key]
end

type Sequence<T> = {{Time: number, Value: T}}
type Range<T> = {Min: T, Max: T}

type Texture = {
    ID: string;

    SpriteSheet: {
        Duration: number;
        Bounce: boolean?;
        Cells: Vector2;
        Size: Vector2;
    }?;
}

type Particle = {
    ModifyPostStep: ((Particle) -> (any))?;
    ModifyPreStep: ((Particle) -> (any))?;
    Transparency: Sequence<number>?;
    Acceleration: Range<Vector2>?;
    Velocity: Range<Vector2>?;
    Rotation: Sequence<number>?;
    Lifetime: Range<number>;
    Position: Vector2?;
    Texture: Texture?;
    Color: Sequence<Color3>?;
    Size: Sequence<Vector2>;
}

type ParticleState = {
    ParticleDefinition: Particle;

    _CellSize: Vector2?;

    _Acceleration: Vector2;
    _LastUpdate: number;
    _StartTime: number;
    _Velocity: Vector2;
    _Position: Vector2;
    _Lifetime: number;

    -- Cache values because Instances are slow.
    _LastTransparency: number;
    _LastRotation: number;
    _LastColor: Color3;
    _LastSize: Vector2;
}

type EmitterConfig = {
    -- Properties of the particles which will be emitted.
    -- A function can be supplied, useful for controlling
    -- paired properties between a set of variations and
    -- things like emitter shape via initial Position.
    ParticleDefinition: Particle | ((EmitterConfig) -> (Particle));

    TimeScale: number?;
    EmitFrom: GuiObject;
    Rate: number;
}

local function ParticleEmitter(Config: EmitterConfig)
    local self = {}

    local _ParticleDefinition = Config.ParticleDefinition
    local _ParticleDefinitionIsFunction = (typeof(_ParticleDefinition) == "function")

    local _ActiveParticles: {[ParticleState]: ImageLabel} = {}
    local _ParticleCount = 0
    local _Enabled = true

    -- TODO: port all ParticleEmitter Update to one RenderStepped connection.
    local function Update()
        local TimeScale = Config.TimeScale or 1
        local Cleanup

        -- TODO: can easily be multithreaded, convert.
        for Active, Root in _ActiveParticles do
            local Base = Active.ParticleDefinition

            local CurrentTime = os.clock()
            local StartTime = Active._StartTime
            local Lifetime = Active._Lifetime
            local Elapsed = (CurrentTime - StartTime) * TimeScale

            if (Elapsed >= Lifetime) then
                Elapsed = Lifetime
                Cleanup = Cleanup or {}
                table.insert(Cleanup, {Active, Root})
                -- Still simulate the next frame to ensure it reaches its final visual state.
            end

            local ModifyPreStep = GetProperty(Base, "ModifyPreStep")

            if (ModifyPreStep) then
                ModifyPreStep(Active)
            end

            -- Apply new visuals.
            local TimeMultiplier = math.min(1, Elapsed / Lifetime)

            local Transparency = GetPairOnSequence(GetProperty(Base, "Transparency"), TimeMultiplier)
            local Rotation = GetPairOnSequence(GetProperty(Base, "Rotation"), TimeMultiplier)
            local Color = GetPairOnSequence(GetProperty(Base, "Color"), TimeMultiplier)
            local Size = GetPairOnSequence(GetProperty(Base, "Size"), TimeMultiplier)

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
                Root.Rotation = math.deg(Rotation)
            end

            if (Active._LastSize ~= Size) then
                Active._LastSize = Size
                Root.Size = UDim2.fromScale(Size.X, Size.Y)
            end

            -- Apply movement.
            local Acceleration = Active._Acceleration
            local Velocity = Active._Velocity
            local Position = Active._Position

            local LastUpdate = Active._LastUpdate
            local DeltaTime = (CurrentTime - LastUpdate) * TimeScale
            local HalfDeltaTime = DeltaTime * 0.5

            local NewPosition = (Position + Velocity * DeltaTime + Acceleration * (DeltaTime * HalfDeltaTime))
            local NewVelocity = (Velocity + (Acceleration + Acceleration) * HalfDeltaTime)

            Active._LastUpdate = CurrentTime
            Active._Position = NewPosition
            Active._Velocity = NewVelocity

            Root.Position = UDim2.fromScale(NewPosition.X, NewPosition.Y)

            -- Apply sprite sheet texture offset.
            local SpriteSheet = Active._SpriteSheet

            if (SpriteSheet) then
                local Duration = SpriteSheet.Duration
                local Bounce = SpriteSheet.Bounce
                local Cycle = Elapsed // Duration
                local Cells = SpriteSheet.Cells
                local TotalFrames = SpriteSheet.TotalFrames or (Cells.X * Cells.Y)
                local CellSize = Active._CellSize
                local Frame = ((Elapsed * TotalFrames) // Duration) % TotalFrames

                if (Bounce and Cycle % 2 == 1) then
                    Frame = TotalFrames - Frame - 1
                end

                Root.ImageRectOffset = Vector2.new(
                    (Frame % Cells.X) * CellSize.X,
                    (Frame // Cells.Y) * CellSize.Y
                )
            end

            local ModifyPostStep = GetProperty(Base, "ModifyPostStep")

            if (ModifyPostStep) then
                ModifyPostStep(Active)
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

        local Acceleration = GetProperty(Particle, "Acceleration")
            local AccelerationMin = Acceleration.Min
            local AccelerationMax = Acceleration.Max

        local Velocity = GetProperty(Particle, "Velocity")
            local VelocityMin = Velocity.Min
            local VelocityMax = Velocity.Max

        local Lifetime = GetProperty(Particle, "Lifetime")
            local LifetimeMin = Lifetime.Min
            local LifetimeMax = Lifetime.Max

        local Position = GetProperty(Particle, "Position")

        local Texture = GetProperty(Particle, "Texture")
            local SpriteSheet = Texture.SpriteSheet

        local FinalParticle = {
            ParticleDefinition = Particle;
            
            _Acceleration = Vector2.new(
                RandomGen:NextNumber(AccelerationMin.X, AccelerationMax.X),
                RandomGen:NextNumber(AccelerationMin.Y, AccelerationMax.Y)
            );
            _Velocity = Vector2.new(
                RandomGen:NextNumber(VelocityMin.X, VelocityMax.X),
                RandomGen:NextNumber(VelocityMin.Y, VelocityMax.Y)
            );
            _SpriteSheet = SpriteSheet;
            _LastUpdate = StartTime;
            _StartTime = StartTime;
            _CellSize = (SpriteSheet and SpriteSheet.Size / SpriteSheet.Cells or nil);
            _Position = Position;
            _Lifetime = RandomGen:NextNumber(LifetimeMin, LifetimeMax);

            _LastTransparency = nil;
            _LastRotation = nil;
            _LastColor = nil;
            _LastSize = nil;
        }

        local ParticleRoot = Instance.new("ImageLabel")
        ParticleRoot.ImageTransparency = 1
        ParticleRoot.Image = Texture.ID
        ParticleRoot.ScaleType = (SpriteSheet and Enum.ScaleType.Crop or Enum.ScaleType.Stretch)
        ParticleRoot.BackgroundTransparency = 1
        ParticleRoot.AnchorPoint = Vector2.new(0.5, 0.5)
        ParticleRoot.Position = UDim2.fromScale(Position.X, Position.Y)
        ParticleRoot.SizeConstraint = Enum.SizeConstraint.RelativeYY

        if (SpriteSheet) then
            ParticleRoot.ImageRectSize = FinalParticle._CellSize
        end

        ParticleRoot.Parent = Config.EmitFrom

        _ActiveParticles[FinalParticle] = ParticleRoot
        _ParticleCount += 1
    end

    local _UpdateConnection = RunService.PostSimulation:Connect(Update)
    local _EmitTime = 1 / Config.Rate / (Config.TimeScale or 0)

    local _Accumulation = _EmitTime
    local _LastTime = os.clock()

    local _EmitTimer = task.spawn(function()
        while (true) do
            if (not _Enabled) then
                task.wait()
                continue
            end

            while (true) do
                local New = _Accumulation - _EmitTime

                if (New < 0) then
                    break
                end

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

    function self.SetEnabled(Enabled: boolean)
        _Enabled = Enabled
    end

    function self.Emit(Count: number)
        for _ = 1, Count do
            CreateParticle(_ParticleDefinitionIsFunction and _ParticleDefinition(Config) or _ParticleDefinition)
        end
    end

    function self.GetParticleCount()
        return _ParticleCount
    end

    self.Create = CreateParticle
    return self
end

return ParticleEmitter