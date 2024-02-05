export type Path<T> = ((any) -> (T))

export type Texture = {
    ID: string;

    SpriteSheet: {
        RandomStart: boolean?;
        TotalFrames: number?; -- Useful if you want to use a subset of the sprite sheet or the last row is not full.
        Duration: number;
        Bounce: boolean?;
        Cells: Vector2;
        Size: Vector2;
    }?;
}

export type Particle = {
    PostStep: ((Particle) -> (any))?;
    PreStep: ((Particle) -> (any))?;

    Transparency: Path<number>?;
    AspectRatio: number?;
    Rotation: Path<number>?;
    Lifetime: number;
    Position: Path<Vector2>?;
    Texture: Texture?;
    Color: Path<Color3>?;
    Size: Path<Vector2>;

    RootProperties: {[string]: any}?;
    RootChildren: {GuiObject}?;
}

export type ParticleState = {
    ParticleDefinition: Particle;

    SpriteSheetFrameOffset: number?;
    SpriteSheetCellSize: Vector2?;

    Completion: number;
    TimeScale: number;
    StartTime: number;
    Instance: ImageLabel;

    -- Cache values because Instances are slow.
    _LastTransparency: number;
    _LastPosition: Vector2;
    _LastRotation: number;
    _LastColor: Color3;
    _LastSize: Vector2;
}

return true