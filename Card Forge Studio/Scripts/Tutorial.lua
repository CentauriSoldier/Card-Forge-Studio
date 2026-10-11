-- Basic topic order uses filenames; reorder this list without renaming topic files.
local tTopicOrder = {
    "CreateGame.lua",
    "CreateCardSet.lua",
    "ExportCards.lua",
};

-- Advanced topics use the same filename format and independent order.
local tAdvancedTopicOrder = {
    "ScriptEnvironment.lua",
    "CardData.lua",
    "RowProcessor.lua",
    "CodeColumns.lua",
    "TextStyles.lua",
    "DrawingCards.lua",
    "ImagesAndPaths.lua",
    "CardFaces.lua",
    "ReusableCode.lua",
    "Debugging.lua",
    "ExportFormats.lua",
    "SharingProjects.lua",
};

local wx       = require("wx");
local Tutorial = {};

--[[!
@fqxn CFS.Modules.Tutorial
@pulsarlua table Tutorial
@desc Loads the native reader's tutorials from Scripts/Tutorial. Basic and Advanced topic order tables are declared at the top of this file; each topic owns its step order and keyed step definitions. Images belong in Images/Tutorial and fall back to Images/Missing.png when absent. Topic and step IDs stay stable when their presentation order changes.
!]]

--[[!
@fqxn CFS.Modules.Tutorial.Private.Functions.escapeHTML
@desc Escapes captions and image URLs before rendering tutorial figures.
@param string sText Caption or URL.
@return string sHTML Escaped text.
@vis private
!]]
local function escapeHTML(sText)
    return sText:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;");
end

--[[!
@fqxn CFS.Modules.Tutorial.Functions.Load
@pulsarlua function Tutorial.Load
@desc Returns fresh ordered topics and steps for the native reader. Missing figures use the shared missing-image asset; images are bounded to the instruction panel. This function reads tutorial definitions only and does not load or alter any game.
@return table tTopics Ordered topic records with ordered steps.
!]]
function Tutorial.Load()
    local tTopics, tSeen = {}, {};
    for _, tCategory in ipairs({{name = "Basic", order = tTopicOrder}, {name = "Advanced", order = tAdvancedTopicOrder}}) do
        for _, sFile in ipairs(tCategory.order) do
            assert(sFile:match("^[%w_%-]+%.lua$"), "Invalid tutorial topic filename.");
            assert(not tSeen[sFile], "Duplicate tutorial topic: "..sFile); tSeen[sFile] = true;
            local tSource = require("Tutorial."..sFile:sub(1, -5));
            local tTopic = {title = tSource.title, category = tCategory.name, steps = {}};
            local tUsed = {};
            for _, nID in ipairs(tSource.stepOrder) do
                assert(not tUsed[nID], "Duplicate tutorial step ID."); tUsed[nID] = true;
                local tSourceStep = assert(tSource.steps[nID], "Missing tutorial step: "..tostring(nID));
                local sHTML = tSourceStep.html;
                for _, tFigure in ipairs(tSourceStep.images or {}) do
                    assert(tFigure.file:match("^[%w_%-]+%.png$"), "Invalid tutorial image filename.");
                    local pImage = APP_PATH.."/Images/Tutorial/"..tFigure.file;
                    if (not wx.wxFileExists(pImage)) then pImage = APP_PATH.."/Images/Missing.png"; end
                    local oImage = wx.wxImage(pImage, wx.wxBITMAP_TYPE_PNG);
                    assert(oImage:IsOk(), "Cannot read tutorial image: "..pImage);
                    local nWidth, nHeight = oImage:GetWidth(), oImage:GetHeight(); oImage:delete();
                    local nScale = math.min(1, 560 / nWidth, 320 / nHeight);
                    local oFile = wx.wxFileName(pImage); local sURL = wx.wxFileSystem.FileNameToURL(oFile); oFile:delete();
                    sHTML = sHTML..'<p><img src="'..escapeHTML(sURL)..'" width="'..math.floor(nWidth * nScale)..'" height="'..math.floor(nHeight * nScale)..'"><br><font color="#667085">'..escapeHTML(tFigure.caption)..'</font></p>';
                end
                tTopic.steps[#tTopic.steps + 1] = {id = nID, title = tSourceStep.title, html = sHTML};
            end
            tTopics[#tTopics + 1] = tTopic;
        end
    end
    return tTopics;
end

return Tutorial;
