local math = math;
local clamp = math.clamp;

_NoExitScriptOnPageJump = true;

require("constants");   --load the constants
require("FS");          --load the program's file/path management system

CFG             = {}; --TODO lock/unlock table as needed
--[[
function SortByEndFolder(a, b)
    local sGameA = io.getenddir(a);
    local sGameB = io.getenddir(b);
    return sGameA < sGameB;
end]]

function NewGame() --TODO move to game module
    local sGame             = Dialog.Input("Create New Game", "Game name:", "", MB_ICONINFORMATION);
    local bCancelPressed    = sGame == "CANCEL";
    local bIsEmpty          = sGame:isempty();
    --local bIsFilesafe       = sGame:isfilesafe();

    if (not bCancelPressed and not bIsEmpty) then

        if (bIsFilesafe) then
            PrepGame(sGame);
            MainMenu.RefreshGamesList();
            Page.Jump("Forge");
        --else
            --Dialog.Message("Error Creating Game", '"'..sGame.."\"\r\n is not file-safe.");
        end

    end

end



--assumes the path is good...even though it need not exist
function PrepGame(sGame) --TODO move to game module

    FS.PrepGame(sGame); --set the filepaths for the current game

    --reset the BuildMechanics var (it gets reloaded in InitForge.lua if present)
    BuildMechanics = nil;

    --init and set the game's forge
    ProcSys.PrepActiveGame();
    local oForge = require("InitForge");
    ProcSys.SetForge(oForge);

    --build the user's mechanics html if it exists
    if type(BuildMechanics) == "function" then
        local sHTML = BuildMechanics(CFG);

        if (type(sHTML) == "string") then
            TextFile.WriteFromString(_pGame.."\\Mechanics.html", sHTML, false);
        end

    end

    ProcessDox(pGame);--TODO get this boolean from INI file before running Dox
end
--common files
--_pStyles    = _pGame.."\\Styles.ini" ???Why is this commented out?

function ProcessDox(pGame)
    local sName             = INIFile.GetValue(FS.Info, "SETTINGS", "Name");
    local sName             = ( type.isstring(sName) and not sName:isempty() and sName:isfilesafe()) and
                                sName or "Card Forge";
    local bIncludePlugins   = INIFile.GetValueBoolean(FS.Info, "SETTINGS", "IncludePlugins");

    local tFiles = {};
    local oDoxLua = DoxLua(sName); --create the dox object

    local function ImportFile(pFile) --callback function for found files
        oDoxLua.importFile(pFile, true);
        return true;
    end

    --start with the app scripts
    local pScripts = FS.Scripts;
    File.Find(pScripts.."\\", "*.lua", false, false, nil, ImportFile);

    local sPluginsRoot          = pScripts.."\\Plugins";
    local nPluginsRootLength    = #sPluginsRoot;

    --add files from the app's Scripts subfolders
    for nIndex, pFolder in ipairs(Folder.Find(pScripts, "*", false, nil)) do

        if (pFolder:sub(1, nPluginsRootLength) == sPluginsRoot) then

            --don't run Dox inside the Plugins dir unless it's explicitly permitted
            if (bIncludePlugins) then
                File.Find(pFolder.."\\", "*.lua", true, false, nil, ImportFile);
            end

        else
            File.Find(pFolder.."\\", "*.lua", true, false, nil, ImportFile);
        end

    end

    --now, add any of the game's scripts that exist
    File.Find(FS.Game.."\\", "*.lua", true, false, nil, ImportFile);

    --if the user has included an intro doc in the game, load it too
    local pIntro = FS.Docs.."\\intro"
    if (File.DoesExist(pIntro)) then
        oDoxLua.setIntro(TextFile.ReadToString(pIntro));
    end

    --refresh the dox content
    oDoxLua.refresh();
    --set the output path
    oDoxLua.setOutputPath(FS.Docs);
    --create the output
    oDoxLua.export(sName.." API");
end

ELProfiler = require("Plugins.ELProfiler");
ELProfiler.setClock(os.clock);

--🅻🅾🅰🅳 🅷🅴🅻🅿🅴🆁 🅲🅻🅰🆂🆂🅴🆂
ProcSys     = require("ProcSys");
Forge       = require("Forge");
StyleEditor = require("StyleEditor");
WinSys      = require("WinSys");
    WinAMS  = require("WinSys.WinAMS");
Tutorial    = require("Tutorial");
Game        = require("Game");

--TODO remove?
Editor      = require("Editor");



--[[!
    @fqxn CFS.UserEnv
    @desc The Lua environment used in Card Forge Studio's lua editor.
    <br>You can hook this function to inject whatever you need into your game's User Envrironment so you have access to them inside the editor.
    <br>Generally, it's best to do this in your game's InitForge.lua file.
    @ex
    --store the original function so it can be hooked in the override
    local _GetUserEnv = GetUserEnv;

    --override the basic GetUserEnv function to include your game's required items and
    --append as needed to the default env table (but only once for each item)
    function GetUserEnv()
        -- Get the default environment
        local tEnv = _GetUserEnv()

        -- Inject enums if missing
        if not tEnv.Enums then
            tEnv.Enums = {
                DamageType = { Kinetic = 1, Energy = 2, True = 3 },
                UnitLayer  = { Land = 1, Sea = 2, Air = 3 },
            }
        end

        -- Inject read-only game helpers if missing
        if not tEnv.Game then
            tEnv.Game = {
                GetTurn = function()
                    return Game.GetTurn()
                end,
            }
        end

        -- Inject logging helpers if missing
        if not tEnv.Log then
            tEnv.Log = {
                Info = function(msg)
                    Editor.Log("INFO", msg)
                end,
                Warn = function(msg)
                    Editor.Log("WARN", msg)
                end,
            }
        end

        -- Inject utility helpers if missing
        if not tEnv.Math then
            tEnv.Math = {
                Clamp = function(v, min, max)
                    return math.max(min, math.min(max, v))
                end,
            }
        end

        --return the modified environment
        return tEnv;
    end
!]]
function GetUserEnv()
    local tRet = {
        -- Lua basics
       ipairs       = ipairs,
       pairs        = pairs,
       tonumber     = tonumber,
       tostring     = tostring,
       type         = type,
       math         = math,
       string       = string,
       table        = table,

       -- LuaEx basics
       RNG          = RNG,
       array        = array,
       class        = class,
       enum         = enum,
       rawtype      = rawtype,
       struct       = struct,
       structfactory= structfactory,

       clamp        = math.clamp,
       drift        = math.drift,
       driftf       = math.driftf,
       rand         = math.random,
       randf        = math.randomf,
       min          = math.min,
       max          = math.max,
       pick         = RNG.pick,
       print        = p,

       S            = null, --Style
       CFG          = CFG,
    };

    tRet.S = {};

    local tStyles = INIFile.GetSectionNames(FS.Styles);

    if (tStyles) then

        for _, sStyle in ipairs(tStyles) do
            tRet.S[sStyle] = setmetatable(
            {
                O = '<'..sStyle..'>',
                C = '</'..sStyle..'>',
            },
            {
                __call = function(t, vText)
                    return '<'..sStyle..'>'..tostring(vText)..'</'..sStyle..'>'
                end,
            }
            );
        end

    end

    return tRet;
end

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

Description = require("Description");

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

    --TODO make all basic files as needed here
    if not (File.DoesExist(FS.AppCFG)) then
        File.Copy(FS.AppCFG_T, FS.AppCFG, true, false, false, true, nil);
    end

    if not (bIsCompiled) then
        local sVersion = CoG.BuildVersionID();
        INIFile.SetValue(FS.AppCFG, "Settings", "Version", sVersion);
        constant("APP_VERSION", sVersion);
    else
        constant("APP_VERSION", INIFile.GetValue(FS.AppCFG, "Settings", "Version"));
    end

    constant("HWND_APP", Application.GetWndHandle());

    --load all games
    Game.Refresh();

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

    --ScalerX.OnStartup(1400, 1200);
end
