--[[!
@fqxn CardForgeEngine.Dev.BuildExampleCFA
@desc Builds the Example Duel from its editable source into a new publishable
    game folder. Run from the Engine folder with Studio's lua.exe.
!]]
local _pEngine = ".";
local _pSource = "./Examples/Source/Example Duel";
local _pLibrary = arg[1] or "./Examples/Games";
local _sTitle = "Example Duel";
local _sGameUUID = "04cc1a33-f2c1-4fa7-985a-3bde6ff12f08";
local _sSetUUID = "75c287a3-f3ef-4557-b252-eadbaf5935d8";

package.path = _pEngine.."/?.lua;../Scripts/Plugins/?.lua;"..package.path;

require("LuaEx.init");
package.path = package.path..";../Scripts/?.lua";
local _Reader = require("CFA.Reader");
local _Writer = require("CFA.Writer");

--[[!
@fqxn CardForgeEngine.Dev.BuildExampleCFA.readBytes
@desc Loads a source file as binary data without evaluating its contents.
!]]
local function readBytes(pFile)
    local hFile <close> = assert(io.open(pFile, "rb"));
    return assert(hFile:read("a"));
end

--[[!
@fqxn CardForgeEngine.Dev.BuildExampleCFA.collect
@desc Collects source card artwork with stable ordering and virtual paths.
!]]
local function collect(tFiles, pFolder)
    local tPaths = assert(io.listfiles(_pSource.."/"..pFolder, false, nil, "png"));
    table.sort(tPaths);
    for _, pFile in ipairs(tPaths) do
        local sName = pFile:match("[^/\\]+$");
        tFiles[#tFiles + 1] = {Path = pFolder.."/"..sName, Bytes = readBytes(pFile)};
    end
end

--[[!
@fqxn CardForgeEngine.Dev.BuildExampleCFA.build
@desc Stages both archives and the deck file and publishes one complete directory.
!]]
local function build()
    assert(io.isdir(_pLibrary), "Create the destination library before running the builder.");
    local pDestination = _pLibrary.."/".._sTitle;
    assert(not io.isdir(pDestination), "The example already exists. Select a fresh output library to rebuild.");
    local pTemp = os.tmpname();
    os.remove(pTemp);
    local sStageID = assert(pTemp:match("([^/\\]+)$"));
    local pStage = _pLibrary.."/.stage-"..sStageID;
    assert(not io.isdir(pStage) and io.mkdir(pStage), "Unable to stage Example Duel.");

    local pSets = pStage.."/CardSets";
    local pGameArchive = pStage.."/".._sGameUUID..".cfa";
    local pSetArchive = pSets.."/".._sSetUUID..".cfa";
    local pDecks = pStage.."/Decks.lua";

    local bOK, vFailure = pcall(function()
        assert(io.mkdir(pSets), "Unable to stage the set folder.");

        local tGame = {
            {Path = "Game.lua", Bytes = readBytes(_pSource.."/Game.lua")},
            {Path = "Page.lua", Bytes = readBytes(_pSource.."/Page.lua")},
        };
        local tSet = {{Path = "Cards.lua", Bytes = readBytes(_pSource.."/Cards.lua")}};
        collect(tSet, "Images/Cards/Fronts");
        collect(tSet, "Images/Cards/Backs");

        assert(_Writer.write(pGameArchive, {Kind = "game", UUID = _sGameUUID, Title = _sTitle}, tGame));
        assert(_Writer.write(pSetArchive, {Kind = "set", UUID = _sSetUUID, Title = "Starter"}, tSet));

        local hDecks = assert(io.open(pDecks, "wb"));
        local bWritten = hDecks:write(readBytes(_pSource.."/Decks.lua"));
        local bClosed = hDecks:close();
        assert(bWritten and bClosed, "Unable to stage the deck definitions.");

        -- Compare each verified archive entry to its editable source.
        for _, tPackage in ipairs({{pGameArchive, tGame}, {pSetArchive, tSet}}) do
            local Reader = assert(_Reader.open(tPackage[1]));
            local bVerified, sError = pcall(function()
                for _, tFile in ipairs(tPackage[2]) do
                    assert(Reader.read(tFile.Path) == tFile.Bytes, "Archive entry differs from source.");
                end
            end);
            Reader.close();
            assert(bVerified, sError);
        end

        assert(os.rename(pStage, pDestination), "Unable to publish the example without replacement.");
    end);

    if (not bOK) then
        for _, pFile in ipairs({pDecks, pSetArchive, pGameArchive}) do os.remove(pFile); end
        for _, pFolder in ipairs({pSets, pStage}) do os.remove(pFolder); end
        error(vFailure, 0);
    end

    print("Built and verified "..pDestination);
end

build();
