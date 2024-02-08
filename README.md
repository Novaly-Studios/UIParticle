# UIParty

A particle emitter system for Roblox UIs.

## Examples

Baseline demonstration of the library's capabilities:

```lua
local UIParty = require(...:WaitForChild("UIParty"))
    local CreateParticleEmitter = UIParty.CreateParticleEmitter
    local Paths = UIParty.Paths

local RandomGen = Random.new()
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

local Emitter = CreateParticleEmitter({
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
            Rotation = Paths.Value(-math.deg(Angle));
            Color = Colors[RandomGen:NextInteger(1, #Colors)];
            Size = Paths.Sequence({
                {Time = 0, Value = Vector2.new(0.4, 0.4)};
                {Time = 1, Value = Vector2.new(0.2, 0.2)};
            });
        };
    end
})

task.delay(10, Emitter.Destroy)
```

## Todo

### Important

- [ ] Function documentation
- [ ] Examples folder

### Short Term

- [ ] Preset emission shapes (Radial, Rectangular, ...)
- [ ] Framerate-based emission downscaling
- [ ] Multithreaded update support

### Long Term

- [ ] Particle editor plugin
- [ ] Other particle types (e.g. Text, Lightning, Water, Polygonal)
- [ ] Density combination
