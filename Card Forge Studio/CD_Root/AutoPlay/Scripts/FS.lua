local _sOriginalPackagePath = package.path;

--preset values, constant throughout program flow
local pTemplates   = _Docs.."\\Templates";
local pAppDir      = _AppDataLocal.."\\Card Forge";
local pGames       = pAppDir.."\\Games";
local pAppCFG_T    = pTemplates.."\\"..APP_CFG; --template
local pAppCFG      = pAppDir.."\\"..APP_CFG;
local pTutorials   = _Docs.."\\Tutorials";

local tPaths = {
    Templates   = pTemplates,
    AppDir      = pAppDir,
    Games       = pGames,
    AppCFG_T    = pAppCFG_T,
    AppCFG      = pAppCFG,
    Tutorials   = pTutorials,
};

local function BuildInfoFile(sGame) --TODO move this
    local sRet =[[
[SETTINGS]
;true puts all Plugin/luaEx Dox in your API help file(increases boot time)
IncludePlugins=false
Name=${game}]] % {
    game = sGame,
};

    return sRet;
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

local tFunctions = {
    --Name = functoions
    PrepSet = function()

    end,
    --assumes
    PrepGame = function(sGame)
        --reset the package path
        package.path = _sOriginalPackagePath;

        if not (type(sGame) == "string") then
            error("FS: Error prepping game paths. Argument 1 must be of type string. Got "..type(sGame)..'.');
        end

        local oGame = Game.GetByName(sGame);

        if not (type(oGame) == "Game") then
            error("FS: Error prepping game paths. Could not find game object for \""..type(sGame)..'."');
        end

        Game.SetActive(sGame);

        local pGame = oGame.GetPath();

        if not (io.isdirectchild(pGames, pGame)) then
            error("FS: Error prepping game paths.\r\n\"${game}\" is not located in the expected directory of\r\n\"${games}.\"" % {game = pGame, games = pGames});
        end

        --setup the game's folder
        tPaths.Game         = pGame;                                --CheckFolder(pGame);
        tPaths.Docs         = pGame             .."\\Docs";         CheckFolder(tPaths.Docs);
        tPaths.Temp         = pGame             .."\\Temp";         CheckFolder(tPaths.Temp);
        --tPaths.CardSets     = pGame             .."\\Sets";         CheckFolder(tPaths.CardSets);
        tPaths.Set          = ""; --Gets set during set loading
        tPaths.CSVBackup    = pGame             .."\\CSV Backup";   CheckFolder(tPaths.CSVBackup);
        tPaths.CSVExport    = pGame             .."\\CSV Export";   CheckFolder(tPaths.CSVExport);
        tPaths.CardExport   = pGame             .."\\Card Export";  CheckFolder(tPaths.CardExport);
        tPaths.Scripts      = pGame             .."\\Scripts";      CheckFolder(tPaths.Scripts);
        tPaths.Cards        = pGame             .."\\Cards";        CheckFolder(tPaths.Cards);
        tPaths.Symbols      = pGame             .."\\Symbols";      CheckFolder(tPaths.Symbols);
        tPaths.Config       = tPaths.Scripts    .."\\Config";       CheckFolder(tPaths.Config);

        --set the game name
        _sGame = oGame.GetName(); --TODO FINISH UPDATE THIS

        --setup the game's files
        tPaths.Drafts        = pGame.."\\Drafts.lua";           CheckFile(tPaths.Drafts,                        "return\r\n{\r\n};"); --QUESTION IS THIS BEING USED?
        tPaths.Info          = pGame.."\\Info.ini";             CheckFile(tPaths.Info,                          BuildInfoFile(_sGame));
        tPaths.Scratch       = tPaths.Temp.."\\Scratch.lua";    CheckFile(tPaths.Scratch,                       "");
        tPaths.Styles        = pGame.."\\Styles.ini";           CheckFile(tPaths.Styles,                        pTemplates.."\\Styles.ini");
                                                                CheckFile(tPaths.Scripts.."\\InitForge.lua",    pTemplates.."\\InitForge.lua");
                                                                CheckFile(tPaths.Scripts.."\\Config.lua",       pTemplates.."\\Config.lua");

        --add game's scripts folder to the package path
        package.path = _sOriginalPackagePath..";"..pGame.."\\Scripts\\?.lua";

        --load the game's config
        CFG = require("Config");
    end,
};

local tFSMeta     = {
    __index = function(t, k)
        return tPaths[k] or tFunctions[k];
    end,
    __newindex = function(t, k, v) error("Atempt to write to read only FS table.") end,
};

local tFSDecoy    = {};

setmetatable(tFSDecoy, tFSMeta);

rawset(_G, "FS", tFSDecoy);
