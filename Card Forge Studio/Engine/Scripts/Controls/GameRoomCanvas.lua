--[[!
@fqxn CardForgeEngine.Controls.GameRoomCanvas
@desc Renders engine room geometry and textured tabletop objects to a buffered wxLuma viewport.
!]]
local _wx      = require("wx");
local _Surface = require("wxLuma.Core.ControlSurface");
local _nTextureSize = 256;
local _tHorizontalUV = {{U = 0, V = 0}, {U = 0, V = 1}, {U = 1, V = 1}, {U = 1, V = 0}};
local _tVerticalUV   = {{U = 0, V = 1}, {U = 1, V = 1}, {U = 1, V = 0}, {U = 0, V = 0}};
local GameRoomCanvas = {};

--[[!
@fqxn CardForgeEngine.Controls.GameRoomCanvas.loadMaterials
@desc Decodes and prefilters PNGs, preserving aspect ratio. The supplied cache
    shares decoded and shaded textures across objects in the same batch.
!]]
local function loadMaterials(tMaterials, pRoot, tCache)
    local tResult = {};
    tCache = tCache or {};

    for sName, tMaterial in pairs(tMaterials) do
        local tEntry = {Colour = string.char(tMaterial.R, tMaterial.G, tMaterial.B)};
        local pTexture = tMaterial.Texture;

        if (pRoot and pTexture) then
            local nLimit = tMaterial.TextureSize or _nTextureSize;
            local sKey = pTexture.."\0"..nLimit;
            local tSource = tCache[sKey];
            if (not tSource) then
                local oImage = _wx.wxImage(pRoot.."/"..pTexture, _wx.wxBITMAP_TYPE_PNG);
                if (not oImage:IsOk()) then
                    oImage:delete();
                    error("Cannot load scene texture: "..pTexture);
                end
                local nScale = math.min(1, nLimit / math.max(oImage:GetWidth(), oImage:GetHeight()));
                local nWidth = math.max(1, math.floor(oImage:GetWidth() * nScale + 0.5));
                local nHeight = math.max(1, math.floor(oImage:GetHeight() * nScale + 0.5));
                local oScaled = oImage:Scale(nWidth, nHeight, _wx.wxIMAGE_QUALITY_HIGH);
                tSource = {Data = oScaled:GetData(), Width = nWidth, Height = nHeight, Shaded = {}};
                tCache[sKey] = tSource;
                oScaled:delete(); oImage:delete();
            end

            local nShade = tMaterial.Shade;
            local tTexture = tSource.Shaded[nShade];
            if (not tTexture) then
                local tChannels, tSamples = {}, {};
                for nChannel = 0, 255 do
                    tChannels[nChannel] = string.char(math.floor(nChannel * nShade + 0.5));
                end
                local sData = tSource.Data;
                for nOffset = 1, #sData, 3 do
                    local nRed, nGreen, nBlue = sData:byte(nOffset, nOffset + 2);
                    tSamples[#tSamples + 1] = tChannels[nRed]..tChannels[nGreen]..tChannels[nBlue];
                end
                tTexture = {Samples = tSamples, Width = tSource.Width, Height = tSource.Height};
                tSource.Shaded[nShade] = tTexture;
            end
            tEntry.Texture = tTexture;
        end

        tResult[sName] = tEntry;
    end

    return tResult;
end

--[[!
@fqxn CardForgeEngine.Controls.GameRoomCanvas.projectFace
@desc Projects a front-facing surface and carries the attributes needed for texturing.
!]]
local function projectFace(tFace, oCamera, nWidth, nHeight)
    local tVertices = tFace.Vertices;
    if (not oCamera.isFacing(tVertices)) then return; end

    local tUV = tFace.UV or (tVertices[1].Y == tVertices[3].Y and _tHorizontalUV or _tVerticalUV);
    local tPoints = oCamera.projectPolygon(tVertices, tUV, nWidth, nHeight);
    if (#tPoints < 3) then return; end

    local nDepth = 0;
    for _, tPoint in ipairs(tPoints) do nDepth = nDepth + tPoint.Depth; end

    return {Points = tPoints, Depth = nDepth / #tPoints, Material = tFace.Material};
end

--[[!
@fqxn CardForgeEngine.Controls.GameRoomCanvas.paintFace
@desc Rasterizes a convex face as clipped horizontal spans. Interpolating U/depth,
    V/depth and reciprocal depth keeps textures attached to the actual 3D surface.
!]]
local function paintFace(tRows, tFace, tMaterials, nWidth, nHeight)
    if (not tFace) then return; end

    local tPoints, tMaterial = tFace.Points, tMaterials[tFace.Material];
    local nTop, nBottom = math.huge, -math.huge;
    for _, tPoint in ipairs(tPoints) do
        nTop, nBottom = math.min(nTop, tPoint.Y), math.max(nBottom, tPoint.Y);
    end

    local tPixels = {};
    local tTexture = tMaterial.Texture;
    local tSamples = tTexture and tTexture.Samples;
    local nTextureWidth = tTexture and tTexture.Width;
    local nTextureHeight = tTexture and tTexture.Height;
    local floor, min, max = math.floor, math.min, math.max;
    for nRow = max(0, math.ceil(nTop - 0.5)), min(nHeight - 1, math.ceil(nBottom - 0.5) - 1) do
        local nY = nRow + 0.5;
        local nLeft, nRight = math.huge, -math.huge;
        local nLeftQ, nLeftU, nLeftV, nRightQ, nRightU, nRightV;
        local tPrevious = tPoints[#tPoints];

        for _, tCurrent in ipairs(tPoints) do
            if ((tPrevious.Y <= nY and nY < tCurrent.Y) or (tCurrent.Y <= nY and nY < tPrevious.Y)) then
                local nRatio = (nY - tPrevious.Y) / (tCurrent.Y - tPrevious.Y);
                local nX = tPrevious.X + (tCurrent.X - tPrevious.X) * nRatio;
                local nQ = tPrevious.Q + (tCurrent.Q - tPrevious.Q) * nRatio;
                local nU = tPrevious.UQ + (tCurrent.UQ - tPrevious.UQ) * nRatio;
                local nV = tPrevious.VQ + (tCurrent.VQ - tPrevious.VQ) * nRatio;
                if (nX < nLeft) then nLeft, nLeftQ, nLeftU, nLeftV = nX, nQ, nU, nV; end
                if (nX > nRight) then nRight, nRightQ, nRightU, nRightV = nX, nQ, nU, nV; end
            end
            tPrevious = tCurrent;
        end

        local nBegin = max(0, math.ceil(nLeft - 0.5));
        local nEnd = min(nWidth - 1, math.ceil(nRight - 0.5) - 1);

        if (nBegin <= nEnd) then
            local nCount = nEnd - nBegin + 1;
            local sSpan;
            if (tSamples) then
                local nWidthInverse = 1 / (nRight - nLeft);
                local nQStep = (nRightQ - nLeftQ) * nWidthInverse;
                local nUStep = (nRightU - nLeftU) * nWidthInverse;
                local nVStep = (nRightV - nLeftV) * nWidthInverse;
                local nOffset = nBegin + 0.5 - nLeft;
                local nQ = nLeftQ + nQStep * nOffset;
                local nU = nLeftU + nUStep * nOffset;
                local nV = nLeftV + nVStep * nOffset;

                for nPixel = 1, nCount do
                    local nScale = 1 / nQ;
                    local nTextureX = floor(nU * nScale * nTextureWidth);
                    local nTextureY = floor(nV * nScale * nTextureHeight);
                    -- In a clipped span the interpolated UVs are already in
                    -- range, except for rounding at the texture's outer edges.
                    if (nTextureX < 0) then nTextureX = 0;
                    elseif (nTextureX >= nTextureWidth) then nTextureX = nTextureWidth - 1; end
                    if (nTextureY < 0) then nTextureY = 0;
                    elseif (nTextureY >= nTextureHeight) then nTextureY = nTextureHeight - 1; end
                    tPixels[nPixel] = tSamples[nTextureY * nTextureWidth + nTextureX + 1];
                    nQ, nU, nV = nQ + nQStep, nU + nUStep, nV + nVStep;
                end
                sSpan = table.concat(tPixels, "", 1, nCount);
            else
                sSpan = tMaterial.Colour:rep(nCount);
            end

            local sRow = tRows[nRow + 1];
            tRows[nRow + 1] = sRow:sub(1, nBegin * 3)..sSpan..sRow:sub((nEnd + 1) * 3 + 1);
        end
    end
end

--[[!
@fqxn CardForgeEngine.Controls.GameRoomCanvas.paintLayer
@desc Paints visible faces of one furniture layer far-to-near.
!]]
local function paintLayer(tRows, tFaces, oCamera, nWidth, nHeight, tMaterials)
    local tProjected = {};
    for _, tFace in ipairs(tFaces) do
        local tProjection = projectFace(tFace, oCamera, nWidth, nHeight);
        if (tProjection) then tProjected[#tProjected + 1] = tProjection; end
    end

    table.sort(tProjected, function(tLeft, tRight) return tLeft.Depth > tRight.Depth; end);
    for _, tFace in ipairs(tProjected) do paintFace(tRows, tFace, tMaterials, nWidth, nHeight); end
end

--[[!
@fqxn CardForgeEngine.Controls.GameRoomCanvas.floorMark
@desc Converts a room grid segment into a thin upward-facing strip on the floor.
!]]
local function floorMark(tLine)
    local tA, tB = tLine[1], tLine[2];
    local nX = tA.X == tB.X and 0.009 or 0;
    local nZ = tA.Z == tB.Z and 0.009 or 0;
    local tVertices = {
        {X = tA.X - nX, Y = tA.Y, Z = tA.Z - nZ},
        {X = tB.X - nX, Y = tB.Y, Z = tB.Z - nZ},
        {X = tB.X + nX, Y = tB.Y, Z = tB.Z + nZ},
        {X = tA.X + nX, Y = tA.Y, Z = tA.Z + nZ},
    };
    if (nZ > 0) then tVertices[2], tVertices[4] = tVertices[4], tVertices[2]; end
    return {Material = "FloorLine", Vertices = tVertices};
end

--[[!
@fqxn CardForgeEngine.Controls.GameRoomCanvas.render
@desc Paints one room frame, then resolves supersampled edges through wxImage.
    The smaller interactive frame keeps drag and wheel updates responsive.
!]]
local function render(tGeometry, tMaterials, tCards, oCamera, nWidth, nHeight, bMoving)
    local nMaxSize = math.max(nWidth, nHeight);
    local nScale = bMoving and math.min(1, 520 / nMaxSize) or math.min(2, 1536 / nMaxSize);
    local nW, nH = math.max(1, math.floor(nWidth * nScale)), math.max(1, math.floor(nHeight * nScale));
    local sBackground = tMaterials.Background.Colour:rep(nW);
    local tRows = {};
    for nRow = 1, nH do tRows[nRow] = sBackground; end

    for _, tFace in ipairs(tGeometry.Architecture) do
        paintFace(tRows, projectFace(tFace, oCamera, nW, nH), tMaterials, nW, nH);
    end
    if (oCamera.isFacing(tGeometry.Architecture[3].Vertices)) then
        for _, tLine in ipairs(tGeometry.FloorLines) do
            paintFace(tRows, projectFace(floorMark(tLine), oCamera, nW, nH), tMaterials, nW, nH);
        end
    end
    paintFace(tRows, projectFace(tGeometry.Shadow, oCamera, nW, nH), tMaterials, nW, nH);
    paintLayer(tRows, tGeometry.Legs, oCamera, nW, nH, tMaterials);
    paintLayer(tRows, tGeometry.Table, oCamera, nW, nH, tMaterials);
    paintFace(tRows, projectFace(tGeometry.Surface, oCamera, nW, nH), tMaterials, nW, nH);
    paintLayer(tRows, tCards.Faces, oCamera, nW, nH, tCards.Materials);

    local oImage = _wx.wxImage(nW, nH);
    oImage:SetData(table.concat(tRows));
    local oResolved = oImage:Scale(nWidth, nHeight, bMoving and _wx.wxIMAGE_QUALITY_BILINEAR or _wx.wxIMAGE_QUALITY_HIGH);
    local oBitmap = _wx.wxBitmap(oResolved);
    oResolved:delete(); oImage:delete();
    return oBitmap;
end

--[[!
@fqxn CardForgeEngine.Controls.GameRoomCanvas.create
@desc Creates a reusable viewport with a cached room frame and swappable camera.
@param wxWindow oParent Native parent.
@param table tWxLuma The application's loaded framework.
@param CardForgeEngine.GameRoom oRoom World geometry.
@param CardForgeEngine.PerspectiveCamera oCamera View camera.
@param string pRoot Installation root containing the default material PNGs.
@ret table Surface exposing Control, setScene, setCamera and setCardMeshes.
!]]
function GameRoomCanvas.create(oParent, tWxLuma, oRoom, oCamera, pRoot)
    local oCanvas = _Surface.create(oParent, {Theme = tWxLuma.Theme, Border = _wx.wxBORDER_NONE}, "GameRoomCanvas");
    local tGeometry, tMaterials, oBitmap;
    local tCards = {Faces = {}, Materials = {}};
    local nLastWidth, nLastHeight;
    local bDirty, bMoving = true, false;

    --[[!
    @fqxn CardForgeEngine.Controls.GameRoomCanvas.setCamera
    @desc Queues a camera redraw, optionally favoring fast interactive rendering.
    !]]
    function oCanvas.setCamera(oNextCamera, bInteractive)
        assert(not oCanvas.Disposed, "The room canvas is disposed.");
        assert(class.isa(oNextCamera, "CardForgeEngine.PerspectiveCamera"), "Expected a PerspectiveCamera.");
        oCamera, bMoving, bDirty = oNextCamera, bInteractive == true, true;
        oCanvas.refresh();
        return oCanvas;
    end

    --[[!
    @fqxn CardForgeEngine.Controls.GameRoomCanvas.setScene
    @desc Loads another room and its default materials into this viewport.
    !]]
    function oCanvas.setScene(oNextRoom, oNextCamera)
        assert(class.isa(oNextRoom, "CardForgeEngine.GameRoom"), "Expected a GameRoom.");
        local tNextGeometry = oNextRoom.getGeometry();
        local tNextMaterials = loadMaterials(tNextGeometry.Materials, pRoot);
        oCanvas.setCamera(oNextCamera);
        tGeometry, tMaterials = tNextGeometry, tNextMaterials;
        return oCanvas;
    end

    --[[!
    @fqxn CardForgeEngine.Controls.GameRoomCanvas.setCardMeshes
    @desc Rebuilds the card layer from a dense list of meshes. Call again after
        changing a card's face-up state to update its presentation snapshot.
    @param table tMeshes Ordered array of CardMesh objects.
    !]]
    function oCanvas.setCardMeshes(tMeshes)
        assert(not oCanvas.Disposed, "The room canvas is disposed.");
        assert(rawtype(tMeshes) == "table", "Expected a list of card meshes.");
        local nCount = #tMeshes;
        for nIndex, oMesh in pairs(tMeshes) do
            assert(rawtype(nIndex) == "number" and nIndex % 1 == 0 and nIndex >= 1 and nIndex <= nCount
                and class.isa(oMesh, "CardForgeEngine.CardMesh"), "Expected a dense list of card meshes.");
        end

        local tNext = {Faces = {}, Materials = {}};
        local tCache = {};
        for nIndex = 1, nCount do
            local oMesh = assert(tMeshes[nIndex], "Card mesh list must not have gaps.");
            local tMesh = oMesh.getGeometry();
            local tMaterials = loadMaterials(tMesh.Materials, pRoot, tCache);
            local sPrefix = nIndex..":";

            -- Each mesh owns its material names even when its textures are shared.
            for sName, tMaterial in pairs(tMaterials) do
                tNext.Materials[sPrefix..sName] = tMaterial;
            end
            for _, tFace in ipairs(tMesh.Faces) do
                tFace.Material = sPrefix..tFace.Material;
                tNext.Faces[#tNext.Faces + 1] = tFace;
            end
        end

        tCards, bDirty = tNext, true;
        oCanvas.refresh();
        return oCanvas;
    end

    --[[!
    @fqxn CardForgeEngine.Controls.GameRoomCanvas.draw
    @desc Refreshes the cached frame when the scene, camera or viewport changes.
    !]]
    function oCanvas.draw(oDC, nWidth, nHeight)
        if (oCanvas.Disposed or nWidth <= 0 or nHeight <= 0) then return; end

        if (bDirty or nWidth ~= nLastWidth or nHeight ~= nLastHeight) then
            local oNext = render(tGeometry, tMaterials, tCards, oCamera, nWidth, nHeight, bMoving);
            if (oBitmap) then oBitmap:delete(); end
            oBitmap = oNext;
            nLastWidth, nLastHeight, bDirty = nWidth, nHeight, false;
        end
        oDC:DrawBitmap(oBitmap, 0, 0, false);
    end

    --[[!
    @fqxn CardForgeEngine.Controls.GameRoomCanvas.onDestroy
    @desc Releases the cached native frame before its parent destroys the surface.
    !]]
    function oCanvas.onDestroy()
        if (oBitmap) then oBitmap:delete(); oBitmap = nil; end
        tGeometry, tMaterials, tCards = nil, nil, nil;
    end

    oCanvas.Control:SetName("Game Room Canvas");
    return oCanvas.setScene(oRoom, oCamera);
end

return GameRoomCanvas;
