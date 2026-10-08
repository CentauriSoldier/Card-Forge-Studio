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

tGlobalMeta.__newindex = function(tGlobal, sKey, vValue)
    if (fBootstrapRead(tGlobal, sKey) ~= nil) then
        return fBootstrapWrite(tGlobal, sKey, vValue);
    end

    return fGlobalWrite(tGlobal, sKey, vValue);
end

require("Constants");

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
function LoadGameModules()
    local tImportSystem = require("Globals.ImportSystem");

    Import          = tImportSystem.Import;
    SanitizePath    = tImportSystem.SanitizePath;
    ProcessDox      = require("Globals.ProcessDox");
    Exporter        = require("Exporter");
    ExporterImage   = require("Exporters.ExporterImage");
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

function Status.Set(vStatus)
    sStatusText = vStatus and tostring(vStatus) or "";

    if (dStatusFrame) then
        dStatusFrame:SetStatusText(sStatusText, 0);
    end
end

function Status.Append(vStatus)
    local sStatus = vStatus and tostring(vStatus) or "";

    Status.Set(sStatusText..sStatus.."\r\n");
end


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


function OnStartUp(dMainFrame)
    math.randomseed(os.time());
    math.random();
    math.random();
    math.random();

    dStatusFrame = dMainFrame;

    local sLastError = "";

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
