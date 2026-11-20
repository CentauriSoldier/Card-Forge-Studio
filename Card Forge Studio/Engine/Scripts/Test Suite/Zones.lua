--[[!
@fqxn CardForgeEngine.TestSuite.Zones
@desc In-memory checks for occupied slots, movement, identity, cloning and restoration.
!]]
local Zones = {};

function Zones.run()
    local oGame = CardForgeEngine.Game();
    local oDeck = CardForgeEngine.Deck();
    local oHand = CardForgeEngine.Hand(nil, {Capacity = 2});
    local oDiscard = CardForgeEngine.Discard();
    oGame.addZone(oDeck).addZone(oHand).addZone(oDiscard);
    local oFirst, oSecond, oThird = CardForgeEngine.Card(), CardForgeEngine.Card(), CardForgeEngine.Card();
    local sFirst, sSecond, sThird = oFirst.getInstanceID(), oSecond.getInstanceID(), oThird.getInstanceID();
    assert(string.isuuid(sFirst) and not pcall(CardForgeEngine.Card, "not-a-uuid"));
    assert(not pcall(oGame.addCard, oFirst), "Registration requires a zone.");
    oGame.addCard(oFirst, oDeck.getID()).addCard(oSecond, oDeck.getID()).addCard(oThird, oDeck.getID());
    assert(#oGame == 3 and #oDeck == 3 and oDeck.getCard("Bottom") == oFirst and oDeck.getCard("Top") == oThird);
    assert(oDeck.getCard(2) == oSecond and oDeck.getCard(4) == nil);
    assert(oGame.getCard(sFirst:upper()) == oFirst);
    assert(not pcall(oGame.addCard, oFirst, oHand.getID()));
    assert(not pcall(oGame.addCard, CardForgeEngine.Card(sFirst), oHand.getID()));
    local oOtherGame = CardForgeEngine.Game();
    local oOtherZone = CardForgeEngine.Zone();
    oOtherGame.addZone(oOtherZone);
    assert(not pcall(oOtherGame.addCard, oFirst, oOtherZone.getID()));
    assert(not pcall(oOtherGame.addZone, oDeck));
    assert(not pcall(oDeck.apply, oGame, {}, CoG.BaseDeck(), false));

    local tMove = oGame.moveCard(sSecond, oHand.getID());
    assert(tMove.FromIndex == 2 and tMove.ToIndex == 1 and tMove.CardID == sSecond and tMove.Changed);
    assert(#oDeck == 2 and oDeck.getCard(2) == oThird and #oHand == 1);
    assert(oGame.getCardLocation(sThird).Index == 2);
    oGame.moveCard(sThird, oHand.getID(), "Bottom");
    assert(oHand.getCard(1) == oThird and oHand.getCard(2) == oSecond);
    assert(not pcall(oGame.moveCard, sFirst, oHand.getID()), "Full destination must reject movement.");
    assert(#oDeck == 1 and #oHand == 2 and oGame.getCardLocation(sFirst).ZoneID == oDeck.getID());
    assert(not pcall(oHand.setCapacity, 1));
    oHand.setCapacity(3);
    assert(not pcall(oGame.moveCard, sFirst, oHand.getID(), 5));
    assert(not pcall(oGame.moveCard, sFirst, string.uuid()));
    assert(not pcall(oGame.moveCard, string.uuid(), oHand.getID()));
    oGame.moveCard(sFirst, oHand.getID(), 2);
    assert(oHand.getCard(2) == oFirst);
    oGame.moveCard(sThird, oHand.getID(), 3);
    assert(oHand.getCard(1) == oFirst and oHand.getCard(2) == oSecond and oHand.getCard(3) == oThird);
    assert(not oGame.moveCard(sThird, oHand.getID(), "Top").Changed);
    assert(not pcall(oGame.moveCard, sFirst, oHand.getID(), 4), "Same-zone indices use the post-removal count.");
    local tCards = oHand.getCards(); tCards[1] = nil;
    assert(#oHand == 3 and oHand.getCard(1) == oFirst);
    local nCount = 0;
    for nIndex, other in pairs(oHand) do assert(other == oHand.getCard(nIndex)); nCount = nCount + 1; end
    assert(nCount == 3);

    assert(not pcall(oGame.shuffleZone, oHand.getID(), function() error("Random failure"); end));
    assert(oHand.getCard(1) == oFirst and oHand.getCard(3) == oThird);
    assert(not pcall(oGame.shuffleZone, oHand.getID(), function()
        oGame.moveCard(sFirst, oDiscard.getID()); return 1;
    end));
    assert(#oHand == 3 and #oDiscard == 0);
    local tShuffle = oGame.shuffleZone(oHand.getID(), function() return 1; end);
    assert(#tShuffle.CardIDs == 3);
    for nIndex, other in oHand.eachCard() do assert(oGame.getCardLocation(other.getInstanceID()).Index == nIndex); end

    assert(not oDeck.getLayout().FaceUp and oDiscard.getLayout().FaceUp and oHand.getLayout().Kind == "Fan");
    local tLayout = oHand.getLayout(); tLayout.Kind = "Changed";
    assert(oHand.getLayout().Kind == "Fan");
    oHand.setLayout({Kind = "Overlap"});
    assert(not oFirst.isFaceUp(), "Presentation presets must not mutate card flags.");
    local oCopy = clone(oFirst);
    assert(oCopy.getInstanceID() ~= sFirst and oCopy.getName() == oFirst.getName());
    local oHandCopy = clone(oHand);
    assert(#oHandCopy == 3 and oHandCopy.getID() ~= oHand.getID() and oHandCopy.getGame() == nil);
    assert(oHandCopy.getCard(1).getInstanceID() ~= oHand.getCard(1).getInstanceID());
    assert(oHandCopy.getLayout().Kind == "Overlap" and oHandCopy.getCapacity() == 3);

    local oRow = CardForgeEngine.Row(); oRow.addZone(oDeck).addZone(oHand);
    local oBoard = CardForgeEngine.Playfield(); oBoard.addRow(oRow);
    assert(#oRow == 2 and #oBoard == 1 and not oBoard.isEmpty());
    assert(not pcall(oRow.removeZone, oHand.getID()) and not pcall(oBoard.removeRow, 1));
    assert(not pcall(oRow.addZone, oHand));
    assert(oRow.removeZone(1) == oDeck and oRow.getZone(1) == oHand);
    local oBoardCopy = clone(oBoard);
    assert(oBoardCopy.getID() ~= oBoard.getID() and #oBoardCopy.getRow(1).getZone(1) == 3);
    local tRestored = deserialize(serialize({Game = oGame, Board = oBoard}));
    local oRestored = tRestored.Game;
    local oRestoredHand = oRestored.getZone(oHand.getID());
    assert(#oRestored == 3 and oRestoredHand.getGame() == oRestored);
    assert(tRestored.Board.getRow(1).getZone(1) == oRestoredHand, "Restoration must preserve shared references.");
    assert(oRestored.getCard(sFirst) ~= oFirst and oRestored.getCard(sFirst).getInstanceID() == sFirst);
    oRestored.moveCard(sFirst, oDiscard.getID());
    assert(#oRestoredHand == 2 and #oHand == 3);
    local oGameCopy = clone(oGame);
    assert(#oGameCopy == 3 and oGameCopy.getCard(sFirst) == nil);
    local oStack = oGame.createStack("main");
    oStack.push(CardForgeEngine.Operation("pending", function() end));
    assert(not pcall(clone, oGame), "Pending callback identities cannot be remapped implicitly.");
    oStack.pop();
    assert(clone(oGame).getStack("main").size() == 0);

    assert(not pcall(oGame.removeZone, oHand.getID()));
    for _, other in oHand.eachCard() do oGame.moveCard(other.getInstanceID(), oDiscard.getID()); end
    assert(oHand.isEmpty()); oHand.setCapacity(0);
    assert(not pcall(oGame.addCard, CardForgeEngine.Card(), oHand.getID()));
    assert(oRow.removeZone(1) == oHand and oBoard.removeRow(1) == oRow);
    assert(oGame.removeZone(oHand.getID()) == oHand and oHand.getGame() == nil);
    assert(oGame.removeCard(sFirst) == oFirst and oGame.getCardLocation(sFirst) == nil);
    assert(not pcall(oGame.addCard, CardForgeEngine.Card(sFirst), oDeck.getID()));
    oGame.addCard(oFirst, oDeck.getID());

    -- Shared CoG ordering: insertion/default draw at top; bottom remains index one.
    local oStorage = CoG.BaseDeck({oFirst, oSecond});
    oStorage.addCard(oThird);
    assert(oStorage.peek() == oThird and oStorage.peek(1) == oFirst);
    local tDrawn = oStorage.drawMany(2);
    assert(tDrawn[1] == oThird and tDrawn[2] == oSecond and #oStorage == 1);
    oStorage.addCard(oSecond, false);
    assert(oStorage.draw(1) == oSecond and oStorage.draw() == oFirst and oStorage.draw() == nil);
    assert(oStorage.peek() == nil);
    return "UUIDs, exclusive zones, dense slots, move validation, capacity, CoG ordering, shuffle recovery, layouts, rows/playfields, clone identities and shared snapshot restoration.";
end

return Zones;