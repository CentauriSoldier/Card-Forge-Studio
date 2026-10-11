local wx       = require("wx");
local Exporter = require("Exporter");
local PNG      = require("Exporters.ExporterPNG");
local Settings = require("Exporters.Atlas.Settings");
local Generic  = require("Exporters.Atlas.Generic");
local Love     = require("Exporters.Atlas.Love");
local assert   = assert;
local error    = error;
local ipairs   = ipairs;
local io       = io;
local math     = math;
local os       = os;
local string   = string;
local tostring = tostring;
local xpcall   = xpcall;
local debug    = debug;
local Atlas    = {};

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas
@desc Packs finished card artwork into PNG sheets with Generic version 1 JSON or LÖVE 11.5 Lua metadata. Cards remain unrotated and untrimmed. One pixel of duplicated edge artwork surrounds each frame to reduce filtering bleed, inside the configured padding. Sheets use a white background, matching the existing PNG renderer. Multiple sheets are produced when required. Options belong to the active card set; existing output files are never overwritten.
!]]

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas.Functions.load
@pulsarlua function ExporterAtlas.load
@desc Reads normalized per-card-set atlas settings.
@param string pInfo Metadata path.
@return table tOptions Settings.
!]]
function Atlas.load(pInfo) return Settings.load(pInfo); end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas.Functions.model
@pulsarlua function ExporterAtlas.model
@desc Creates a transactional settings draft that preserves unrelated metadata and rejects external edits.
@param string pInfo Metadata path.
@return table tModel Options and saveOptions.
!]]
function Atlas.model(pInfo) return Settings.model(pInfo); end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas.Functions.plan
@pulsarlua function ExporterAtlas.plan
@desc Plans fixed-size PNG pages and target metadata. Uses existing PNG front/back rules. Fails before rendering when a padded card cannot fit or dimensions exceed the pixel limit. Stable frame IDs use source row and face; names are retained as labels.
@param table tRows Ordered source rows.
@param table tOptions Atlas settings.
@param table tNames Source-row names.
@param number nTotal Source row count.
@param number nWidth Native card width.
@param number nHeight Native card height.
@return table tPlan Output records and atlas layout.
!]]
function Atlas.plan(tRows, tOptions, tNames, nTotal, nWidth, nHeight)
    assert(tOptions.target == "Generic_1" or tOptions.target == "Love_11_5", "Unsupported atlas target version.");
    local nCardWidth, nCardHeight = PNG.dimensions(nWidth, nHeight, tOptions.scale);
    local nPageWidth, nPageHeight, nPadding = tOptions.pageWidth, tOptions.pageHeight, tOptions.padding;
    assert(nPageWidth >= 64 and nPageWidth <= 8192 and nPageWidth == math.floor(nPageWidth), "Invalid atlas page width.");
    assert(nPageHeight >= 64 and nPageHeight <= 8192 and nPageHeight == math.floor(nPageHeight), "Invalid atlas page height.");
    assert(nPageWidth * nPageHeight <= 64000000, "Atlas page exceeds 64 million pixels.");
    assert(nPadding >= 1 and nPadding <= 32 and nPadding == math.floor(nPadding), "Invalid atlas padding.");
    local nCellWidth, nCellHeight = nCardWidth + 2 * nPadding, nCardHeight + 2 * nPadding;
    local nColumns, nRows = math.floor(nPageWidth / nCellWidth), math.floor(nPageHeight / nCellHeight);
    assert(nColumns > 0 and nRows > 0, "Card plus padding does not fit the atlas page. Increase the page size or reduce scale.");
    local tAtlas = {pages = {}, frames = {}, target = tOptions.target};
    local tPlan = {};
    for nIndex, tCard in ipairs(PNG.plan(tRows, tOptions, tNames, nTotal)) do
        local nPage = math.floor((nIndex - 1) / (nColumns * nRows)) + 1;
        local nSlot = (nIndex - 1) % (nColumns * nRows);
        if (not tAtlas.pages[nPage]) then
            local tPage = {name = string.format("atlas_%03d.png", nPage), width = nPageWidth, height = nPageHeight, frames = {}};
            tAtlas.pages[nPage] = tPage; tPlan[#tPlan + 1] = tPage;
        end
        local tFrame = {id = string.format("row_%d_%s", tCard.row, tCard.face), label = tostring(tNames[tCard.row] or "Card"), row = tCard.row, face = tCard.face, page = nPage,
            x = (nSlot % nColumns) * nCellWidth + nPadding, y = math.floor(nSlot / nColumns) * nCellHeight + nPadding, width = nCardWidth, height = nCardHeight};
        tAtlas.frames[#tAtlas.frames + 1] = tFrame;
        local tFrames = tAtlas.pages[nPage].frames; tFrames[#tFrames + 1] = tFrame;
    end
    tPlan[#tPlan + 1] = {name = tOptions.target == "Love_11_5" and "atlas.lua" or "atlas.json", metadata = true};
    tPlan.atlas = tAtlas;
    return tPlan;
end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas.Functions.render
@pulsarlua function ExporterAtlas.render
@desc Renders a frame through the existing isolated PNG renderer.
@param string sFace Front or back.
@param string pFile Temporary PNG path.
@param number nScale Percentage.
!]]
function Atlas.render(sFace, pFile, nScale) PNG.render(sFace, pFile, nScale); end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas.Private.Functions.paste
@desc Pastes one frame and duplicates its outermost pixels into a one-pixel border.
@vis private
@param any oPage Sheet image.
@param any oCard Card image.
@param table tFrame Rectangle.
!]]
local function paste(oPage, oCard, tFrame)
    local x, y, w, h = tFrame.x, tFrame.y, tFrame.width, tFrame.height;
    oPage:Paste(oCard, x, y);
    for _, tEdge in ipairs({{0, 0, w, 1, x, y - 1}, {0, h - 1, w, 1, x, y + h}, {0, 0, 1, h, x - 1, y}, {w - 1, 0, 1, h, x + w, y},
        {0, 0, 1, 1, x - 1, y - 1}, {w - 1, 0, 1, 1, x + w, y - 1}, {0, h - 1, 1, 1, x - 1, y + h}, {w - 1, h - 1, 1, 1, x + w, y + h}}) do
        local oEdge = oCard:GetSubImage(wx.wxRect(tEdge[1], tEdge[2], tEdge[3], tEdge[4]));
        oPage:Paste(oEdge, tEdge[5], tEdge[6]); oEdge:delete();
    end
end

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterAtlas.Functions.run
@pulsarlua function ExporterAtlas.run
@desc Renders pages and version-specific metadata through the shared staged coordinator. Temporary frame images are removed after success or failure. Final files are committed only after every page and manifest is produced.
@param string pDirectory Existing destination.
@param table tPlan Atlas plan.
@param function fRender Receives row, face, and temporary PNG path.
@param function|nil fProgress Shared output progress callback.
@return number nCount Committed output file count.
!]]
function Atlas.run(pDirectory, tPlan, fRender, fProgress)
    return Exporter.run(pDirectory, tPlan, function(tFile, pStage)
        if (tFile.metadata) then
            local sText = tPlan.atlas.target == "Love_11_5" and Love.build_11_5(tPlan.atlas) or Generic.build_1(tPlan.atlas);
            local oFile = assert(io.open(pStage, "wb"));
            local bWritten, sError = oFile:write(sText); local bClosed, sCloseError = oFile:close();
            assert(bWritten, sError); assert(bClosed, sCloseError); return;
        end
        local oPage, oCard, pCard;
        local bOK, sError = xpcall(function()
            oPage = wx.wxImage(tFile.width, tFile.height);
            assert(oPage:IsOk(), "Could not allocate atlas page.");
            oPage:SetRGB(wx.wxRect(0, 0, tFile.width, tFile.height), 255, 255, 255);
            local oTemporary = wx.wxFile();
            pCard = wx.wxFileName.CreateTempFileName(wx.wxFileName.GetTempDir().."/cfs-atlas-", oTemporary);
            if (oTemporary:IsOpened()) then oTemporary:Close(); end; oTemporary:delete();
            assert(pCard ~= "", "Could not stage atlas frame.");
            for _, tFrame in ipairs(tFile.frames) do
                fRender(tFrame.row, tFrame.face, pCard);
                oCard = wx.wxImage(pCard, wx.wxBITMAP_TYPE_PNG);
                assert(oCard:IsOk() and oCard:GetWidth() == tFrame.width and oCard:GetHeight() == tFrame.height, "Rendered card dimensions differ from the atlas plan.");
                paste(oPage, oCard, tFrame); oCard:delete(); oCard = nil;
            end
            assert(oPage:SaveFile(pStage, wx.wxBITMAP_TYPE_PNG), "Could not save atlas page.");
        end, debug.traceback);
        if (oCard) then oCard:delete(); end
        if (oPage) then oPage:delete(); end
        if (pCard) then os.remove(pCard); end
        if (not bOK) then error(sError, 0); end
    end, fProgress);
end

return Atlas;