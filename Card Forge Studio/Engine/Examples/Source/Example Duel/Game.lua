--[[!
@fqxn Example.Game
@desc Local duel rules built from CFE cards, exclusive zones and named operations.
    No renderer dependency. The computer is an ordinary player using the same API.
!]]
local Game = {};

--[[!
@fqxn Example.Game.create
@desc Starts a duel using card and deck modules from the supplied content.
@param string|table vContent Development directory or bundled content provider.
@param function|nil fRandom Optional random number generator for tests.
@ret table Duel rule interface.
!]]
function Game.create(vContent, fRandom)
    local tDefinitions, tDecks;

    -- Developer tests can still supply their editable source directory.
    if (type(vContent) == "string") then
        tDefinitions = assert(loadfile(vContent.."/Cards.lua", "t"))();
        tDecks = assert(loadfile(vContent.."/Decks.lua", "t"))();
    else
        tDefinitions = vContent.load("Cards.lua");
        tDecks = vContent.load("Decks.lua");
    end
    local tByKey = {};
    for _, tDefinition in ipairs(tDefinitions) do tByKey[tDefinition.Key] = tDefinition; end;
    local oGame = CardForgeEngine.Game();
    local oStack = oGame.createStack("actions");
    local tPlayers, tDefinitionsByID = {}, {};
    local nActive, nTurn, nWinner = 1, 1, 0;
    local tEvents = {};
    local Duel = {};

    local function fDescribe(tCard)
        local tParts = {tCard.Cost.." energy"};
        if (tCard.Damage) then tParts[#tParts + 1] = "Deal "..tCard.Damage.." damage"; end
        if (tCard.Shield) then tParts[#tParts + 1] = "Gain "..tCard.Shield.." shield"; end
        if (tCard.Energy) then tParts[#tParts + 1] = "Gain "..tCard.Energy.." energy"; end
        if (tCard.Draw) then tParts[#tParts + 1] = "Draw "..tCard.Draw; end
        return table.concat(tParts, " | ");
    end
    local function fEvent(tEvent)
        tEvents[#tEvents + 1] = tEvent;
        if (#tEvents > 100) then table.remove(tEvents, 1); end
    end
    local function fDraw(nPlayer)
        local tPlayer = tPlayers[nPlayer];
        if (#tPlayer.Hand >= tPlayer.Hand.getCapacity()) then return false; end
        if (tPlayer.Deck.isEmpty()) then
            for _, other in tPlayer.Discard.eachCard() do
                oGame.moveCard(other.getInstanceID(), tPlayer.Deck.getID());
            end
            oGame.shuffleZone(tPlayer.Deck.getID(), fRandom);
        end
        local other = tPlayer.Deck.getCard("Top");
        if (not other) then return false; end
        local sID = other.getInstanceID();
        oGame.moveCard(sID, tPlayer.Hand.getID());
        fEvent({Kind = "Draw", Player = nPlayer, CardID = sID});
        return true;
    end
    for nPlayer = 1, 2 do
        local tPlayer = {Health = 30, Shield = 0, Energy = 3,
            Deck = CardForgeEngine.Deck(), Hand = CardForgeEngine.Hand(nil, {Capacity = 5}),
            Discard = CardForgeEngine.Discard(), Play = CardForgeEngine.Zone(nil, {Name = "Played"})};
        tPlayers[nPlayer] = tPlayer;
        for _, sZone in ipairs({"Deck", "Hand", "Discard", "Play"}) do oGame.addZone(tPlayer[sZone]); end
        for _, sKey in ipairs(tDecks.Starter) do
            local tDefinition = assert(tByKey[sKey], "Unknown deck card: "..sKey);
            local other = CardForgeEngine.Card(nil, tDefinition.Name, fDescribe(tDefinition));
            tDefinitionsByID[other.getInstanceID()] = tDefinition;
            oGame.addCard(other, tPlayer.Deck.getID());
        end
        oGame.shuffleZone(tPlayer.Deck.getID(), fRandom);
        for nIndex = 1, 5 do fDraw(nPlayer); end
    end

    function Duel.getSnapshot()
        local tResult = {Active = nActive, Turn = nTurn, Winner = nWinner, Players = {}};
        for nPlayer, tPlayer in ipairs(tPlayers) do
            local tCopy = {Health = tPlayer.Health, Shield = tPlayer.Shield, Energy = tPlayer.Energy,
                DeckCount = #tPlayer.Deck, DiscardCount = #tPlayer.Discard, Hand = {}, Played = {}};
            for _, sZone in ipairs({"Hand", "Play"}) do
                local tList = sZone == "Hand" and tCopy.Hand or tCopy.Played;
                for _, other in tPlayer[sZone].eachCard() do
                    local tDefinition = tDefinitionsByID[other.getInstanceID()];
                    tList[#tList + 1] = {ID = other.getInstanceID(), Key = tDefinition.Key,
                        Name = tDefinition.Name, Kind = tDefinition.Kind, Cost = tDefinition.Cost,
                        Text = other.getDescription()};
                end
            end
            tResult.Players[nPlayer] = tCopy;
        end
        return tResult;
    end
    function Duel.getLocation(sID) return oGame.getCardLocation(sID); end
    function Duel.takeEvents()
        local tResult = tEvents; tEvents = {}; return tResult;
    end
    function Duel.canPlay(sID)
        if (nWinner ~= 0) then return false; end
        local tDefinition = tDefinitionsByID[sID];
        local tPlayer = tPlayers[nActive];
        return tDefinition ~= nil and tPlayer.Hand.indexOf(sID) ~= nil and tDefinition.Cost <= tPlayer.Energy;
    end
    function Duel.play(sID)
        if (not Duel.canPlay(sID)) then return false; end
        local nPlayer, tPlayer, tEnemy = nActive, tPlayers[nActive], tPlayers[3 - nActive];
        local tDefinition = tDefinitionsByID[sID];
        oStack.push(CardForgeEngine.Operation(tDefinition.Name, function()
            tPlayer.Energy = tPlayer.Energy - tDefinition.Cost + (tDefinition.Energy or 0);
            tPlayer.Shield = tPlayer.Shield + (tDefinition.Shield or 0);
            local nBlocked = math.min(tEnemy.Shield, tDefinition.Damage or 0);
            tEnemy.Shield = tEnemy.Shield - nBlocked;
            tEnemy.Health = math.max(0, tEnemy.Health - ((tDefinition.Damage or 0) - nBlocked));
            oGame.moveCard(sID, tPlayer.Play.getID());
            fEvent({Kind = "Play", Player = nPlayer, CardID = sID, Key = tDefinition.Key,
                Name = tDefinition.Name, Text = fDescribe(tDefinition), Type = tDefinition.Kind});
            if (tEnemy.Health == 0) then nWinner = nPlayer; end
            if (nWinner == 0) then
                for nIndex = 1, tDefinition.Draw or 0 do fDraw(nPlayer); end
            end
        end, {{CardID = sID, Check = function() return Duel.canPlay(sID); end}}));
        local tResult = oGame.resolveNext("actions");
        assert(tResult.Status == "Resolved", tResult.Reason or "Demo action failed.");
        return true;
    end
    function Duel.endTurn()
        if (nWinner ~= 0) then return false; end
        local tPlayer = tPlayers[nActive];
        for _, sZone in ipairs({"Hand", "Play"}) do
            for _, other in tPlayer[sZone].eachCard() do
                local sID = other.getInstanceID();
                oGame.moveCard(sID, tPlayer.Discard.getID());
                fEvent({Kind = "Discard", Player = nActive, CardID = sID});
            end
        end
        nActive, nTurn = 3 - nActive, nTurn + 1;
        tPlayer = tPlayers[nActive];
        tPlayer.Shield, tPlayer.Energy = 0, 3;
        while (#tPlayer.Hand < 5 and fDraw(nActive)) do end
        fEvent({Kind = "Turn", Player = nActive});
        return true;
    end
    function Duel.stepComputer()
        if (nActive ~= 2 or nWinner ~= 0) then return false; end
        -- Energy first, then damage, then shields; ties retain hand order.
        local sBestID, nBest = nil, -math.huge;
        for _, other in tPlayers[2].Hand.eachCard() do
            local sID = other.getInstanceID();
            if (Duel.canPlay(sID)) then
                local tCard = tDefinitionsByID[sID];
                local nScore = (tCard.Energy or 0) * 10 + (tCard.Damage or 0) * 2 + (tCard.Shield or 0);
                if (nScore > nBest) then sBestID, nBest = sID, nScore; end
            end
        end
        if (sBestID) then return Duel.play(sBestID); end
        return Duel.endTurn();
    end
    function Duel.audit()
        local tSeen, nCount = {}, 0;
        for _, tPlayer in ipairs(tPlayers) do
            assert(#tPlayer.Hand <= 5 and tPlayer.Health >= 0 and tPlayer.Shield >= 0 and tPlayer.Energy >= 0);
            for _, sZone in ipairs({"Deck", "Hand", "Discard", "Play"}) do
                for nIndex, other in tPlayer[sZone].eachCard() do
                    local sID = other.getInstanceID(); local tLocation = oGame.getCardLocation(sID);
                    assert(not tSeen[sID] and tLocation.ZoneID == tPlayer[sZone].getID() and tLocation.Index == nIndex);
                    tSeen[sID] = true; nCount = nCount + 1;
                end
            end
        end
        assert(nCount == 40 and #oGame == 40);
        return true;
    end
    return Duel;
end

return Game;