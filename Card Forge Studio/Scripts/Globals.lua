--[[!
@fqxn CFS.Modules.Globals
@desc Initializes application services, protected globals, development documentation builds, and status callbacks.
!]]

assert(APP_PATH, "The launcher must initialize APP_PATH before Globals.");

local tBootstrapMeta = assert(getmetatable(_G));
local fBootstrapRead = tBootstrapMeta.__index;
local fBootstrapWrite = tBootstrapMeta.__newindex;
local type = type;

require("Plugins.LuaEx.init");

-- Preserve the launcher's path guard alongside LuaEx's protected globals.
local tGlobalMeta = getmetatable(_G);
local vGlobalRead = tGlobalMeta.__index;
local fGlobalWrite = tGlobalMeta.__newindex;

--[[!
@fqxn CFS.Modules.Globals.Private.tGlobalMeta___index
@desc Reads launcher-protected globals before delegating to the LuaEx global reader.
@param any tGlobal Global.
@param any sKey Key.
@vis private
!]]
tGlobalMeta.__index = function(tGlobal, sKey)
    local vBootstrapValue = fBootstrapRead(tGlobal, sKey);

    if (vBootstrapValue ~= nil) then
        return vBootstrapValue;
    end

    if (type(vGlobalRead) == "function") then
        return vGlobalRead(tGlobal, sKey);
    elseif (type(vGlobalRead) == "table") then
        return vGlobalRead[sKey];
    end
end

--[[!
@fqxn CFS.Modules.Globals.Private.tGlobalMeta___newindex
@desc Preserves the launcher write guard for protected globals and delegates other writes to LuaEx.
@param any tGlobal Global.
@param any sKey Key.
@param any vValue Value.
@vis private
!]]
tGlobalMeta.__newindex = function(tGlobal, sKey, vValue)
    if (fBootstrapRead(tGlobal, sKey) ~= nil) then
        return fBootstrapWrite(tGlobal, sKey, vValue);
    end

    return fGlobalWrite(tGlobal, sKey, vValue);
end

require("Constants");

if (DEV_MODE and BUILD_DOX) then
    local Dox      = Dox;
    local DoxLua   = DoxLua;
    local base64   = base64;
    local error    = error;
    local ipairs   = ipairs;
    local os       = os;
    local string   = string;
    local table    = table;
    local tostring = tostring;
    local utf8     = utf8;
    local wx       = require("wx");

    --[[!
    @fqxn CFS.Modules.Globals.Private.CollectLuaFiles
    @desc Collects Studio Lua sources recursively, excluding the linked Plugins tree. Paths are sorted before import for reproducible builds.
    @param string pFolder Source folder to inspect.
    @param table tFiles Collected source paths.
    !]]
    local function CollectLuaFiles(pFolder, tFiles)
        local oFolder = wx.wxDir(pFolder);

        if (not oFolder:IsOpened()) then
            oFolder:delete();
            error("Cannot inspect documentation source folder: "..pFolder, 2);
        end

        local bFound, sName = oFolder:GetFirst("", wx.wxDIR_FILES + wx.wxDIR_DIRS);

        while (bFound) do
            local pEntry = pFolder.."/"..sName;

            if (wx.wxDirExists(pEntry)) then
                if (sName:lower() ~= "plugins") then
                    CollectLuaFiles(pEntry, tFiles);
                end
            elseif (sName:lower():match("%.lua$")) then
                table.insert(tFiles, pEntry);
            end

            bFound, sName = oFolder:GetNext();
        end

        oFolder:delete();
    end


    --[[!
    @fqxn CFS.Modules.Globals.Private.InstallPulsarPackage
    @desc Extracts the generated package into Pulsar's packages directory. The ZIP is retained after installation failure and removed only after successful extraction.
    @param string pZIP Generated package archive.
    @param string pPackages Pulsar package directory.
    !]]
    local function InstallPulsarPackage(pZIP, pPackages)
        -- PowerShell literal strings and an encoded command preserve path characters.
        local sArchive     = "'"..pZIP:gsub("'", "''").."'";
        local sDestination = "'"..pPackages:gsub("'", "''").."'";
        local sScript      = "$ProgressPreference = 'SilentlyContinue'; $ErrorActionPreference = 'Stop'; Add-Type -AssemblyName System.IO.Compression.FileSystem; "..
                        "$root = [System.IO.Path]::GetFullPath("..sDestination.."); "..
                        "[System.IO.Directory]::CreateDirectory($root) | Out-Null; "..
                        "$root = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar; "..
                        "$zip = [System.IO.Compression.ZipFile]::OpenRead("..sArchive.."); "..
                        "try { foreach ($entry in $zip.Entries) { "..
                        "$target = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($root, $entry.FullName)); "..
                        "if (-not $target.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'ZIP path outside package directory'; }; "..
                        "if ($entry.FullName.EndsWith('/')) { [System.IO.Directory]::CreateDirectory($target) | Out-Null; } "..
                        "else { [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target)) | Out-Null; "..
                        "[System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true); }; "..
                        "}; } finally { $zip.Dispose(); };";
        local tEncoded     = {};

        for _, nCodePoint in utf8.codes(sScript) do
            if (nCodePoint <= 0xFFFF) then
                table.insert(tEncoded, string.pack("<I2", nCodePoint));
            else
                nCodePoint = nCodePoint - 0x10000;
                table.insert(tEncoded, string.pack("<I2I2", 0xD800 + (nCodePoint >> 10), 0xDC00 + (nCodePoint & 0x3FF)));
            end
        end

        local sCommand = "powershell.exe -WindowStyle Hidden -NoProfile -NonInteractive -EncodedCommand "..base64.enc(table.concat(tEncoded));
        local bOK      = os.execute(sCommand);

        if (not bOK) then
            error("Pulsar package installation failed; ZIP retained at "..pZIP, 2);
        end

        local bRemoved, sError = os.remove(pZIP);

        if (not bRemoved) then
            error("Pulsar package installed, but its ZIP could not be removed: "..tostring(sError), 2);
        end
    end


    local pDocs     = APP_PATH.."/Docs";
    local pProfile  = os.getenv("USERPROFILE");
    local tFiles    = {};

    if (not pProfile or pProfile == "") then
        error("Cannot find the Windows profile for Pulsar package installation.", 2);
    end

    if (not wx.wxDirExists(pDocs) and not wx.wxFileName.Mkdir(pDocs, 511, wx.wxPATH_MKDIR_FULL)) then
        error("Cannot create documentation output folder: "..pDocs, 2);
    end

    CollectLuaFiles(_Scripts, tFiles);
    table.sort(tFiles);

    local oDox = DoxLua("CFS");

    for _, pFile in ipairs(tFiles) do
        oDox.importFile(pFile, true);
    end

    oDox.refresh();
    oDox.setOutputPath(pDocs);
    oDox.export("index");
    oDox.setBuilder(Dox.BUILDER.PULSAR_LUA);

    local pZIP = oDox.export("CFS");

    InstallPulsarPackage(pZIP, pProfile.."/.pulsar/packages");
end

local wx = require("wx");
assert(wx.wxFont.AddPrivateFont(_Fonts.."/CRYSTAL-Regular.ttf"), "Cannot load the bundled CRYSTAL font.");

CFG     = {};
FTCSV   = require("Plugins.FTCSV.ftcsv");
dLog    = require("Windows.Log");
Log     = require("Log");
INIFile = require("Plugins.INI");
FS      = require("Globals.FS");
ProcSys = require("ProcSys");
Game    = require("Game");

_bLoaded = false;

-- These services retain their original dependencies until their individual ports are complete.
--[[!
@fqxn CFS.Modules.Globals.LoadGameModules
@pulsarlua function LoadGameModules
@desc Loads retained game services and publishes their global entry points; several legacy services still require porting before use.
@vis public
!]]
function LoadGameModules()
    local tImportSystem = require("Globals.ImportSystem");

    Import          = tImportSystem.Import;
    SanitizePath    = tImportSystem.SanitizePath;
    ProcessDox      = require("Globals.ProcessDox");
    FontStyle       = require("FontStyle");
    ProcSys         = require("ProcSys");
    Forge           = require("Forge");
    StyleEditor     = require("StyleEditor");
    Game            = require("Game");
    Tutorial        = require("Tutorial");
    UserEnv         = require("Globals.UserEnv");
end

Status = {};

local dStatusFrame;
local sStatusText = "";

--[[!
@fqxn CFS.Modules.Globals.Status.Set
@pulsarlua function Status.Set
@desc Sets status text and updates the main native frame when it is attached.
@param any vStatus Status.
@vis public
!]]
function Status.Set(vStatus)
    sStatusText = vStatus and tostring(vStatus) or "";

    if (dStatusFrame) then
        dStatusFrame:SetStatusText(sStatusText, 0);
    end
end

--[[!
@fqxn CFS.Modules.Globals.Status.Append
@pulsarlua function Status.Append
@desc Appends a status line through the shared status setter.
@param any vStatus Status.
@vis public
!]]
function Status.Append(vStatus)
    local sStatus = vStatus and tostring(vStatus) or "";

    Status.Set(sStatusText..sStatus.."\r\n");
end


--[[!
@fqxn CFS.Modules.Globals.BuildJSON
@pulsarlua function BuildJSON
@desc Builds the tutorial-data script with ordered sections and Base64-encoded HTML items.
@param any tSections Sections.
@param any tSectionOrder Section order.
@param any tFlatOrder Flat order.
@vis public
!]]
function BuildJSON(tSections, tSectionOrder, tFlatOrder)

    if not (type(tSections) == "table") then
        error("BuildJSON: tSections must be a table.", 2);
    end

    if not (type(tSectionOrder) == "table") then
        error("BuildJSON: tSectionOrder must be a table.", 2);
    end

    if not (type(tFlatOrder) == "table") then
        error("BuildJSON: tFlatOrder must be a table.", 2);
    end

    local tJS = {};
    tJS[#tJS + 1] = "<script>";
    tJS[#tJS + 1] = "window.TUTORIAL_DATA = {";
    tJS[#tJS + 1] = "    \"sections\": {";

    for s = 1, #tSectionOrder do
        local sSection = tSectionOrder[s];
        local tItems   = tSections[sSection];

        tJS[#tJS + 1] = "        "..string.format("%q", sSection)..": {";
        tJS[#tJS + 1] = "            \"items\": {";

        if (type(tItems) == "table") then
            for i = 1, #tItems do
                local tItem = tItems[i];
                local sComma = (i < #tItems and "," or "");

                local sKey   = tostring(tItem.Key or "");
                local sTitle = tostring(tItem.Title or "UNKNOWN");
                local sHTML  = tostring(tItem.HTML or "");
                local sB64   = base64.enc(sHTML) or "";

                tJS[#tJS + 1] = "                "..string.format("%q", sKey)..": {";
                tJS[#tJS + 1] = "                    \"title\": "..string.format("%q", sTitle)..",";
                tJS[#tJS + 1] = "                    \"html_b64\": "..string.format("%q", sB64);
                tJS[#tJS + 1] = "                }"..sComma;
            end
        end

        tJS[#tJS + 1] = "            }";
        tJS[#tJS + 1] = "        }"..(s < #tSectionOrder and "," or "");
    end

    tJS[#tJS + 1] = "    },";
    tJS[#tJS + 1] = "    \"order\": [";

    for i = 1, #tFlatOrder do
        local sComma = (i < #tFlatOrder and "," or "");
        tJS[#tJS + 1] = "        "..string.format("%q", tFlatOrder[i])..sComma;
    end

    tJS[#tJS + 1] = "    ]";
    tJS[#tJS + 1] = "}";
    tJS[#tJS + 1] = "</script>";

    return table.concat(tJS, "\n");
end


--[[!
@fqxn CFS.Modules.Globals.OnStartUp
@pulsarlua function OnStartUp
@desc Seeds random generation, attaches the status frame, and installs duplicate-suppressed runtime error reporting.
@param any dMainFrame Main frame.
@vis public
!]]
function OnStartUp(dMainFrame)
    math.randomseed(os.time());
    math.random();
    math.random();
    math.random();

    dStatusFrame = dMainFrame;

    local sLastError = "";

    --[[!
    @fqxn CFS.Modules.Globals.CustomRuntimeErrorHandler
@pulsarlua function CustomRuntimeErrorHandler
    @desc Reports a runtime error only when it differs from the previous error.
    @param any sError Error.
    @vis public
    !]]
    CustomRuntimeErrorHandler = function(sError)
        sError = tostring(sError);

        if (sError ~= sLastError) then
            require("Errors").report(sError);
            sLastError = sError;
        end


    end

    -- TODO Restore the development startup copy of Docs/Changelog.md to the repository's Changelog.md using the new file paths and Lua file operations.
    -- TODO Connect card-set processing after the remaining ProcSys services are ported.
    Game.Refresh();
    -- Startup does not clear logs, write configuration, or create files in linked games.
    Log.Note("Globals initialized: application paths, constants, INI, CSV, and virtual filesystem.");
end
