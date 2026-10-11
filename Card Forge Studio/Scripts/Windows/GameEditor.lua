--[[!
@fqxn CFS.Windows.GameEditor
@desc
<section aria-label="GameEditor overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">GameEditor</h2><p style="font-size:1.15rem;margin:0">Game Editor organizes the shared scripts used throughout a game.</p></div>
<h3>How it fits into your work</h3><p>Work in Environment and Config groups, select or create source files, and save validated drafts.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.Game">Game</a></h3><p style="margin:0">A game is the home for a whole project: its name, shared settings, and collection of card sets.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.UserEnv">User Environment</a></h3><p style="margin:0">UserEnv is the shared workspace where game scripts find configuration, helper values, and the APIs Studio exposes.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Editors.Common">Editors.Common</a></h3><p style="margin:0">The shared editor helper supplies consistent drafts and save protections.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.EditorSettings">EditorSettings</a></h3><p style="margin:0">Shared settings keep the code editors consistent across projects.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Shared game source is separate from individual card-set drawing and processing scripts.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

-- Game source window: Environment above Config, with files in depth-first order.
local wx = require("wx");
local Common = require("Windows.Editors.Common");
local GameEditor = {};

--[[!
@fqxn CFS.Windows.GameEditor.Private.Functions.alphabetical
@desc Compares source names case-insensitively, with a case-sensitive tie breaker.
@vis private
@param any sLeft Left.
@param any sRight Right.
!]]
local function alphabetical(sLeft, sRight)
    if (sLeft:lower() == sRight:lower()) then return sLeft < sRight; end
    return sLeft:lower() < sRight:lower();
end

--[[!
@fqxn CFS.Windows.GameEditor.Private.Functions.names
@desc Lists and sorts visible and hidden entries matching the requested directory flags.
@vis private
@param any pFolder Folder.
@param any nFlags Flags.
!]]
local function names(pFolder, nFlags)
    local oFolder = wx.wxDir(pFolder);
    assert(oFolder:IsOpened(), "Could not read source folder: "..pFolder);
    local tNames = {};
    local bFound, sName = oFolder:GetFirst("", nFlags + wx.wxDIR_HIDDEN);
    while (bFound) do
        tNames[#tNames + 1] = sName;
        bFound, sName = oFolder:GetNext();
    end
    oFolder:delete(); table.sort(tNames, alphabetical);
    return tNames;
end

--[[!
@fqxn CFS.Windows.GameEditor.Functions.files
@pulsarlua function GameEditor.files
@desc Lists ENV/CFG root scripts and recursively discovers Lua, INI, and text files in their groups.
@param any pScripts Scripts.
@param any pEnvironment Environment.
@param any pConfig Config.
!]]
function GameEditor.files(pScripts, pEnvironment, pConfig)
    local tFiles = {};
    for nGroup, tRoot in ipairs({{name = "ENV", path = pEnvironment}, {name = "CFG", path = pConfig}}) do
        tFiles[#tFiles + 1] = {name = tRoot.name..".lua", path = pScripts.."/"..tRoot.name..".lua", kind = "lua", group = nGroup};
        local tPending = {{path = tRoot.path, relative = ""}};
        while (#tPending > 0) do
            local tFolder = table.remove(tPending);
            for _, sName in ipairs(names(tFolder.path, wx.wxDIR_FILES)) do
                local sExtension = sName:match("%.([^%.]+)$"); sExtension = sExtension and sExtension:lower();
                if (sExtension == "lua" or sExtension == "ini" or sExtension == "txt") then
                    tFiles[#tFiles + 1] = {name = tFolder.relative..sName, path = tFolder.path.."/"..sName, kind = sExtension == "txt" and "text" or sExtension, group = nGroup};
                end
            end
            local tFolders = names(tFolder.path, wx.wxDIR_DIRS);
            for nIndex = #tFolders, 1, -1 do
                local sName = tFolders[nIndex];
                tPending[#tPending + 1] = {path = tFolder.path.."/"..sName, relative = tFolder.relative..sName.."/"};
            end
        end
    end
    return tFiles;
end

--[[!
@fqxn CFS.Windows.GameEditor.Functions.file
@pulsarlua function GameEditor.file
@desc Validates a supported source filename inside its root and returns a grouped editor-file record.
@param any pRoot Root folder.
@param any pFile File path.
@param any nGroup Group.
!]]
function GameEditor.file(pRoot, pFile, nGroup)
    local oRoot = wx.wxFileName.DirName(pRoot); oRoot:Normalize();
    local oFile = wx.wxFileName(pFile); oFile:Normalize();
    local pNormalizedRoot = oRoot:GetFullPath():gsub("\\", "/"):gsub("/+$", "").."/";
    local pNormalizedFile = oFile:GetFullPath():gsub("\\", "/");
    oRoot:delete(); oFile:delete();
    assert(pNormalizedFile:sub(1, #pNormalizedRoot):lower() == pNormalizedRoot:lower(), "Choose a file inside this source folder.");
    local sExtension = pNormalizedFile:match("%.([^%.]+)$"); sExtension = sExtension and sExtension:lower();
    assert(sExtension == "lua" or sExtension == "ini" or sExtension == "txt", "Choose a Lua, INI, or TXT filename.");
    return {name = pNormalizedFile:sub(#pNormalizedRoot + 1), path = pNormalizedFile, kind = sExtension == "txt" and "text" or sExtension, group = nGroup};
end
--[[!
@fqxn CFS.Windows.GameEditor.Functions.create
@pulsarlua function GameEditor.create
@desc Creates the game source editor with separate Environment and Config groups, New-file selection, and window state.
@param any dParent Parent window.
@param any pScripts Scripts.
@param any pEnvironment Environment.
@param any pConfig Config.
@param any tOptions Options table.
!]]
function GameEditor.create(dParent, pScripts, pEnvironment, pConfig, tOptions)
    tOptions = tOptions or {};
    tOptions.groups = {"Environment", "Config"};
    --[[!
    @fqxn CFS.Windows.GameEditor.Private.Functions.tOptions_newFile
    @desc Prompts for a filename in the selected ENV/CFG root and validates its location and extension.
    @vis private
    @param any dFrame Frame.
    @param any nGroup Group.
    !]]
    tOptions.newFile = function(dFrame, nGroup)
        local pRoot = nGroup == 1 and pEnvironment or pConfig;
        local oDialog = wx.wxFileDialog(dFrame, "New source file", pRoot, "", "Lua files (*.lua)|*.lua|INI files (*.ini)|*.ini|Text files (*.txt)|*.txt", wx.wxFD_SAVE);
        local nResult = oDialog:ShowModal(); local pFile = oDialog:GetPath(); oDialog:Destroy();
        if (nResult ~= wx.wxID_OK) then return nil; end
        return GameEditor.file(pRoot, pFile, nGroup);
    end
    tOptions.windowState = "GameEditor";
    tOptions.savedMessage = "Game source saved.";
    return Common.create(dParent, GameEditor.files(pScripts, pEnvironment, pConfig), "Game Source Editor", tOptions);
end
return GameEditor;
