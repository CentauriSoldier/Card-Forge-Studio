--[[!
@fqxn CardForgeEngine.TestSuite.Framework
@desc In-memory regression checks for CoG and the engine's first resolution API.
!]]
local Framework = {};

--[[!
@fqxn CardForgeEngine.TestSuite.Framework.run
@desc Verifies the initialized engine with a fresh game on every run.
@ret string sSummary Covered behavior after all assertions pass.
!]]
function Framework.run()
    local oGame  = CardForgeEngine.Game();
    local oCard  = CardForgeEngine.Card("00000000-0000-0000-0000-000000000001", "Test card");
    local oOther = CardForgeEngine.Card("00000000-0000-0000-0000-000000000002", "Other card");
    local oZone = CardForgeEngine.Zone();
    oGame.addZone(oZone);
    oGame.addCard(oCard, oZone.getID()).addCard(oOther, oZone.getID());
    local oMain  = oGame.createStack("main");
    local oReply = oGame.createStack("reply");
    local tOrder = {};

    assert(class.isa(oCard, "CoG.BaseCard"));
    assert(class.getparentname("CardForgeEngine.Stack") == "LuaEx.Classes.Stack");
    assert(CoG.RNG.binary(0) == 0 and CoG.RNG.binary(1) == 1);
    assert(not pcall(oMain.push, function() end), "Bare callbacks must not bypass validation.");
    assert(not pcall(oMain.reverse), "Resolution stacks cannot reverse.");
    assert(not pcall(oGame.createStack, "main"), "Stack names must be unique.");
    assert(not pcall(oGame.addCard, CardForgeEngine.Card("00000000-0000-0000-0000-000000000001"), oZone.getID()), "IDs cannot be reassigned.");

    oMain.push(CardForgeEngine.Operation("first", function()
        tOrder[#tOrder + 1] = "first";
    end));
    oMain.push(CardForgeEngine.Operation("second", function()
        tOrder[#tOrder + 1] = "second";
    end));
    oReply.push(CardForgeEngine.Operation("reply", function()
        tOrder[#tOrder + 1] = "reply";
    end));
    assert(oGame.resolveNext("main").Status == "Resolved");
    assert(oReply.size() == 1, "Resolving one stack must leave another alone.");
    assert(oGame.resolveNext("reply").Status == "Resolved");
    assert(oGame.resolveNext("main").Status == "Resolved");
    assert(table.concat(tOrder, ",") == "second,reply,first", "Stacks must resolve LIFO by explicit selection.");
    assert(oGame.resolveNext("main").Status == "Empty");

    local bRan = false;
    local oMissing = CardForgeEngine.Operation("missing", function()
        bRan = true;
    end, {{CardID = "00000000-0000-0000-0000-000000000001"}});
    oMain.push(oMissing);
    oGame.removeCard("00000000-0000-0000-0000-000000000001");
    assert(oGame.resolveNext("main").Code == "CardMissing" and not bRan);
    oGame.addCard(oCard, oZone.getID());

    local tRequirement = {{CardID = "00000000-0000-0000-0000-000000000001", Check = function(other)
        return other.isFaceUp(), "Card must be face up.";
    end}};
    local oChecked = CardForgeEngine.Operation("condition", function()
        bRan = true;
    end, tRequirement);
    -- Editing the caller's records must not silently remove registered rules.
    tRequirement[1].Check = nil;
    oMain.push(oChecked);
    local tRejected = oGame.resolveNext("main");
    assert(tRejected.Status == "Skipped" and tRejected.Code == "ConditionRejected" and not bRan);

    local oDelayed = CardForgeEngine.Operation("current state", function(other, tCards)
        assert(other == oGame and tCards["00000000-0000-0000-0000-000000000001"] == oCard);
        bRan = true;
    end, {{CardID = "00000000-0000-0000-0000-000000000001", Check = function(other) return other.isFaceUp(); end}});
    oMain.push(oDelayed);
    oCard.reveal();
    assert(oGame.resolveNext("main").Status == "Resolved" and bRan);

    oMain.push(CardForgeEngine.Operation("condition error", function() error("Must not run."); end,
        {{CardID = "00000000-0000-0000-0000-000000000001", Check = function() error("Predicate failed."); end}}));
    assert(oGame.resolveNext("main").Code == "ConditionError");
    oMain.push(CardForgeEngine.Operation("callback error", function() error("Callback failed."); end));
    assert(oGame.resolveNext("main").Code == "CallbackError");

    oMain.push(CardForgeEngine.Operation("changed registry", function() error("Must not run."); end,
        {{CardID = "00000000-0000-0000-0000-000000000001", Check = function()
            oGame.removeCard("00000000-0000-0000-0000-000000000001");
            return true;
        end}}));
    assert(oGame.resolveNext("main").Code == "CardChanged");
    oGame.addCard(oCard, oZone.getID());

    oMain.push(CardForgeEngine.Operation("reentrant", function()
        oGame.resolveNext("reply");
    end));
    assert(oGame.resolveNext("main").Code == "CallbackError");
    oMain.push(CardForgeEngine.Operation("after error", function() end));
    assert(oGame.resolveNext("main").Status == "Resolved", "Resolution lock must recover after errors.");

    local oDirect = CardForgeEngine.Operation("direct", function() error("Must not run."); end);
    assert(not pcall(oDirect.resolve, oGame), "User code cannot resolve outside a stack dispatch.");
    oMain.push(oDelayed);
    assert(oGame.resolveNext("main").Code == "AlreadyResolved", "Resolved Operations cannot execute twice.");
    local tResults = oGame.getResults();
    assert(#tResults > 0);
    tResults[1].Status = "changed";
    assert(oGame.getResults()[1].Status ~= "changed", "History must be copied.");

    -- Bounded diagnostics do not grow without limit during a long-running game.
    for nIndex = 1, 140 do
        oMain.push(CardForgeEngine.Operation("bounded", function() end));
        assert(oGame.resolveNext("main").Status == "Resolved");
    end
    assert(#oGame.getResults() == 128);

    return "CoG cards/RNG, LuaEx inheritance, independent LIFO stacks, validation, stale cards, failure isolation, dispatch enforcement and bounded reports.";
end

return Framework;
