local _tGames       = {}; --keys are uuids, values are {Game = GameObject, Name = NameString}
local _oActiveGame  = false;
local GetCRC        = File.GetCRC
local ReadToString  = TextFile.ReadToString;
local CardSet;
local io            = io;
--TODO with New methods, checkf or existing item first...do not overwrite

--[[
█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗
╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝
                                                ██╗      ██████╗  ██████╗ █████╗ ██╗
                                                ██║     ██╔═══██╗██╔════╝██╔══██╗██║
                                                ██║     ██║   ██║██║     ███████║██║
                                                ██║     ██║   ██║██║     ██╔══██║██║
                                                ███████╗╚██████╔╝╚██████╗██║  ██║███████╗
                                                ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝
█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗
╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝
]]


--[[
    @fqxn   CFS.ValidateName
    @desc   Reads and validates the display name for a folder-backed object (Game/CardSet/etc.).
            Looks up "Name" under [SETTINGS] in "<Folder>\Info.ini".
            Throws if the value is missing/empty.
    @param  pFolder (string) Absolute path to the object folder.
    @param  sType   (string) Human-readable type label used in error messages (e.g. "Game", "CardSet").
    @return (string) The validated name string from the INI.
    @error  Raised when the INI value is missing or empty.
]]
local function ValidateName(pFolder, sType)

    local sName = INIFile.GetValue(pFolder.."\\Info.ini", "SETTINGS", "Name");

    if (sName:isempty()) then
        error("Invalid ${type}: Malformed ${type} INI file at ${path}. Missing \"Name\" value." % {path = pFolder, type = sType}, nErrorLevel);
    end

    return sName;
end


local function ValidateFolder(pFolder, sType)
    local nErrorLevel = 4;

    --get and validate the game's uuid
    local sUUID = io.getenddir(pFolder);

    if not (sUUID:isuuid()) then
        error("Invalid ${type}: ${type} directory must be named a valid uuid string. Got \"${folder}\" at path\r\n\"${path}.\"" % {folder = sUUID, path = pFolder, type = sType}, nErrorLevel);
    end

    return sUUID;
end


local function ValidateAndUpdateGame(this, cdat)
    local pri           = cdat.pri;
    local pFolder       = pri.Path;
    local nErrorLevel   = 3;
    local sType         = "Game";

    --get and validate the game's uuid
    local sUUID = ValidateFolder(pFolder, sType);

    --validate the game's name
    local sName = ValidateName(pFolder, sType);

    pri.UUID = sUUID;
    pri.Name = sName;

    --register/update the game object's reference
    _tGames[pri.UUID] = {
        Name    = sName,
        Object  = this,
    };

    --updade the game's card sets
    pri.CardSets = {};

    --iterate over all potential card set folders
    local tCardSetFolders  = Folder.Find(pFolder.."\\Sets\\", "*", false, nil);

    if (type(tCardSetFolders) == "table") then

        for _, pCardSetFolder in pairs(tCardSetFolders) do

            if (io.getenddir(pCardSetFolder):lower() ~= ".ignore") then

                --try to create the new cardset object
                local oCardSet = CardSet(pCardSetFolder);

                pri.CardSets[oCardSet.GetUUID()] = {
                    Name    = oCardSet.GetName();
                    Object  = oCardSet,
                };

            end

        end

    end

end

local function SortByName(oItemA, oItemB)
    return oItemA.GetName() < oItemB.GetName();
end

local function UpdateCardSetCallCode(sCall, tCall)
    local bRet      = false;
    local pCallCode = tCall.Path;

    if not (File.DoesExist(pCallCode)) then
        --TODO FINISH ERROR
        error("NO FILE, OMG! AHHHHH!!!!"..sCall);
    end

    --get the new CRC
    local nCRC = GetCRC(tCall.Path);

    if (nCRC == -1) then --an error occurred if it does == -1
        --TODO ERROR HERE
    end

    --compare it the existing one
    if (nCRC ~= tCall.CRC) then
        --set the newest CRC for this call
        tCall.CRC = nCRC;
        tCall.Code = ReadToString(pCallCode); --TODO THROW ERROR on file read error
        p(sCall)
    end

    return bRet;
end


--[[
█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗
╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝
                                         ██████╗ █████╗ ██████╗ ██████╗ ███████╗███████╗████████╗
                                        ██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝╚══██╔══╝
                                        ██║     ███████║██████╔╝██║  ██║███████╗█████╗     ██║
                                        ██║     ██╔══██║██╔══██╗██║  ██║╚════██║██╔══╝     ██║
                                        ╚██████╗██║  ██║██║  ██║██████╔╝███████║███████╗   ██║
                                         ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝   ╚═╝
█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗
╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝
]]
CardSet = class("CardSet",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --CardSet = function(this, sAuthCode) end, --static constructor (runs after class object creation)
        --CardSetExists = function(sCardSet) end
        --rebuilds all game objects and refreshes the private static info
    },
    {--PRIVATE
        --Calls               = {}, --holds things like Draw, Proc, etc.
        CallRepo            = null,
        CardWidth__AUTOR_   = null,
        CardHeight__AUTOR_  = null,
        DataPath__AUTOR_    = null,
        InfoPath__AUTOR_    = null,
        IsActive__AUTOA_    = false,
        Name__AUTOA_        = '',
        Path__AUTOR_        = null,
        UUID__AUTOR_        = null,
    },
    {--PROTECTED

    },
    {--PUBLIC
        CardSet = function(this, cdat, pFolder)
            local pri = cdat.pri;

            --validate the input string and ensure it leads to a valid directory
            if not (rawtype(pFolder) == "string" and Folder.DoesExist(pFolder)) then
                error("Invalid CardSet: CardSet path must lead to an existing directory.", 3);
            end

            local pData     = pFolder.."\\"..FILER_CARDSET_DATA.Full;
            local pInfo     = pFolder.."\\"..FILER_CARDSET_INFO.Full;

            --call files
            local pDrawPath     = pFolder.."\\"..FILER_CARDSET_DRAW.Full;
            local pCellProcPath = pFolder.."\\"..FILER_CARDSET_CELLPROC.Full;

            local tCheckFiles = {pData, pInfo, pDrawPath, pCellProcPath};

            for _, pFile in pairs(tCheckFiles) do

                if not (File.DoesExist(pFile)) then
                    error("Invalid CardSet: missing expected file at \""..pFile..".\"");
                end

            end

            --TODO SPECIAL COLUMNS!!!
            local sUUID         = ValidateFolder(pFolder, "CardSet");
            local sName         = ValidateName(pFolder, "CardSet");
            local nCardWidth    = tonumber(INIFile.GetValue(pFolder.."\\Info.ini", "SETTINGS", "CardWidth"));
            local nCardHeight   = tonumber(INIFile.GetValue(pFolder.."\\Info.ini", "SETTINGS", "CardHeight"));

            if (not nCardWidth) then
                error("Invalid ${type}: Malformed ${type} INI file at ${path}. Missing \"CardWidth\" value or non-numeric value given." % {path = pFolder, type = sType}, 2);
            end

            if (not nCardHeight) then
                error("Invalid ${type}: Malformed ${type} INI file at ${path}. Missing \"CardHeight\" value or non-numeric value given." % {path = pFolder, type = sType}, 2);
            end

            --set the game's info
            pri.DataPath    = pData;
            pri.InfoPath    = pInfo;
            pri.Name        = sName;
            pri.Path        = pFolder;
            pri.UUID        = sUUID;
            pri.CardWidth   = math.abs(nCardWidth);
            pri.CardHeight  = math.abs(nCardHeight);

            --create the LiveFileRepo and register the LiveFiles for each call.
            local oCallRepo = LiveFile.CreateRepo();
            pri.CallRepo    = oCallRepo;
            LiveFile.Register(oCallRepo, "CellProc",    pCellProcPath,  PROCSYS_FILE_SYNC_TIMER_INTERVAL);
            LiveFile.Register(oCallRepo, "Draw",        pDrawPath,      PROCSYS_FILE_SYNC_TIMER_INTERVAL);--TODO SPECIAL COLUMNS!!!
        end,
        GetLiveFile = function(this, cdat, sCall)
            local pri = cdat.pri;
            return pri.CallRepo[sCall];
            --local tCalls = pri.Calls;
            --p(sCall, type(tCalls[sCall].Code))
            --if (tCalls[sCall] == nil) then
            --    error("TODO ERROR CAN'T GET CALL - NO CARDSET CALL BY THAT NAME")
            --end

            --return tCalls[sCall].Code;
        end,
        --[[GetLiveFileRepo = function(this, cdat)
            return cdat.pri.CallRepo;
            --local tCalls = pri.Calls;
            --p(sCall, type(tCalls[sCall].Code))
            --if (tCalls[sCall] == nil) then
            --    error("TODO ERROR CAN'T GET CALL - NO CARDSET CALL BY THAT NAME")
            --end

            --return tCalls[sCall].Code;
        end,]]
        --[[GetCallPath = function(this, cdat, sCall)
            local pri = cdat.pri;
            local tCalls = pri.Calls;
            --p(sCall, type(tCalls[sCall].Code))
            if (tCalls[sCall] == nil) then
                error("TODO ERROR CAN'T GET CALL - NO CARDSET CALL BY THAT NAME")
            end

            return tCalls[sCall].Path;
        end,]]
        GetCardSize = function(this, cdat)
            local pri = cdat.pri;
            return {Width = pri.CardWidth, Height = pri.CardHeight};
        end,
        SetActive = function(this, cdat, vFlag)
            local pri       = cdat.pri;
            local bActive   = rawtype(vFlag) == "boolean" and vFlag or false;

            if (bActive) then
                LiveFile.StartAll(pri.CallRepo);
            else
                LiveFile.StopAll(pri.CallRepo);
            end

        end,
        --updates proc, draw, etc.
        --[[UpdateCallCode = function(this, cdat, sCall)
            local pri       = cdat.pri;
            local tCalls    = pri.Calls;
            local nRet;

            if (tCalls[sCall] == nil) then
                error("TODO ERROR CAN'T UPDATE CALL - NO CARDSET CALL BY THAT NAME");
            end

            local tCall = tCalls[sCall];
            local pCallCode = tCall.Path;

            if not (File.DoesExist(pCallCode)) then
                --TODO FINISH ERROR
                error("NO FILE, OMG! AHHHHH!!!!"..sCall);
            end

            --get the new CRC
            local nCRC = GetCRC(tCall.Path);

            if (nCRC == -1) then --an error occurred if it does == -1
                --TODO ERROR HERE
            end

            --compare it the existing one
            if (nCRC ~= tCall.CRC) then
                --set the newest CRC for this call
                tCall.CRC = nCRC;
                tCall.Code = ReadToString(pCallCode); --TODO THROW ERROR on file read error
                nRet = nCRC;
            end

            return nRet;
        end]]
    },
    nil,   --extending class
    true,  --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);



--[[


█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗
╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝
                                                 ██████╗  █████╗ ███╗   ███╗███████╗
                                                ██╔════╝ ██╔══██╗████╗ ████║██╔════╝
                                                ██║  ███╗███████║██╔████╔██║█████╗
                                                ██║   ██║██╔══██║██║╚██╔╝██║██╔══╝
                                                ╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗
                                                 ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝
█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗█████╗
╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝╚════╝
]]
return class("Game",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --Game = function(this, sAuthCode) end, --static constructor (runs after class object creation)
        GetActive = function()
            return _oActiveGame;
        end,
        GetAll = function()
            local tRet = {};

            for sUUID, tGame in pairs(_tGames) do
                tRet[#tRet + 1] = tGame.Object;
            end

            table.sort(tRet, SortByName);

            return tRet;
        end,
        GetNames = function()
            local tRet = {};

            for sUUID, tGame in pairs(_tGames) do
                tRet[#tRet + 1] = tGame.Name;
            end

            table.sort(tRet, SortByName);

            return tRet;
        end,
        --GameExists = function(sGame) end
        GetByName = function(sName)
            local vRet;

            if not (rawtype(sName) == "string") then
                error("Game.GetByName: Argument 1 must be of type string. Got "..rawtype(sName)..'.');
            end

            for sUUID, tGame in pairs(_tGames) do

                if (sName == tGame.Name) then
                    vRet = tGame.Object;
                    break;
                end

            end

            return vRet;
        end,
        New = function()
            local sGame             = Dialog.Input("Create New Game", "Game name:", "", MB_ICONINFORMATION);
            local bCancelPressed    = sGame == "CANCEL";
            local bIsEmpty          = sGame:isempty();

            if (not bCancelPressed and not bIsEmpty) then

                if (bIsFilesafe) then
                    Game.Prep(sGame);
                    MainMenu.RefreshGamesList();
                end

            end

        end,
        Prep = function(sGame) --TODO REDO THIS NOW THAT IT'S IN THIS MODULE TO INCLUDE VERIFYING THE INPUT

            FS.PrepGame(sGame); --set the filepaths for the current game

            --TODO FIX FINISH THIS SHOULD NOT BE CALLED HERE WITHOUT SAFE ENV
            --Load any config and user environment that may exist TODO BUG FIX - FINISH - USE PROTECTED environment for loading this
            --local sInitChunk    = _oActiveCardSet.GetCallCode("CellProc");
            --TODO MOVE THIS OUT SO IT CAN BE USED IN THING SLIKE oGame.RefreshCFG() and oGame.RefreshEnv() or just oGame.ReInit()
            local sInitChunk = TextFile.ReadToString(FS.Scripts.."\\Init.lua");
            --TODO CHECK AND ERROR on bad file
            --TODO Clear/Refresh UserEnv

            --the error message in case things go south
            local sChunkName = sGame.." Init";

            --try to load the chuck
            local fChunk, sError = load(sInitChunk, sChunkName, "t", UserEnv.Get());
            if not (fChunk) then
                error("Error running Init file for Game "..sGame..".\r\n"..sError, 2); --TODO LOG/display
            end

            --try to call the chunk
            local tInit = {pcall(fChunk)};

            if not (tInit[1]) then
                error("Error running Init file for Game "..sGame..".\r\n"..tInit[2], 2);
            end

            local tCFG, tEnv = table.unpack(tInit, 2);

            if (type(tCFG) == "table") then
                UserEnv.UpdateCFG(tCFG);
            end

            if (type(tEnv) == "table") then
                UserEnv.UserUpdateRoot(tEnv);
            end


            --reset the BuildMechanics var (it gets reloaded in Init.lua if present)
            BuildMechanics = nil;

            --init and set the game's forge
            --ProcSys.PrepActiveGame();

            --build the user's mechanics html if it exists QUESTION qhat is this? Is it used?
            if type(BuildMechanics) == "function" then
                local sHTML = BuildMechanics(CFG);

                if (type(sHTML) == "string") then
                    TextFile.WriteFromString(_pGame.."\\Mechanics.html", sHTML, false);
                end

            end

            ProcessDox(pGame);--TODO get this boolean from INI file before running Dox

            Forge.RefreshStyles();
        end,
        --rebuilds all game objects and refreshes the private static info
        Refresh = function()
            --clear out all games
            _tGames = {};

            --iterate over all potential game folders
            local tGameFolders  = Folder.Find(FS.Games.."\\", "*", false, nil);

            if (type(tGameFolders) == "table") then

                for _, pGameFolder in pairs(tGameFolders) do
                    --try to create the new game object
                    Game(pGameFolder);
                end

            end

        end,
        SetActive = function(vGame) --TODO update game objects
            local zName = type(vGame);
            local oGame;

            if (zName == "string") then

                if (_tGames[vGame] ~= nil) then
                    oGame = _tGames[vGame].Object;

                else

                    for sUUID, tGame in pairs(_tGames) do

                        if (tGame.Name:lower() == vGame:lower()) then
                            oGame = tGame.Object;
                            break;
                        end

                    end

                end

            elseif (zName == "Game") then
                _oActiveGame = vGame;

            else
                error("TODO: BAD THINGS HERE WRONG TYPE");

            end

            if not (oGame) then
                error("TODO: BAD THINGS HERE..no game object found");
            end

            _oActiveGame = oGame;
        end
    },
    {--PRIVATE
        Env__AUTOR_             = null,
        CFG__AUTOR_             = null,
        CardSets                = {},
        IncludePlugins__AUTOA_  = false,
        Name__AUTOA_            = '',
        Path__AUTOR_            = null,
        UUID__AUTOR_            = null,
    },
    {--PROTECTED

    },
    {--PUBLIC
        Game = function(this, cdat, pFolder)
            local pri = cdat.pri;

            --validate the input string and ensure it leads to a valid directory
            if not (rawtype(pFolder) == "string" and Folder.DoesExist(pFolder)) then
                error("Invalid game: Game path must lead to an existing directory.", 3);
            end

            --set the game's folder
            pri.Path = pFolder;

            --update my info
            ValidateAndUpdateGame(this, cdat);
        end,
        GetAllCardSets = function(this, cdat)
            local pri = cdat.pri;
            local tRet = {};

            for sUUID, tCardSet in pairs(pri.CardSets) do
                tRet[#tRet + 1] = tCardSet.Object;
            end

            table.sort(tRet, SortByName);

            return tRet;
        end,
        GetCardSet = function(this, cdat, sUUID)
            local pri = cdat.pri;
            local vRet;

            if not (rawtype(sUUID) == "string") then
                error("GetCardSet: Argument 1 must be of type string. Got "..rawtype(sUUID)..'.');
            end

            for sCardSetUUID, tCardSet in pairs(pri.CardSets) do

                if (sCardSetUUID:lower() == sUUID:lower()) then
                    vRet = tCardSet.Object;
                    break;
                end

            end

            return vRet;
        end,
        GetCardSetByName = function(this, cdat, sName)
            local pri = cdat.pri;
            local vRet;

            if not (rawtype(sName) == "string") then
                error("GetCardSetByName: Argument 1 must be of type string. Got "..rawtype(sName)..'.');
            end

            for sUUID, tCardSet in pairs(pri.CardSets) do

                if (sName == tCardSet.Name) then
                    vRet = tCardSet.Object;
                    break;
                end

            end

            return vRet;
        end,
        GetCardSetNames = function(this, cdat)
            local pri = cdat.pri;
            local tRet = {};

            for sUUID, tCardSet in pairs(pri.CardSets) do
                tRet[#tRet + 1] = tCardSet.Name;
            end

            table.sort(tRet, SortByName);

            return tRet;
        end,
        NewCardSet = function(this, cdat)

        end,
        --dates game and all game's card sets
        Update = ValidateAndUpdateGame,
    },
    nil,   --extending class
    true,  --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
