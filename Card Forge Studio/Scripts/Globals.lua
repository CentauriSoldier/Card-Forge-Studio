--[[!
@fqxn CFS.Modules.Globals
@desc
<section aria-label="Globals overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">Globals</h2><p style="font-size:1.15rem;margin:0">Globals connects the application services during startup.</p></div>
<h3>How it fits into your work</h3><p>Setup loads dependencies and connects logging, filesystem, processing, and status services. Development documentation generation requires both development flags.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Constants">Constants</a></h3><p style="margin:0">Shared constants let Studio services agree on names, paths, and processing choices.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.FS">File System</a></h3><p style="margin:0">FS is Studio's map of where project files belong.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys">Processing System</a></h3><p style="margin:0">ProcSys keeps project files, card values, and the preview working together as you edit.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.Log">Log</a></h3><p style="margin:0">Logging records Studio activity and preserves useful context when something goes wrong.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Development builds generate HTML and a Pulsar package, install the package, then delete its ZIP only after successful extraction. This is separate from a loaded game's documentation.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
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
@fqxn CFS.Modules.Globals.Private.Functions.tGlobalMeta___index
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
@fqxn CFS.Modules.Globals.Private.Functions.tGlobalMeta___newindex
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
@fqxn CFS.Modules.Globals.Functions.LoadGameModules
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
@fqxn CFS.Modules.Globals.Status.Functions.Set
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
@fqxn CFS.Modules.Globals.Status.Functions.Append
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
@fqxn CFS.Modules.Globals.Functions.BuildJSON
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
@fqxn CFS.Modules.Globals.Functions.OnStartUp
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
    @fqxn CFS.Modules.Globals.Functions.CustomRuntimeErrorHandler
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
