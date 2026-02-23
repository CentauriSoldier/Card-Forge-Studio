local _tGames       = {}; --keys are uuids, values are {Game = GameObject, Name = NameString}
local _oActiveGame  = false;
local GetCRC        = File.GetCRC
local ReadToString  = TextFile.ReadToString;
local CardSet;
local io            = io;
--TODO with New methods, checkf or existing item first...do not overwrite

--[[
██╗      ██████╗  ██████╗ █████╗ ██╗         ███████╗██╗   ██╗███╗   ██╗ ██████╗████████╗██╗ ██████╗ ███╗   ██╗███████╗
██║     ██╔═══██╗██╔════╝██╔══██╗██║         ██╔════╝██║   ██║████╗  ██║██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
██║     ██║   ██║██║     ███████║██║         █████╗  ██║   ██║██╔██╗ ██║██║        ██║   ██║██║   ██║██╔██╗ ██║███████╗
██║     ██║   ██║██║     ██╔══██║██║         ██╔══╝  ██║   ██║██║╚██╗██║██║        ██║   ██║██║   ██║██║╚██╗██║╚════██║
███████╗╚██████╔╝╚██████╗██║  ██║███████╗    ██║     ╚██████╔╝██║ ╚████║╚██████╗   ██║   ██║╚██████╔╝██║ ╚████║███████║
╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝]]


--[[
    @fqxn   Card Forge Studio.ValidateName
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
    local bRet = false;

    --get the new CRC
    local nCRC = GetCRC(tCall.Path);

    if (nCRC == -1) then --an error occurred if it does == -1
        --TODO ERROR HERE
    end

    --compare it the existing one
    if (nCRC ~= tCall.CRC) then
        --set the newest CRC for this call
        tCall.CRC = nCRC;
        local pCallCode = tCall.Path;

        if not (File.DoesExist(pCallCode)) then
            --TODO FINISH ERROR
            error("NO FILE, OMG! AHHHHH!!!!")
        end

        local sCallCode = ReadToString(pCallCode);
        tCall.Code = sCallCode;
    end

    return bRet;
end


--[[
██████╗ █████╗ ██████╗ ██████╗ ███████╗███████╗████████╗     ██████╗██╗      █████╗ ███████╗███████╗
██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝╚══██╔══╝    ██╔════╝██║     ██╔══██╗██╔════╝██╔════╝
██║     ███████║██████╔╝██║  ██║███████╗█████╗     ██║       ██║     ██║     ███████║███████╗███████╗
██║     ██╔══██║██╔══██╗██║  ██║╚════██║██╔══╝     ██║       ██║     ██║     ██╔══██║╚════██║╚════██║
╚██████╗██║  ██║██║  ██║██████╔╝███████║███████╗   ██║       ╚██████╗███████╗██║  ██║███████║███████║
╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝   ╚═╝        ╚═════╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝]]
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
        Calls               = {}, --holds things like Draw, Proc, etc.
        DataPath__AUTOR_    = null,
        InfoPath__AUTOR_    = null,
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

            local sUUID     = ValidateFolder(pFolder, "CardSet");
            local sName     = ValidateName(pFolder, "CardSet");
            local pData     = pFolder.."\\Data.csv";
            local pInfo     = pFolder.."\\Info.ini";

            --call files
            local pDrawPath = pFolder.."\\Draw.lua";
            local pProcPath = pFolder.."\\Proc.lua";

            local tCheckFiles = {pData, pInfo, pDrawPath, pProcPath};

            for _, pFile in pairs(tCheckFiles) do

                if not (File.DoesExist(pFile)) then
                    error("Invalid CardSet: missing expected file at \""..pFile..".\"");
                end

            end

            --set the game's info
            pri.DataPath    = pData;
            pri.InfoPath    = pInfo;
            pri.Name        = sName;
            pri.Path        = pFolder;
            pri.UUID        = sUUID;

            --setup the game's functions tables
            pri.Calls = {
                Draw = {
                    Code        = ReadToString(pDrawPath),
                    CRC         = GetCRC(pDrawPath),
                    Path        = pDrawPath,
                },
                Proc = {
                    Code        = ReadToString(pProcPath),
                    CRC         = GetCRC(pProcPath),
                    Path        = pProcPath,
                },
            };

        end,
        GetCallCode = function(this, cdat, sCall)
            local pri = cdat.pri;
            local tCalls = pri.Calls;
            --p(sCall, type(tCalls[sCall].Code))
            if (tCalls[sCall] == nil) then
                error("TODO ERROR CAN'T GET CALL - NO CARDSET CALL BY THAT NAME")
            end

            return tCalls[sCall].Code;
        end,
        --updates proc, draw, etc.
        UpdateCallCode = function(this, cdat, sCall)
            local pri = cdat.pri;
            local tCalls = pri.Calls;

            if (tCalls[sCall] == nil) then
                error("TODO ERROR CAN'T UPDATE CALL - NO CARDSET CALL BY THAT NAME")
            end

            return UpdateCardSetCallCode(sCall, tCalls[sCall]);
        end
    },
    nil,   --extending class
    true,  --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);



--[[
██████╗  █████╗ ███╗   ███╗███████╗     ██████╗██╗      █████╗ ███████╗███████╗
██╔════╝ ██╔══██╗████╗ ████║██╔════╝    ██╔════╝██║     ██╔══██╗██╔════╝██╔════╝
██║  ███╗███████║██╔████╔██║█████╗      ██║     ██║     ███████║███████╗███████╗
██║   ██║██╔══██║██║╚██╔╝██║██╔══╝      ██║     ██║     ██╔══██║╚════██║╚════██║
╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗    ╚██████╗███████╗██║  ██║███████║███████║
╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝     ╚═════╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝]]
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
