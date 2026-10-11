local ipairs = ipairs;
local string = string;
local table  = table;
local Generic = {};

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas.Generic
@desc Generic atlas format version 1: PNG pages and UTF-8 JSON rectangles measured from each page's top-left corner. No rotation or trimming is applied.
!]]

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas.Generic.Private.Functions.quote
@desc Escapes JSON names and control characters.
@vis private
@param string sValue Text.
@return string sJSON JSON string.
!]]
local function quote(sValue)
    return '"'..sValue:gsub('[%z\1-\31\\"]', function(sCharacter)
        if (sCharacter == '"' or sCharacter == '\\') then return '\\'..sCharacter; end
        return string.format('\\u%04x', sCharacter:byte());
    end)..'"';
end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas.Generic.Functions.build_1
@desc Builds Generic version 1 metadata. Page indices are one-based; pixel coordinates are zero-based. Frame rectangles exclude padding.
@param table tAtlas Pages and frames.
@return string sText JSON manifest.
!]]
function Generic.build_1(tAtlas)
    local tPages, tFrames = {}, {};
    for _, tPage in ipairs(tAtlas.pages) do
        tPages[#tPages + 1] = string.format('{"image":%s,"width":%d,"height":%d}', quote(tPage.name), tPage.width, tPage.height);
    end
    for _, tFrame in ipairs(tAtlas.frames) do
        tFrames[#tFrames + 1] = string.format('{"id":%s,"name":%s,"row":%d,"face":%s,"page":%d,"x":%d,"y":%d,"width":%d,"height":%d}', quote(tFrame.id), quote(tFrame.label), tFrame.row, quote(tFrame.face), tFrame.page, tFrame.x, tFrame.y, tFrame.width, tFrame.height);
    end
    return '{"format":"CFS Atlas","version":1,"origin":"top-left","rotated":false,"trimmed":false,"pages":['..table.concat(tPages, ',')..'],"frames":['..table.concat(tFrames, ',')..']}\n';
end

return Generic;