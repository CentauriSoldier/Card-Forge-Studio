--[[!
@fqxn CFS.Windows.StyleEditor
@desc
<section aria-label="StyleEditor overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">StyleEditor</h2><p style="font-size:1.15rem;margin:0">Style Editor shapes reusable card text through controls and a live sample.</p></div>
<h3>How it fits into your work</h3><p>Adjust inherited style drafts, inspect the native text preview, and validate settings before saving. Export can resolve inheritance into independent values or include the complete chain of referenced styles. Import validates a merged draft and asks before replacing matching names; Save commits it to the active sheet.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.FontStyle">Font Style</a></h3><p style="margin:0">FontStyle gives card text a reusable visual identity.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Forge">Forge</a></h3><p style="margin:0">Forge is the visual workbench that turns selected card data and drawing instructions into artwork.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.FS">File System</a></h3><p style="margin:0">FS is Studio's map of where project files belong.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">The preview helps evaluate text styling; grid colors and documentation themes are separate.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

-- Draft style editing. Only Save writes the active game's style file.
local wx = require("wx");
local INI = require("Plugins.INI");
local FontStyle = require("FontStyle");
local WindowState = require("Windows.WindowState");
local StyleEditor = {};
WindowState.register("StyleEditor", {savePosition = true, saveSize = true, saveVisible = false,});

local tGroups = {
    {"Font", {{"Family", "Font family", "text", "Times New Roman"}, {"Size", "Size", "number", "12", 1, 300}, {"Color", "Text color", "color", "0,0,0,255"}, {"Bold", "Bold", "boolean", "false"}, {"Italic", "Italic", "boolean", "false"}, {"Underline", "Underline", "boolean", "false"}, {"StrikeOut", "Strikeout", "boolean", "false"}, {"HQ", "High quality", "boolean", "true"}, {"LetterSpacing", "Letter spacing", "number", "0", 0, 100},}},
    {"Shadow", {{"ShadowEnabled", "Enabled", "boolean", "false"}, {"ShadowX", "Horizontal offset", "number", "0", -500, 500}, {"ShadowY", "Vertical offset", "number", "0", -500, 500}, {"ShadowRadius", "Softness radius", "number", "2", 0, 15}, {"ShadowColor", "Color", "color", "0,0,0,128"},}},
    {"Outline", {{"OutlineEnabled", "Enabled", "boolean", "false"}, {"OutlineThickness", "Thickness", "number", "1", 0, 30}, {"OutlineColor", "Color", "color", "0,0,0,255"},}},
    {"3D", {{"3DEnabled", "Enabled", "boolean", "false"}, {"3DDepth", "Depth", "number", "1", 0, 50}, {"3DStepX", "Horizontal step", "number", "1", -50, 50}, {"3DStepY", "Vertical step", "number", "1", -50, 50}, {"3DColor", "Color", "color", "0,0,0,255"},}},
    {"Glow", {{"GlowEnabled", "Enabled", "boolean", "false"}, {"GlowRadius", "Radius", "number", "8", 0, 50}, {"GlowAlphaMax", "Strength (0–255)", "number", "160", 0, 255}, {"GlowColor", "Inner color", "color", "255,255,255,255"}, {"GlowOuterColor", "Outer color", "color", "255,255,255,0"},}},
    {"Highlight", {{"BackgroundEnabled", "Enabled", "boolean", "false"}, {"BackgroundPadding", "Padding", "number", "2", 0, 100}, {"BackgroundColor", "Color", "color", "255,255,0,96"},}},
};
local tFields = {};
for _, tGroup in ipairs(tGroups) do
    for _, tField in ipairs(tGroup[2]) do tFields[tField[1]] = tField; end
end

--[[!
@fqxn CFS.Windows.StyleEditor.Private.Functions.readFile
@desc Reads a complete style file in binary mode and checks reading and closing.
@param any pFile File.
@vis private
!]]
local function readFile(pFile)
    local hFile = assert(io.open(pFile, "rb"));
    local sText = assert(hFile:read("a"));
    assert(hFile:close());
    return sText;
end

--[[!
@fqxn CFS.Windows.StyleEditor.Private.Functions.channels
@desc Parses hexadecimal or channel-list color text into color components.
@param any sValue Value.
@vis private
!]]
local function channels(sValue)
    local tColor = {};
    local sHex = sValue:match("^%s*#?(%x+)%s*$");
    if (sHex and (#sHex == 6 or #sHex == 8)) then
        for nIndex = 1, #sHex, 2 do tColor[#tColor + 1] = tonumber(sHex:sub(nIndex, nIndex + 1), 16); end
    else
        for sPart in (sValue..","):gmatch("(.-),") do
            local nChannel = tonumber(sPart);
            assert(nChannel, "Invalid color channel.");
            tColor[#tColor + 1] = nChannel;
        end
    end
    assert(#tColor == 3 or #tColor == 4, "Use RGB or RGBA color values.");
    tColor[4] = tColor[4] or 255;
    for _, nChannel in ipairs(tColor) do assert(nChannel and nChannel % 1 == 0 and nChannel >= 0 and nChannel <= 255, "Invalid color channel."); end
    return tColor;
end

--[[!
@fqxn CFS.Windows.StyleEditor.Functions.model
@pulsarlua function StyleEditor.model
@desc Loads a style INI into an editable model with inheritance resolution, validation, rename dependencies, and protected saving.
@param any pFile File path.
!]]
function StyleEditor.model(pFile)
    local tModel = {path = pFile, original = readFile(pFile), sections = {}, names = {}, dirty = false,};
    local oConfig = wx.wxFileConfig("", "", pFile, "", wx.wxCONFIG_USE_LOCAL_FILE);
    oConfig:DisableAutoSave(); oConfig:SetExpandEnvVars(false);
    local bOK, sError = xpcall(function()
        local bGroup, sName, nGroup = oConfig:GetFirstGroup();
        while (bGroup) do
            tModel.names[#tModel.names + 1] = sName;
            tModel.sections[sName] = {};
            oConfig:SetPath("/"..sName);
            local bEntry, sKey, nEntry = oConfig:GetFirstEntry();
            while (bEntry) do
                local bFound, sValue = oConfig:Read(sKey, "");
                tModel.sections[sName][sKey] = bFound and sValue or "";
                bEntry, sKey, nEntry = oConfig:GetNextEntry(nEntry);
            end
            oConfig:SetPath("/");
            bGroup, sName, nGroup = oConfig:GetNextGroup(nGroup);
        end
    end, debug.traceback);
    oConfig:delete(); assert(bOK, sError);
    table.sort(tModel.names);
    local tChanged, tRemoved = {}, {};
    --[[!
    @fqxn CFS.Windows.StyleEditor.Model.resolve
    @desc Resolves a style value through its inheritance chain.
    @param any sName Name.
    @param any sKey Key.
    @vis public
    !]]
    function tModel.resolve(sName, sKey)
        local tSeen = {};
        while (true) do
            assert(not tSeen[sName], "Inheritance cycle for "..sKey..".");
            tSeen[sName] = true;
            local tSection = tModel.sections[sName];
            if (not tSection) then return ""; end
            local sValue = tSection[sKey] or "";
            local sReference = sValue:match("^%s*<%s*(.-)%s*>%s*$");
            if (not sReference) then return sValue; end
            sName = sReference;
        end
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Model.validate
    @desc Validates the resolved value for a style field.
    @param any sName Name.
    @param any sKey Key.
    @vis public
    !]]
    function tModel.validate(sName, sKey)
        local tField = tFields[sKey];
        local sValue = tModel.resolve(sName, sKey);
        if (not tField or sValue == "") then return; end
        if (tField[3] == "color") then channels(sValue);
        elseif (tField[3] == "boolean") then assert(sValue:lower() == "true" or sValue:lower() == "false", "Use true or false for "..sKey..".");
        elseif (tField[3] == "number") then
            local nValue = tonumber(sValue);
            assert(nValue and nValue == nValue and nValue >= tField[5] and nValue <= tField[6] and nValue % 1 == 0, sKey.." must be an integer from "..tField[5].." to "..tField[6]..".");
        end
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Model.set
    @desc Changes one style field in the draft and marks the model dirty.
    @param any sName Name.
    @param any sKey Key.
    @param any sValue Value.
    @vis public
    !]]
    function tModel.set(sName, sKey, sValue)
        assert(tModel.sections[sName]);
        local sReference = sValue:match("^%s*<%s*(.-)%s*>%s*$");
        assert(not sReference or tModel.sections[sReference], "Missing inherited style: "..tostring(sReference));
        local sOld = tModel.sections[sName][sKey];
        tModel.sections[sName][sKey] = sValue;
        local bOK, sError = pcall(function()
            for _, sSection in ipairs(tModel.names) do tModel.validate(sSection, sKey); end
        end);
        if (not bOK) then tModel.sections[sName][sKey] = sOld; error(sError, 0); end
        if (sOld ~= sValue) then
            tChanged[sName] = tChanged[sName] or {};
            tChanged[sName][sKey] = sValue;
            tModel.dirty = true;
        end
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.name
    @desc Normalizes and validates a unique style name.
    @param any sName Name.
    @vis private
    !]]
    local function name(sName)
        sName = sName:match("^%s*(.-)%s*$"):upper();
        assert(sName ~= "" and not sName:find("[%c%[%]<>/\\=]"), "Enter a unique style name without brackets, separators, or control characters.");
        for sExisting in pairs(tModel.sections) do
            assert(sExisting:upper() ~= sName, "That style name already exists.");
        end
        return sName;
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.names
    @desc Rebuilds the sorted style-name list and marks the model dirty.
    @vis private
    !]]
    local function names()
        tModel.names = {};
        for sName in pairs(tModel.sections) do tModel.names[#tModel.names + 1] = sName; end
        table.sort(tModel.names);
        tModel.dirty = true;
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Model.add
    @desc Creates a style, optionally copying an existing style's settings.
    @param any sName Name.
    @param any sSource Source.
    @vis public
    !]]
    function tModel.add(sName, sSource)
        sName = name(sName);
        assert(not sSource or tModel.sections[sSource], "Source style does not exist.");
        local tValues = {};
        if (sSource) then
            for sKey, sValue in pairs(tModel.sections[sSource]) do tValues[sKey] = sValue; end
        else
            for sKey, tField in pairs(tFields) do tValues[sKey] = tField[4]; end
        end
        tModel.sections[sName] = tValues;
        tChanged[sName] = {};
        for sKey, sValue in pairs(tValues) do tChanged[sName][sKey] = sValue; end
        names();
        return sName;
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Model.dependencies
    @desc Finds styles whose inheritance depends on the requested style.
    @param any sName Name.
    @vis public
    !]]
    function tModel.dependencies(sName)
        local tDependents = {};
        for sOther, tValues in pairs(tModel.sections) do
            if (sOther ~= sName) then
                for sKey in pairs(tValues) do
                    local sCurrent, tSeen = sOther, {};
                    while (sCurrent and not tSeen[sCurrent]) do
                        if (sCurrent == sName) then tDependents[sOther] = true; break; end
                        tSeen[sCurrent] = true;
                        local tSection = tModel.sections[sCurrent];
                        sCurrent = tSection and (tSection[sKey] or ""):match("^%s*<%s*(.-)%s*>%s*$");
                    end
                end
            end
        end
        local tNames = {};
        for sOther in pairs(tDependents) do tNames[#tNames + 1] = sOther; end
        table.sort(tNames);
        return tNames;
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Model.rename
    @desc Renames a style and updates inheritance references in the draft.
    @param any sOld Old.
    @param any sNew New.
    @vis public
    !]]
    function tModel.rename(sOld, sNew)
        assert(tModel.sections[sOld], "Style does not exist.");
        sNew = name(sNew);
        tModel.sections[sNew] = tModel.sections[sOld];
        tModel.sections[sOld], tChanged[sOld], tRemoved[sOld] = nil, nil, true;
        tChanged[sNew] = {};
        for sOther, tValues in pairs(tModel.sections) do
            for sKey, sValue in pairs(tValues) do
                if (sValue:match("^%s*<%s*(.-)%s*>%s*$") == sOld) then
                    tValues[sKey] = "<"..sNew..">";
                    tChanged[sOther] = tChanged[sOther] or {};
                    tChanged[sOther][sKey] = tValues[sKey];
                end
            end
        end
        for sKey, sValue in pairs(tModel.sections[sNew]) do tChanged[sNew][sKey] = sValue; end
        names();
        return sNew;
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Model.remove
    @desc Removes a style, optionally preserving resolved settings of dependent styles.
    @param any sName Name.
    @param any bPreserve Preserve.
    @vis public
    !]]
    function tModel.remove(sName, bPreserve)
        assert(tModel.sections[sName], "Style does not exist.");
        assert(#tModel.names > 1, "Keep at least one style.");
        local tDependents = tModel.dependencies(sName);
        assert(#tDependents == 0 or bPreserve, "Remove inheritance from: "..table.concat(tDependents, ", "));
        local tResolved = {};
        for sOther, tValues in pairs(tModel.sections) do
            if (sOther ~= sName) then
                for sKey, sValue in pairs(tValues) do
                    if (sValue:match("^%s*<%s*(.-)%s*>%s*$") == sName) then
                        tResolved[#tResolved + 1] = {sOther, sKey, tModel.resolve(sOther, sKey)};
                    end
                end
            end
        end
        for _, tValue in ipairs(tResolved) do tModel.set(tValue[1], tValue[2], tValue[3]); end
        tModel.sections[sName], tChanged[sName], tRemoved[sName] = nil, nil, true;
        names();
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Model.exportText
    @desc Serializes selected styles. The flatten mode resolves references to values; include adds all referenced styles recursively. The draft is unchanged.
    @param any tSelected Selected.
    @param string sMode Optional flatten or include inheritance mode.
    @vis public
    !]]
    function tModel.exportText(tSelected, sMode)
        assert(#tSelected > 0, "Select at least one style.");
        local tIncluded, tMissing, tLines = {}, {}, {};
        for _, sName in ipairs(tSelected) do
            assert(tModel.sections[sName], "Selected style does not exist.");
            tIncluded[sName] = true;
        end
        local tExport = {};
        for _, sName in ipairs(tSelected) do tExport[#tExport + 1] = sName; end
        if (sMode == "include") then
            local nIndex = 1;
            while (nIndex <= #tExport) do
                for sKey, sValue in pairs(tModel.sections[tExport[nIndex]]) do
                    local sSource = sValue:match("^%s*<%s*(.-)%s*>%s*$");
                    if (sSource) then
                        assert(tModel.sections[sSource], "Missing inherited style: "..sSource);
                        tModel.resolve(tExport[nIndex], sKey);
                        if (not tIncluded[sSource]) then tIncluded[sSource] = true; tExport[#tExport + 1] = sSource; end
                    end
                end
                nIndex = nIndex + 1;
            end
        end
        for _, sName in ipairs(tExport) do
            tLines[#tLines + 1] = "["..sName.."]";
            local tKeys = {};
            for sKey in pairs(tModel.sections[sName]) do tKeys[#tKeys + 1] = sKey; end
            table.sort(tKeys);
            for _, sKey in ipairs(tKeys) do
                local sValue = tModel.sections[sName][sKey];
                local sSource = sValue:match("^%s*<%s*(.-)%s*>%s*$");
                if (sSource and sMode == "flatten") then
                    local sCurrent, tSeen = sName, {};
                    while (sCurrent) do
                        assert(not tSeen[sCurrent], "Inheritance cycle for "..sKey..".");
                        tSeen[sCurrent] = true;
                        local tSection = assert(tModel.sections[sCurrent], "Missing inherited style: "..sCurrent);
                        sCurrent = (tSection[sKey] or ""):match("^%s*<%s*(.-)%s*>%s*$");
                    end
                    sValue = tModel.resolve(sName, sKey);
                elseif (sSource and not tIncluded[sSource]) then tMissing[sSource] = true; end
                tLines[#tLines + 1] = sKey.."="..sValue;
            end
            tLines[#tLines + 1] = "";
        end
        local tWarnings = {};
        for sName in pairs(tMissing) do tWarnings[#tWarnings + 1] = sName; end
        table.sort(tWarnings);
        return table.concat(tLines, "\r\n"), tWarnings;
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Model.importFile
    @desc Validates a merged style sheet before adding it to the draft. Matching names require replacement permission; files remain unchanged until Save.
    @param string pImport Source INI file.
    @param boolean bReplace Allow replacing matching style names.
    @vis public
    !]]
    function tModel.importFile(pImport, bReplace)
        local tIncoming = StyleEditor.model(pImport);
        assert(#tIncoming.names > 0, "The imported sheet has no styles.");
        local tCandidate = StyleEditor.model(pFile);
        tCandidate.sections = {};
        for sName, tValues in pairs(tModel.sections) do tCandidate.sections[sName] = tValues; end
        for _, sName in ipairs(tIncoming.names) do
            assert(not sName:find("[%c%[%]<>/\\=]"), "Invalid imported style name: "..sName);
            for sExisting in pairs(tModel.sections) do
                assert(sExisting:upper() ~= sName:upper() or sExisting == sName, "Imported name differs only by case: "..sName);
            end
            assert(bReplace or not tModel.sections[sName], "Style already exists: "..sName);
            tCandidate.sections[sName] = tIncoming.sections[sName];
        end
        for sName, tValues in pairs(tCandidate.sections) do
            for sKey, sValue in pairs(tValues) do
                local sSource = sValue:match("^%s*<%s*(.-)%s*>%s*$");
                assert(not sSource or tCandidate.sections[sSource], "Missing inherited style: "..tostring(sSource));
                tCandidate.resolve(sName, sKey);
                tCandidate.validate(sName, sKey);
            end
        end
        for _, sName in ipairs(tIncoming.names) do
            if (tModel.sections[sName]) then tRemoved[sName] = true; end
            tModel.sections[sName] = tIncoming.sections[sName];
            tChanged[sName] = {};
            for sKey, sValue in pairs(tIncoming.sections[sName]) do tChanged[sName][sKey] = sValue; end
        end
        names();
        return #tIncoming.names;
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Model.parsed
    @desc Parses a draft style through an adapter without writing the source file.
    @param any sName Name.
    @vis public
    !]]
    function tModel.parsed(sName)
        return FontStyle.Parse(sName, {
            --[[!
            @fqxn CFS.Windows.StyleEditor.Private.Functions.GetValue
            @desc Resolves a draft style value through the model's inheritance lookup.
            @param any sSection Section.
            @param any sKey Key.
            @vis private
            !]]
            GetValue = function(sSection, sKey) return tModel.resolve(sSection, sKey); end,
            --[[!
            @fqxn CFS.Windows.StyleEditor.Private.Functions.GetValueNames
            @desc Returns keys from a draft style section.
            @param any sSection Section.
            @vis private
            !]]
            GetValueNames = function(sSection)
                local tKeys = {};
                for sKey in pairs(tModel.sections[sSection] or {}) do tKeys[#tKeys + 1] = sKey; end
                return tKeys;
            end,
        });
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Model.save
    @desc Saves style drafts with external-edit checking and staged replacement.
    @vis public
    !]]
    function tModel.save()
        if (not tModel.dirty) then return true; end
        assert(readFile(pFile) == tModel.original, "Styles changed outside this editor. Close and reopen it before saving.");
        for _, sName in ipairs(tModel.names) do
            for sKey in pairs(tFields) do tModel.validate(sName, sKey); end
        end
        local oStage = wx.wxFile();
        local pStage = wx.wxFileName.CreateTempFileName(pFile..".draft-", oStage);
        if (oStage:IsOpened()) then oStage:Close(); end
        oStage:delete();
        assert(pStage ~= "", "Could not create a staged styles file.");
        local pRecovery;
        local bOK, sError = xpcall(function()
            assert(wx.wxCopyFile(pFile, pStage, true), "Could not stage the styles file.");
            for sName in pairs(tRemoved) do INI.DeleteSection(pStage, sName); end
            for sName, tValues in pairs(tChanged) do
                for sKey, sValue in pairs(tValues) do INI.SetValue(pStage, sName, sKey, sValue); end
            end
            assert(readFile(pFile) == tModel.original, "Styles changed while saving. Original file preserved.");
            local oRecovery = wx.wxFile();
            pRecovery = wx.wxFileName.CreateTempFileName(pFile..".recovery-", oRecovery);
            if (oRecovery:IsOpened()) then oRecovery:Close(); end
            oRecovery:delete();
            assert(pRecovery ~= "" and wx.wxCopyFile(pFile, pRecovery, true), "Could not preserve the original styles file.");
            assert(wx.wxRenameFile(pStage, pFile, true), "Could not replace the styles file.");
        end, debug.traceback);
        if (wx.wxFileExists(pStage)) then wx.wxRemoveFile(pStage); end
        if (not bOK and pRecovery and wx.wxFileExists(pRecovery) and not wx.wxFileExists(pFile)) then
            if (not wx.wxCopyFile(pRecovery, pFile, false)) then
                error(tostring(sError).." Original styles retained at "..pRecovery, 0);
            end
        end
        if (pRecovery and wx.wxFileExists(pRecovery)) then wx.wxRemoveFile(pRecovery); end
        assert(bOK, sError);
        tModel.original, tModel.dirty, tChanged, tRemoved = readFile(pFile), false, {}, {};
        return true;
    end
    return tModel;
end

--[[!
@fqxn CFS.Windows.StyleEditor.Private.Functions.colour
@desc Converts a packed RGBA integer to a native color.
@param any nColor Color.
@vis private
!]]
local function colour(nColor)
    return wx.wxColour((nColor >> 24) & 255, (nColor >> 16) & 255, (nColor >> 8) & 255, nColor & 255);
end

--[[!
@fqxn CFS.Windows.StyleEditor.Private.Functions.drawing
@desc Adapts native graphics and device contexts to the font-style drawing interface.
@param any oGC Gc.
@param any oDC Dc.
@vis private
!]]
local function drawing(oGC, oDC)
    local oFont = wx.wxNORMAL_FONT;
    local D = {};
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.D_SetDrawingFont
    @desc Installs the font in the style-preview device and graphics contexts.
    @param any oNewFont New font.
    @vis private
    !]]
    D.SetDrawingFont = function(oNewFont) oFont = oNewFont; oDC:SetFont(oFont); oGC:SetFont(oFont, wx.wxBLACK); end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.D_SetFilteringMode
    @desc Compatibility hook; native graphics composition supplies filtering behavior.
    @vis private
    !]]
    D.SetFilteringMode = function() end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.D_GetTextWidth
    @desc Measures text width in the style-preview graphics context.
    @param any sText Text.
    @vis private
    !]]
    D.GetTextWidth = function(sText) local nW = oGC:GetTextExtent(sText); return nW; end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.D_GetTextHeight
    @desc Measures text height in the style-preview graphics context.
    @param any sText Text.
    @vis private
    !]]
    D.GetTextHeight = function(sText) local _, nH = oGC:GetTextExtent(sText); return nH; end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.D_DrawText
    @desc Draws preview text in the supplied packed color.
    @param any nX X.
    @param any nY Y.
    @param any sText Text.
    @param any nColor Color.
    @vis private
    !]]
    D.DrawText = function(nX, nY, sText, nColor) oGC:SetFont(oFont, colour(nColor)); oGC:DrawText(sText, nX, nY); end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.D_DrawAngledText
    @desc Draws preview text rotated by the supplied angle in degrees.
    @param any nX X.
    @param any nY Y.
    @param any sText Text.
    @param any nAngle Angle.
    @param any nColor Color.
    @vis private
    !]]
    D.DrawAngledText = function(nX, nY, sText, nAngle, nColor) oGC:SetFont(oFont, colour(nColor)); oGC:DrawText(sText, nX, nY, math.rad(nAngle)); end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.D_DrawRectangle
    @desc Draws a filled preview rectangle without an outline.
    @param any nX X.
    @param any nY Y.
    @param any nW W.
    @param any nH H.
    @param any nColor Color.
    @vis private
    !]]
    D.DrawRectangle = function(nX, nY, nW, nH, nColor)
        oGC:SetPen(wx.wxTRANSPARENT_PEN);
        oGC:SetBrush(wx.wxBrush(colour(nColor)));
        oGC:DrawRectangle(nX, nY, nW, nH);
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.D_DrawTextBackground
    @desc Draws a padded preview background in a temporarily transformed graphics state.
    @param any nX X.
    @param any nY Y.
    @param any nW W.
    @param any nH H.
    @param any nPadding Padding.
    @param any nColor Color.
    @param any nAngle Angle.
    @vis private
    !]]
    D.DrawTextBackground = function(nX, nY, nW, nH, nPadding, nColor, nAngle)
        oGC:PushState(); oGC:Translate(nX, nY); oGC:Rotate(-math.rad(nAngle));
        D.DrawRectangle(-nPadding, -nPadding, nW + 2 * nPadding, nH + 2 * nPadding, nColor);
        oGC:PopState();
    end
    return D;
end
StyleEditor.drawing = drawing;

--[[!
@fqxn CFS.Windows.StyleEditor.Functions.create
@pulsarlua function StyleEditor.create
@desc Creates the style editor, live preview, and style-management controls from the loaded style model.
@param any dParent Parent window.
@param any pFile File path.
@param any tOptions Options table.
!]]
function StyleEditor.create(dParent, pFile, tOptions)
    tOptions = tOptions or {};
    local tModel = StyleEditor.model(pFile);
    assert(#tModel.names > 0, "The styles file has no styles.");
    local dFrame = wx.wxFrame(dParent, wx.wxID_ANY, "Style Editor", wx.wxDefaultPosition, wx.wxSize(1000, 820));
    dFrame:SetMinSize(wx.wxSize(800, 650));
    local oState = WindowState.bind(dFrame, "StyleEditor", tOptions.stateFile);
    local dPanel = wx.wxPanel(dFrame, wx.wxID_ANY);
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oBody = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oList = wx.wxListBox(dPanel, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(180, -1), tModel.names);
    local dBook = wx.wxNotebook(dPanel, wx.wxID_ANY);
    local oMessage = wx.wxStaticText(dPanel, wx.wxID_ANY, "Draft changes affect only these samples until Save.");
    local oSample = wx.wxTextCtrl(dPanel, wx.wxID_ANY, "The quick brown fox 0123456789");
    local oSave = wx.wxButton(dPanel, wx.wxID_SAVE, "Save");
    local oClose = wx.wxButton(dPanel, wx.wxID_CLOSE, "Close");
    local tControls, tSamples = {}, {};
    local sSelected = tModel.names[1];
    local bLoading, bClosed = false, false;
    local tInvalid = {};
    local oPreview;
    local sPreviewFont = "";
    local refresh;
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.protect
    @desc Wraps a style-editor action and displays and logs failures.
    @param any fAction Action.
    @vis private
    !]]
    local function protect(fAction)
        return function(...)
            local tArguments = table.pack(...);
            local bOK, sError = xpcall(function() fAction(table.unpack(tArguments, 1, tArguments.n)); end, debug.traceback);
            if (not bOK) then oMessage:SetLabel(tostring(sError):match("^[^\n]+")); require("Errors").report(sError); dPanel:Layout(); end
        end;
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.edited
    @desc Validates a changed field and updates the draft unless controls are being loaded.
    @param any sKey Key.
    @param any sValue Value.
    @vis private
    !]]
    local function edited(sKey, sValue)
        if (bLoading) then return; end
        local bOK, sError = pcall(function()
            local tField = tFields[sKey];
            assert(sValue ~= "" or tField[3] ~= "number", "Enter a number for "..tField[2]..".");
            tModel.set(sSelected, sKey, sValue);
            if (sValue == "true" and sKey:match("Enabled$")) then
                for _, tGroup in ipairs(tGroups) do
                    if (tGroup[2][1][1] == sKey) then
                        for _, tEffectField in ipairs(tGroup[2]) do
                            if (tModel.resolve(sSelected, tEffectField[1]) == "") then
                                tModel.set(sSelected, tEffectField[1], tEffectField[4]);
                            end
                        end
                    end
                end
            end
        end);
        tInvalid[sKey] = not bOK and sError or nil;
        if (not bOK) then
            oMessage:SetLabel(tostring(sError):match("^[^\n]+"));
            oSave:Enable(false);
            dPanel:Layout();
            return;
        end
        if (next(tInvalid)) then oSave:Enable(false); return; end
        refresh();
    end
    for _, tGroup in ipairs(tGroups) do
        local dPage = wx.wxPanel(dBook, wx.wxID_ANY);
        local oGrid = wx.wxFlexGridSizer(0, 3, 8, 10);
        oGrid:AddGrowableCol(1, 1);
        for _, tField in ipairs(tGroup[2]) do
            local sKey, sKind = tField[1], tField[3];
            local oInput, oAlpha;
            local oCell = wx.wxBoxSizer(wx.wxHORIZONTAL);
            if (sKind == "boolean") then
                oInput = wx.wxCheckBox(dPage, wx.wxID_ANY, "");
                oInput:Connect(wx.wxEVT_COMMAND_CHECKBOX_CLICKED, protect(function() edited(sKey, oInput:GetValue() and "true" or "false"); end));
            elseif (sKind == "color") then
                oInput = wx.wxColourPickerCtrl(dPage, wx.wxID_ANY, wx.wxBLACK);
                oAlpha = wx.wxSpinCtrl(dPage, wx.wxID_ANY, "255", wx.wxDefaultPosition, wx.wxSize(80, -1), wx.wxSP_ARROW_KEYS, 0, 255, 255);
                --[[!
                @fqxn CFS.Windows.StyleEditor.Private.Functions.changed
                @desc Copies the selected color and alpha controls into the edited style field.
                @vis private
                !]]
                local function changed()
                    local oColor = oInput:GetColour();
                    edited(sKey, table.concat({oColor:Red(), oColor:Green(), oColor:Blue(), oAlpha:GetValue()}, ","));
                end
                oInput:Connect(wx.wxEVT_COMMAND_COLOURPICKER_CHANGED, protect(changed));
                oAlpha:Connect(wx.wxEVT_COMMAND_SPINCTRL_UPDATED, protect(changed));
            else
                oInput = wx.wxTextCtrl(dPage, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_PROCESS_ENTER);
                oInput:Connect(wx.wxEVT_COMMAND_TEXT_UPDATED, protect(function() edited(sKey, oInput:GetValue()); end));
            end
            oCell:Add(oInput, 1, wx.wxEXPAND);
            if (oAlpha) then
                oCell:Add(wx.wxStaticText(dPage, wx.wxID_ANY, "Opacity"), 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxLEFT + wx.wxRIGHT, 6);
                oCell:Add(oAlpha, 0);
            end
            local tChoices = {"Own value"};
            for _, sName in ipairs(tModel.names) do tChoices[#tChoices + 1] = sName; end
            local oLink = wx.wxChoice(dPage, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(170, -1), tChoices);
            oLink:SetToolTip("Inherit this property from another style, or use an own value.");
            oLink:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, protect(function()
                local sSource = oLink:GetStringSelection();
                edited(sKey, sSource == "Own value" and (tModel.resolve(sSelected, sKey) ~= "" and tModel.resolve(sSelected, sKey) or tField[4]) or "<"..sSource..">");
            end));
            oGrid:Add(wx.wxStaticText(dPage, wx.wxID_ANY, tField[2]), 0, wx.wxALIGN_CENTER_VERTICAL);
            oGrid:Add(oCell, 1, wx.wxEXPAND);
            oGrid:Add(oLink, 0, wx.wxEXPAND);
            tControls[sKey] = {input = oInput, alpha = oAlpha, link = oLink, field = tField,};
        end
        local oPageLayout = wx.wxBoxSizer(wx.wxVERTICAL);
        oPageLayout:Add(oGrid, 1, wx.wxEXPAND + wx.wxALL, 12);
        dPage:SetSizer(oPageLayout);
        dBook:AddPage(dPage, tGroup[1]);
    end
    local oStyles = wx.wxBoxSizer(wx.wxVERTICAL);
    oStyles:Add(oList, 1, wx.wxEXPAND);
    local tStyleButtons = {};
    for _, sAction in ipairs({"New", "Duplicate", "Rename", "Delete", "Import", "Export"}) do
        local oButton = wx.wxButton(dPanel, wx.wxID_ANY, sAction);
        tStyleButtons[sAction] = oButton;
        oStyles:Add(oButton, 0, wx.wxEXPAND + wx.wxTOP, 4);
    end
    oBody:Add(oStyles, 0, wx.wxEXPAND + wx.wxRIGHT, 10);
    oBody:Add(dBook, 1, wx.wxEXPAND);
    oLayout:Add(oBody, 1, wx.wxEXPAND + wx.wxALL, 12);
    oLayout:Add(oSample, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 12);
    local oSamples = wx.wxBoxSizer(wx.wxHORIZONTAL);
    for _, nBackground in ipairs({0, 255}) do
        local dCanvas = wx.wxPanel(dPanel, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(-1, 160));
        dCanvas:SetBackgroundStyle(wx.wxBG_STYLE_PAINT);
        dCanvas:Connect(wx.wxEVT_PAINT, protect(function()
            local oDC = wx.wxPaintDC(dCanvas);
            oDC:SetBackground(wx.wxBrush(wx.wxColour(nBackground, nBackground, nBackground)));
            oDC:Clear();
            local oGC = wx.wxGraphicsContext.Create(oDC);
            local bOK, sError = xpcall(function()
                if (oPreview) then
                    local D = drawing(oGC, oDC);
                    local nW, nH, nX, nY = oPreview.Prep(D, oSample:GetValue());
                    local oSize = dCanvas:GetClientSize();
                    local nScale = math.min(1, (oSize:GetWidth() - 20) / math.max(1, nW), (oSize:GetHeight() - 20) / math.max(1, nH));
                    oGC:Scale(nScale, nScale);
                    oPreview.Draw("Style preview", D, oDC, 10 / nScale - nX, 10 / nScale - nY, oSample:GetValue());
                end
            end, debug.traceback);
            oGC:delete(); oDC:delete();
            assert(bOK, sError);
        end));
        dCanvas:Connect(wx.wxEVT_SIZE, function(oEvent) dCanvas:Refresh(false); oEvent:Skip(); end);
        oSamples:Add(dCanvas, 1, wx.wxEXPAND + wx.wxALL, 4);
        tSamples[#tSamples + 1] = dCanvas;
    end
    oLayout:Add(oSamples, 0, wx.wxEXPAND + wx.wxALL, 8);
    oLayout:Add(oMessage, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 12);
    local oButtons = wx.wxBoxSizer(wx.wxHORIZONTAL);
    oButtons:AddStretchSpacer(); oButtons:Add(oSave, 0, wx.wxALL, 6); oButtons:Add(oClose, 0, wx.wxALL, 6);
    oLayout:Add(oButtons, 0, wx.wxEXPAND + wx.wxALL, 6);
    dPanel:SetSizer(oLayout);
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.refresh
    @desc Refreshes style controls, validation state, and the live preview.
    @param any sEditedKey Edited key.
    @vis private
    !]]
    refresh = function(sEditedKey)
        bLoading = true;
        for sKey, tControl in pairs(tControls) do
            local sRaw = tModel.sections[sSelected][sKey] or "";
            local sValue = tModel.resolve(sSelected, sKey);
            if (sValue == "") then sValue = tControl.field[4]; end
            local sSource = sRaw:match("^%s*<%s*(.-)%s*>%s*$");
            tControl.link:SetStringSelection(sSource or "Own value");
            local tChain, tSeen = {}, {};
            local sChainName = sSelected;
            while (sChainName and not tSeen[sChainName]) do
                tChain[#tChain + 1] = sChainName;
                tSeen[sChainName] = true;
                local tSection = tModel.sections[sChainName];
                local sChainValue = tSection and tSection[sKey] or "";
                sChainName = sChainValue:match("^%s*<%s*(.-)%s*>%s*$");
            end
            tControl.link:SetToolTip(table.concat(tChain, " -> ").."\n"..tControl.field[2]..": "..sValue);
            tControl.input:Enable(not sSource);
            if (tControl.alpha) then tControl.alpha:Enable(not sSource); end
            local sKind = tControl.field[3];
            if (sKind == "boolean") then tControl.input:SetValue(sValue:lower() == "true");
            elseif (sKind == "color") then
                local tColor = channels(sValue);
                tControl.input:SetColour(wx.wxColour(tColor[1], tColor[2], tColor[3]));
                tControl.alpha:SetValue(tColor[4]);
            elseif (sKey ~= sEditedKey) then tControl.input:ChangeValue(sValue); end
        end
        bLoading = false;
        local tParsed = assert(tModel.parsed(sSelected), "Could not parse selected style.");
        local sFont = tParsed.FontFamily..":"..tParsed.FontSize..":"..tostring(tParsed.FontOptions.Bold)..":"..tostring(tParsed.FontOptions.Italic)..":"..tostring(tParsed.FontOptions.Underline)..":"..tostring(tParsed.FontOptions.StrikeOut);
        if (oPreview) then oPreview.ApplyParsed(tParsed, sFont ~= sPreviewFont); else oPreview = FontStyle("STYLE_EDITOR_PREVIEW", tParsed); end
        sPreviewFont = sFont;
        oSave:Enable(tModel.dirty);
        dFrame:SetTitle("Style Editor - "..sSelected..(tModel.dirty and " *" or ""));
        oMessage:SetLabel("Draft changes affect only these samples until Save.");
        for _, dCanvas in ipairs(tSamples) do dCanvas:Refresh(false); end
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.refreshNames
    @desc Repopulates the style list and updates control enablement for the selected style.
    @vis private
    !]]
    local function refreshNames()
        oList:Clear();
        for _, sName in ipairs(tModel.names) do oList:Append(sName); end
        oList:SetStringSelection(sSelected);
        for _, tControl in pairs(tControls) do
            tControl.link:Clear(); tControl.link:Append("Own value");
            for _, sName in ipairs(tModel.names) do tControl.link:Append(sName); end
        end
        refresh();
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.requestName
    @desc Prompts for a style name and returns nil when cancelled.
    @param any sTitle Title.
    @param any sDefault Default.
    @vis private
    !]]
    local function requestName(sTitle, sDefault)
        local dName = wx.wxTextEntryDialog(dFrame, "Style name", sTitle, sDefault);
        dName:CentreOnParent();
        local bOK = dName:ShowModal() == wx.wxID_OK;
        local sName = dName:GetValue();
        dName:Destroy();
        if (bOK) then return sName; end
    end
    for sAction, oButton in pairs(tStyleButtons) do
        oButton:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, protect(function()
            assert(not next(tInvalid), "Correct the invalid fields first.");
            if (sAction == "Export") then
                local dSelect = wx.wxMultiChoiceDialog(dFrame, "Select styles to export from the current draft.", "Export styles", tModel.names);
                dSelect:CentreOnParent();
                local bSelected = dSelect:ShowModal() == wx.wxID_OK;
                local tIndices = dSelect:GetSelections();
                dSelect:Destroy();
                if (not bSelected or tIndices:GetCount() == 0) then return; end
                local tSelected = {};
                for nIndex = 0, tIndices:GetCount() - 1 do tSelected[#tSelected + 1] = tModel.names[tIndices:Item(nIndex) + 1]; end
                local sText, tMissing = tModel.exportText(tSelected);
                local bInheritance = #tMissing > 0;
                for _, sName in ipairs(tSelected) do
                    for _, sValue in pairs(tModel.sections[sName]) do
                        if (sValue:match("^%s*<%s*(.-)%s*>%s*$")) then bInheritance = true; end
                    end
                end
                if (bInheritance) then
                    local dMode = wx.wxSingleChoiceDialog(dFrame, "Choose how to export inherited styles. Cancel stops the export.", "Style inheritance", {"Without inheritance (keep resolved values)", "Include all inherited styles"});
                    dMode:CentreOnParent();
                    local bAccepted = dMode:ShowModal() == wx.wxID_OK;
                    local nMode = dMode:GetSelection(); dMode:Destroy();
                    if (not bAccepted) then return; end
                    sText = tModel.exportText(tSelected, nMode == 0 and "flatten" or "include");
                end
                local dFile = wx.wxFileDialog(dFrame, "Export styles", "", "Styles.ini", "Style sheets (*.ini)|*.ini", wx.wxFD_SAVE + wx.wxFD_OVERWRITE_PROMPT);
                local bSave = dFile:ShowModal() == wx.wxID_OK;
                local pExport = dFile:GetPath();
                dFile:Destroy();
                if (not bSave) then return; end
                assert(wx.wxFileName(pExport):GetFullPath():lower() ~= wx.wxFileName(pFile):GetFullPath():lower(), "Export to a separate file, not the active style sheet.");
                local oStage = wx.wxFile();
                local pStage = wx.wxFileName.CreateTempFileName(pExport..".export-", oStage);
                if (oStage:IsOpened()) then oStage:Close(); end
                oStage:delete();
                assert(pStage ~= "", "Could not stage the exported sheet.");
                local bOK, sError = pcall(function()
                    local hFile = assert(io.open(pStage, "wb"));
                    local bWritten, sWriteError = hFile:write(sText);
                    local bClosed, sCloseError = hFile:close();
                    assert(bWritten, sWriteError); assert(bClosed, sCloseError);
                    assert(wx.wxRenameFile(pStage, pExport, true), "Could not save the exported sheet.");
                end);
                if (wx.wxFileExists(pStage)) then wx.wxRemoveFile(pStage); end
                assert(bOK, sError);
                oMessage:SetLabel("Selected styles exported. The draft remains unchanged.");
                return;
            elseif (sAction == "Import") then
                local dFile = wx.wxFileDialog(dFrame, "Import styles", "", "", "Style sheets (*.ini)|*.ini", wx.wxFD_OPEN + wx.wxFD_FILE_MUST_EXIST);
                local bImport = dFile:ShowModal() == wx.wxID_OK;
                local pImport = dFile:GetPath(); dFile:Destroy();
                if (not bImport) then return; end
                local tIncoming = StyleEditor.model(pImport);
                local tMatching = {};
                for _, sName in ipairs(tIncoming.names) do if (tModel.sections[sName]) then tMatching[#tMatching + 1] = sName; end end
                if (#tMatching > 0) then
                    local nAnswer = wx.wxMessageBox("Replace these styles in the draft? "..table.concat(tMatching, ", ")..".\n\nThe active file changes only when you Save.", "Matching styles", wx.wxYES_NO + wx.wxNO_DEFAULT + wx.wxICON_QUESTION, dFrame);
                    if (nAnswer ~= wx.wxYES) then return; end
                end
                local nImported = tModel.importFile(pImport, #tMatching > 0);
                sSelected = tIncoming.names[1]; refreshNames();
                oMessage:SetLabel(tostring(nImported).." styles imported into the draft. Save to keep them.");
            elseif (sAction == "Delete") then
                local tDependents = tModel.dependencies(sSelected);
                local sQuestion = "Delete "..sSelected.." from the draft? Game scripts using this name will need updating.";
                if (#tDependents > 0) then
                    sQuestion = "Inherited by: "..table.concat(tDependents, ", ")..".\n\nPreserve their resolved values and delete "..sSelected.."? Existing indirect links remain intact; direct links become own values. Game scripts using this name will need updating.";
                end
                local nAnswer = wx.wxMessageBox(sQuestion, #tDependents > 0 and "Preserve values and delete" or "Delete style", wx.wxYES_NO + wx.wxNO_DEFAULT + wx.wxICON_QUESTION, dFrame);
                if (nAnswer ~= wx.wxYES) then return; end
                tModel.remove(sSelected, #tDependents > 0);
                sSelected = tModel.names[1];
            else
                local sDefault = sAction == "New" and "NEW_STYLE" or sSelected;
                if (sAction == "Duplicate") then
                    sDefault = sSelected.."_COPY";
                    local nCopy = 2;
                    while (tModel.sections[sDefault]) do sDefault = sSelected.."_COPY_"..nCopy; nCopy = nCopy + 1; end
                end
                local sName = requestName(sAction.." style", sDefault);
                if (not sName) then return; end
                if (sAction == "Rename") then sSelected = tModel.rename(sSelected, sName);
                else sSelected = tModel.add(sName, sAction == "Duplicate" and sSelected or nil); end
            end
            refreshNames();
        end));
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.save
    @desc Rejects invalid fields, saves the style draft, and refreshes the preview and status.
    @vis private
    !]]
    local function save()
        assert(not next(tInvalid), "Correct the invalid fields before saving.");
        tModel.save();
        refresh();
        oMessage:SetLabel("Styles saved. Live cards will update through the file watcher.");
    end
    --[[!
    @fqxn CFS.Windows.StyleEditor.Private.Functions.allowClose
    @desc Asks whether style drafts should be saved, discarded, or kept open.
    @vis private
    !]]
    local function allowClose()
        if (not tModel.dirty and not next(tInvalid)) then return true; end
        local nAnswer = tOptions.confirm and tOptions.confirm() or wx.wxMessageBox("Save your style changes? No discards the draft.", "Style Editor", wx.wxYES_NO + wx.wxCANCEL + wx.wxICON_QUESTION, dFrame);
        if (nAnswer == wx.wxYES) then save(); return true; end
        return nAnswer == wx.wxNO;
    end
    oList:SetSelection(0);
    oList:Connect(wx.wxEVT_COMMAND_LISTBOX_SELECTED, protect(function() assert(not next(tInvalid), "Correct the invalid field before selecting another style."); sSelected = oList:GetStringSelection(); refresh(); end));
    oSample:Connect(wx.wxEVT_COMMAND_TEXT_UPDATED, protect(function() for _, dCanvas in ipairs(tSamples) do dCanvas:Refresh(false); end end));
    oSave:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, protect(save));
    oClose:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function() dFrame:Close(); end);
    dFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        local bOK, bContinue = pcall(allowClose);
        if (not bOK or not bContinue) then
            if (oEvent:CanVeto()) then oEvent:Veto(); end
            if (not bOK) then oMessage:SetLabel(tostring(bContinue):match("^[^\n]+")); require("Errors").report(bContinue); end
            return;
        end
        bClosed = true;
        oState.close();
        if (tOptions.onClose) then tOptions.onClose(); end
        oEvent:Skip();
    end);
    refresh();
    dFrame:Show(true); dPanel:Layout();
    return {frame = dFrame, model = tModel, controls = tControls, samples = tSamples, save = save, refresh = refresh,
        --[[!
        @fqxn CFS.Windows.StyleEditor.Private.Functions.close
        @desc Closes the style editor through its draft-protection handling.
        @vis private
        !]]
        close = function() if (bClosed) then return true; end return dFrame:Close(); end,
        --[[!
        @fqxn CFS.Windows.StyleEditor.Private.Functions.show
        @desc Shows and raises the style editor.
        @vis private
        !]]
        show = function() dFrame:Show(true); dFrame:Raise(); end,};
end

return StyleEditor;