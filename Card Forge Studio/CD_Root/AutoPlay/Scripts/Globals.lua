local math = math;
local clamp = math.clamp;
_NoExitScriptOnPageJump = true;

CFG             = {}; --TODO lock/unlock table as needed TODO REMOVE THIS...IT WILL BE PUSHED IN DURING PREP OR THE LIKE

require("Constants");   --load the constants

ELProfiler = require("Plugins.ELProfiler");
ELProfiler.setClock(os.clock);

FS                  = require("Globals.FS");  --load the program's file/path management system
Log                 = require("Log");

local tImportSystem = require("Globals.ImportSystem");
Import              = tImportSystem.Import;
SanitizePath        = tImportSystem.SanitizePath;
ProcessDox          = require("Globals.ProcessDox");

FontStyle   = require("FontStyle");
ProcSys     = require("ProcSys");
Forge       = require("Forge");
StyleEditor = require("StyleEditor");
Game        = require("Game");
Tutorial    = require("Tutorial");
UserEnv     = require("Globals.UserEnv");

--TODO Modify this entire system to be more universal?
Description = require("Description");



--TODO QUESTION DELETE?
--Editor      = require("Editor");

Status = {};
local sPar = "par status";
function Status.Set(vStatus)
    local sStatus = vStatus and tostring(vStatus) or "";
    Paragraph.SetText(sPar, sStatus);
end
function Status.Append(vStatus)
    local sStatus = vStatus and tostring(vStatus) or "";
    Paragraph.SetText(sPar, Paragraph.GetText(sPar)..sStatus.."\r\n");
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


function OnStartUp()--TODO move to its own module if it gets too big
    math.randomseed(os.time());
    math.random();
    math.random();
    math.random();

    local bIsCompiled = Application.IsCompiled();

    Log.ClearFile();

    --TODO make all basic files as needed here
    if not (File.DoesExist(FS.AppCFG)) then
        File.Copy(FS.AppCFG_T, FS.AppCFG, true, false, false, true, nil);
    end

    if not (bIsCompiled) then
        local sVersion = CoG.BuildVersionID(APP_MAJOR_VERSION, APP_BUILD_VERSION);
        INIFile.SetValue(FS.AppCFG, "Settings", "Version", sVersion);
        constant("APP_VERSION", sVersion);
    else
        constant("APP_VERSION", INIFile.GetValue(FS.AppCFG, "Settings", "Version"));
    end

    constant("HWND_APP",    Application.GetWndHandle());
    constant("HWND_DEBUG",  Debug.GetWndHandle());

    Log.OnStartup();

    --load all games
    local bOK, sError = pcall(Game.Refresh);

    if not (bOK) then
        --TODO LOG
        Dialog.Message("Game.Refresh Error", sError);
    end

    --load the menu
    MainMenu = require("MainMenu");

    --copy the app's changelog to the github repo
    if not (bIsCompiled) then
        local sFile     = "\\Changelog.md";
        local pSource   = _Docs..sFile;
        local pDes      = io.normalizepath(_Docs.."\\..\\..\\..\\..\\")..sFile;
        local sText     = TextFile.ReadToString(pSource);
        TextFile.WriteFromString(pDes, sText, false);
    end

    --build the tutorials
    if not (bIsCompiled and File.DoesExist(Tutorial.PATH_INDEX)) then
        Tutorial.Init();
    end

    local sLastError = ""; --TODO move this to the log file and setup warning the same way...maybe use  anumber ot indicate amount of the same errors
    CustomRuntimeErrorHandler = function(sError)--TODO add option to show log on error if window is hidden!!

        if not (sError == sLastError) then
            Log.Error(sError);
            sLastError = sError;
        end

    end

    _DisableRuntimeErrorDialog = true;--bIsCompiled;
    --ScalerX.OnStartup(1400, 1200);
end
