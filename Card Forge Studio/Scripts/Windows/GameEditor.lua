--[[!
@fqxn CFS.Windows.GameEditor
@desc Grouped Environment and Config source editor with source discovery and New-file selection.
!]]

-- Game source window: Environment above Config, with files in depth-first order.
local wx = require("wx");
local Common = require("Windows.Editors.Common");
local GameEditor = {};

--[[!
@fqxn CFS.Windows.GameEditor.Private.alphabetical
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
@fqxn CFS.Windows.GameEditor.Private.names
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
@fqxn CFS.Windows.GameEditor.files
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
@fqxn CFS.Windows.GameEditor.file
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
@fqxn CFS.Windows.GameEditor.create
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
    @fqxn CFS.Windows.GameEditor.Private.tOptions_newFile
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
