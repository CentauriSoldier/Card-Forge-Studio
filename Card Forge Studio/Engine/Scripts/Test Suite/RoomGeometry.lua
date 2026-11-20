--[[!
@fqxn CardForgeEngine.TestSuite.RoomGeometry
@desc Checks the reusable scene and camera with no native graphics context.
!]]
local RoomGeometry = {};

--[[!
@fqxn CardForgeEngine.TestSuite.RoomGeometry.run
@desc Verifies editable tabletop bounds, isolated geometry and perspective projection.
@ret string Summary of covered behavior.
!]]
function RoomGeometry.run()
    local oRoom = CardForgeEngine.GameRoom({
        Table = {X = 0.5, Z = -0.25, Width = 6, Depth = 4, Height = 1.8, RailWidth = 0.25},
        Materials = {Felt = {R = 21, G = 102, B = 129}},
    });
    local tTop = oRoom.getTabletop();
    assert(tTop.MinX == -2.25 and tTop.MaxX == 3.25 and tTop.MinZ == -2 and tTop.MaxZ == 1.5,
        "The playable surface must follow the configured table and inset.");
    local tGeometry = oRoom.getGeometry();

    -- The table uses a real horizontal world plane that can later host cards.
    for _, tVertex in ipairs(tGeometry.Surface.Vertices) do
        assert(tVertex.Y == tTop.Y and tTop.Y == 1.8, "The tabletop must be level at its configured height.");
    end
    tGeometry.Surface.Vertices[1].Y = 0;
    tGeometry.Materials.Felt.B = 0;
    local tFresh = oRoom.getGeometry();
    assert(tFresh.Surface.Vertices[1].Y == 1.8 and tFresh.Materials.Felt.B == 129,
        "A renderer must be able to change its geometry snapshot without changing the room.");
    assert(not pcall(CardForgeEngine.GameRoom, {Table = {Width = 100}}), "A table must fit in the room.");

    local oCamera = CardForgeEngine.PerspectiveCamera({
        Position = {X = 0, Y = 0, Z = 0},
        Target   = {X = 0, Y = 0, Z = -1},
        Fov = 60,
    });
    local tCenter = oCamera.project({X = 0, Y = 0, Z = -2}, 800, 600);
    local tNear = oCamera.project({X = 1, Y = 1, Z = -2}, 800, 600);
    local tFar  = oCamera.project({X = 1, Y = 1, Z = -4}, 800, 600);
    assert(tCenter.X == 400 and tCenter.Y == 300, "The camera target must project to the viewport center.");
    assert(tNear.X > tFar.X and tNear.Y < tFar.Y and tNear.Depth < tFar.Depth,
        "Farther points should project closer to the center.");
    assert(oCamera.project({X = 0, Y = 0, Z = 1}, 800, 600) == nil,
        "Points behind the camera must not project.");

    return "Editable room geometry, detached snapshots, tabletop placement, and perspective projection.";
end

return RoomGeometry;
