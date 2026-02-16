local math = math;
local clamp = math.clamp;

local _sOriginalPackagePath = package.path;





_NoExitScriptOnPageJump = true;


--🅲🅾🅽🆂🆃🅰🅽🆃🆂
--csv parameters
constant("BACKUP_MINIMUM_INTERVAL", 6); --in minutes
constant("BACKUP_MAX_FILE_COUNT", 10);
constant("CSV_DELIMITER", ',');
--image parameters
constant("HOR", 0);
constant("VER", 1);
constant("BIT_DEPTH_32", 32);

--🅶🅻🅾🅱🅰🅻 🅿🅰🆃🅷🆂
constant("APP_CFG",         "Card Forge.cfg");

constant("_pTemplates",     _Docs.."\\Templates");
constant("_pAppDir",        _AppDataLocal.."\\Card Forge");
constant("_pGames",         _pAppDir.."\\Games");
constant("_pAppCFG_T",      _pTemplates.."\\"..APP_CFG); --template
constant("_pAppCFG",        _pAppDir.."\\"..APP_CFG);

constant("LICENSE", TextFile.ReadToString(_Docs.."\\Licenses\\licenses.txt"));

CFG             = {}; --TODO lock/unlock table as needed

function NewGame()
    local sGame             = Dialog.Input("Create New Game", "Game name:", "", MB_ICONINFORMATION);
    local bCancelPressed    = sGame == "CANCEL";
    local bIsEmpty          = sGame:isempty();
    local bIsFilesafe       = sGame:isfilesafe();

    if (not bCancelPressed and not bIsEmpty) then

        if (bIsFilesafe) then
            PrepGame(_pGames.."\\"..sGame);
            MainMenu.RefreshGamesList();
            Page.Jump("Forge");
        else
            Dialog.Message("Error Creating Game", '"'..sGame.."\"\r\n is not file-safe.");
        end

    end

end

--assumes pFile and vFile are good
local function CheckFile(pFile, vFile)

    if not (File.DoesExist(pFile)) then

        if (File.DoesExist(vFile)) then
            File.Copy(vFile, pFile, true, false, false, true, nil);
        else
            TextFile.WriteFromString(pFile, vFile, false);
        end

    end

end

local function CheckFolder(pFolder)

    if not (Folder.DoesExist(pFolder)) then
        Folder.Create(pFolder);
    end

end

local function BuildInfoFile(sGame)
    local sRet =[[
[SETTINGS]
;true puts all Plugin/luaEx Dox in your API help file(increases boot time)
IncludePlugins=false
Name=${game}]] % {
    game = sGame,
};

    return sRet;
end

--assumes the path is good...even though it need not exist
function PrepGame(pGame)
    --reset the package path
    package.path = _sOriginalPackagePath;

    --setup the game's folder
    _pGame          = pGame;                        CheckFolder(pGame);
    _pDocs          = _pGame    .."\\Docs";         CheckFolder(_pDocs);
    _pTemp          = _pGame    .."\\Temp";         CheckFolder(_pTemp);
    _pCSVSource     = _pGame    .."\\CSV Source";   CheckFolder(_pCSVSource);
    _pCSVBackup     = _pGame    .."\\CSV Backup";   CheckFolder(_pCSVBackup);
    _pCSVExport     = _pGame    .."\\CSV Export";   CheckFolder(_pCSVExport);
    _pCardExport    = _pGame    .."\\Card Export";  CheckFolder(_pCardExport);
    _pScripts       = _pGame    .."\\Scripts";      CheckFolder(_pScripts);
    _pCards         = _pGame    .."\\Cards";        CheckFolder(_pCards);
    _pSymbols       = _pGame    .."\\Symbols";      CheckFolder(_pSymbols);
    _pConfig        = _pScripts .."\\Config";       CheckFolder(_pConfig);

    --set the game name
    _sGame = Path.GetEndFolder(pGame);

    --setup the game's files
    _pDrafts        = _pGame.."\\Drafts.lua";   CheckFile(_pDrafts,                     "return\r\n{\r\n};"); --QUESTION IS THIS BEING USED?
    _pInfo          = _pGame.."\\Info.ini";     CheckFile(_pInfo,                       BuildInfoFile(_sGame));
    _pScratch       = _pTemp.."\\Scratch.lua";  CheckFile(_pScratch,                    "");
    _pStyles        = _pGame.."\\Styles.ini";   CheckFile(_pStyles,                     _pTemplates.."\\Styles.ini");
                                                CheckFile(_pScripts.."\\InitForge.lua", _pTemplates.."\\InitForge.lua");
                                                CheckFile(_pScripts.."\\Config.lua",    _pTemplates.."\\Config.lua");

    --add game's scripts folder to the package path
    package.path = _sOriginalPackagePath..";".._pGame.."\\Scripts\\?.lua";

    --init and set the game's forge
    ProcSys.PrepActiveGame();
    local oForge = require("InitForge");
    ProcSys.SetForge(oForge);

    --load the config files
    CFG = require("Config");

    ProcessDox(pGame);--TODO get this boolean from INI file before running Dox
end
--common files
--_pStyles    = _pGame.."\\Styles.ini" ???Why is this commented out?

function ProcessDox(pGame)
    local sName             = INIFile.GetValue(_pInfo, "SETTINGS", "Name");
    local sName             = ( type.isstring(sName) and not sName:isempty() and sName:isfilesafe()) and
                                sName or "Card Forge";
    local bIncludePlugins   = INIFile.GetValueBoolean(_pInfo, "SETTINGS", "IncludePlugins");

    local tFiles = {};
    local oDoxLua = DoxLua(sName); --create the dox object

    local function ImportFile(pFile) --callback function for found files
        oDoxLua.importFile(pFile, true);
        return true;
    end

    --start with the app scripts
    File.Find(_Scripts.."\\", "*.lua", false, false, nil, ImportFile);

    local sPluginsRoot          = _Scripts.."\\Plugins";
    local nPluginsRootLength    = #sPluginsRoot;

    --add files from the app's Scripts subfolders
    for nIndex, pFolder in ipairs(Folder.Find(_Scripts, "*", false, nil)) do

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
    File.Find(_pGame.."\\", "*.lua", true, false, nil, ImportFile);

    --if the user has included an intro doc in the game, load it too
    local pIntro = _pDocs.."\\intro"
    if (File.DoesExist(pIntro)) then
        oDoxLua.setIntro(TextFile.ReadToString(pIntro));
    end

    --refresh the dox content
    oDoxLua.refresh();
    --set the output path
    oDoxLua.setOutputPath(_pDocs);
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

    local tStyles = INIFile.GetSectionNames(_pStyles);

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


function OnStartUp()--TODO move to its own module if it gets too big
    math.randomseed(os.time());
    math.random();
    math.random();
    math.random();

    local bIsCompiled = Application.IsCompiled();

    --TODO make all basic files as needed here
    if not (File.DoesExist(_pAppCFG)) then
        File.Copy(_pAppCFG_T, _pAppCFG, true, false, false, true, nil);
    end

    if not (bIsCompiled) then
        local sVersion = CoG.BuildVersionID();
        INIFile.SetValue(_pAppCFG, "Settings", "Version", sVersion);
        constant("APP_VERSION", sVersion);
    else
        constant("APP_VERSION", INIFile.GetValue(_pAppCFG, "Settings", "Version"));
    end

    constant("HWND_APP", Application.GetWndHandle());


    --load the menu
    MainMenu = require("MainMenu");



    --ScalerX.OnStartup(1400, 1200);
end
