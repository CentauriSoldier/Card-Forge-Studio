local ipairs = ipairs;
local string = string;
local table  = table;
local Love = {};

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas.Love
@desc Version-specific LÖVE atlas writers. The initial target is LÖVE 11.5, using love.graphics.newImage and the six-number love.graphics.newQuad signature.
!]]

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas.Love.Functions.build_11_5
@desc Builds a Lua module targeting LÖVE 11.5. Require atlas.lua, then call its load function with the atlas folder relative to the game root. Returned entries contain image, quad, name, row, and face. Duplicate names remain distinct by row/face identifier.
@param table tAtlas Pages and frames.
@return string sText Lua source.
@note Future version-sensitive targets use separate documented functions. Compatibility requires testing in the named runtime.
!]]
function Love.build_11_5(tAtlas)
    local tLines = {'local Atlas = {target = "LÖVE", version = "11.5", pages = {}, frames = {}};'};
    for nIndex, tPage in ipairs(tAtlas.pages) do
        tLines[#tLines + 1] = string.format('Atlas.pages[%d] = {image = %q, width = %d, height = %d};', nIndex, tPage.name, tPage.width, tPage.height);
    end
    for _, tFrame in ipairs(tAtlas.frames) do
        tLines[#tLines + 1] = string.format('Atlas.frames[%q] = {name = %q, row = %d, face = %q, page = %d, x = %d, y = %d, width = %d, height = %d};', tFrame.id, tFrame.label, tFrame.row, tFrame.face, tFrame.page, tFrame.x, tFrame.y, tFrame.width, tFrame.height);
    end
    tLines[#tLines + 1] = [[
function Atlas.load(sDirectory)
    assert(type(sDirectory) == "string", "Supply the atlas folder relative to the LÖVE game root.");
    local sPrefix = sDirectory == "" and "" or sDirectory:gsub("[/\\]+$", "").."/";
    local tImages, tFrames = {}, {};
    for nIndex, tPage in ipairs(Atlas.pages) do
        local oImage = love.graphics.newImage(sPrefix..tPage.image);
        assert(oImage:getWidth() == tPage.width and oImage:getHeight() == tPage.height, "Atlas page dimensions changed.");
        tImages[nIndex] = oImage;
    end
    for sID, tFrame in pairs(Atlas.frames) do
        local tPage = Atlas.pages[tFrame.page];
        tFrames[sID] = {image = tImages[tFrame.page], quad = love.graphics.newQuad(tFrame.x, tFrame.y, tFrame.width, tFrame.height, tPage.width, tPage.height), name = tFrame.name, row = tFrame.row, face = tFrame.face};
    end
    return tFrames;
end
return Atlas;
]];
    return table.concat(tLines, '\n');
end

return Love;