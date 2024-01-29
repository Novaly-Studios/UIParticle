# UIParty

A particle emitter system for Roblox UIs.

## Examples

Baseline demonstration of the library's capabilities:

```lua
local CreateParticleEmitter = require(...:WaitForChild("UIParty"))
local RandomGen = Random.new()
local Colors = {
    {
        {Time = 0, Value = Color3.fromRGB(251, 206, 100)};
        {Time = 0.5, Value = Color3.fromRGB(251, 206, 100)};
        {Time = 1, Value = Color3.fromRGB(255, 255, 255)};
    },
    {
        {Time = 0, Value = Color3.fromRGB(61, 131, 235)};
        {Time = 0.5, Value = Color3.fromRGB(61, 131, 235)};
        {Time = 1, Value = Color3.fromRGB(255, 255, 255)};
    },
    {
        {Time = 0, Value = Color3.fromRGB(235, 139, 61)};
        {Time = 0.5, Value = Color3.fromRGB(235, 139, 61)};
        {Time = 1, Value = Color3.fromRGB(255, 255, 255)};
    }
}

local ParticleEmitter = CreateParticleEmitter({
    TimeScale = 2;
    EmitFrom = game.StarterGui.ScreenGui.Frame;
    Rate = 60;

    ParticleDefinition = function()
        local Angle = RandomGen:NextNumber(0, math.pi * 2)
        local Direction = Vector2.new(math.sin(Angle), math.cos(Angle))

        return {
            Transparency = {
                {Time = 0, Value = 1};
                {Time = 0.1, Value = 0};
                {Time = 0.9, Value = 0};
                {Time = 1, Value = 1};
            };
            Velocity = {Min = Direction * 0.3, Max = Direction * 0.3};
            Position = Vector2.new(0.5, 0.5) + Direction * 0.2;
            Lifetime = {Min = 0.75, Max = 0.75};
            Rotation = {
                {Time = 0, Value = -Angle};
            };
            Texture = {
                ID = "rbxassetid://13367535759";

                SpriteSheet = {
                    Duration = 0.75;
                    Cells = Vector2.new(4, 4);
                    Size = Vector2.new(1024, 1024);
                };
            };
            Color = Colors[RandomGen:NextInteger(1, #Colors)];
            Size = {
                {Time = 0, Value = Vector2.new(0.4, 0.4)};
                {Time = 1, Value = Vector2.new(0.2, 0.2)};
            };
        };
    end
})
```

## Todo

- [ ] Examples folder
- [ ] Preset emission shapes (Radial, Rectangular, ...)
- [ ] Paths (Linear, Bezier, Cubic, Spring, instead of only physics-based)
- [ ] Framerate-based emission downscaling
- [ ] Multithreaded update support
- [ ] Density combination
- [ ] Collisions
