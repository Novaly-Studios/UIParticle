export type Path<T> = ((any) -> (T))

type SpriteSheetDefinition = {
    SkipLastFrames: number?;
    RandomStart: boolean?;
    ImageSize: Vector2;
    Duration: number;
    CellSize: Vector2;
    Sheets: {string};
    Bounce: boolean?;
}

export type Texture = string | SpriteSheetDefinition

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

    RootChildrenCopy: {GuiObject}?;
    RootProperties: {[string]: any}?;
    RootChildren: {GuiObject}?;
}

export type ParticleState = {
    ParticleDefinition: Particle;

    SpriteSheetFrameOffset: number?;
    SpriteSheetCellSize: Vector2?;
    SpriteSheet: SpriteSheetDefinition?;

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