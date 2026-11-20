-- Run from Engine/Bin/Windows: & "../../../Bin/lua.exe" "../../Examples/Source/Example Duel/Tests/Game.lua" ../.. "../../Examples/Source/Example Duel"
local _pRoot, _pExample = assert(arg[1]), assert(arg[2]);
package.path = _pRoot.."/?.lua;".._pRoot.."/?/init.lua;".._pRoot.."/../Scripts/Plugins/?.lua;".._pRoot.."/../Scripts/Plugins/?/init.lua;".._pRoot.."/Scripts/Plugins/?.lua;".._pRoot.."/Scripts/Plugins/?/init.lua";
require("LuaEx.init"); require("cog.load")();
local _Game = assert(loadfile(_pExample.."/Game.lua"))();
local _tDefinitions = assert(loadfile(_pExample.."/Cards.lua"))();
assert(#_tDefinitions == 20);
local tKeys = {};
for _, tCard in ipairs(_tDefinitions) do
    assert(not tKeys[tCard.Key] and tCard.Cost >= 0 and tCard.Cost % 1 == 0);
    tKeys[tCard.Key] = true;
end
for nSeed = 1, 12 do
    math.randomseed(nSeed);
    local Duel = _Game.create(_pExample);
    local tState = Duel.getSnapshot();
    assert(#tState.Players[1].Hand == 5 and #tState.Players[2].Hand == 5);
    assert(tState.Players[1].DeckCount == 15 and tState.Players[1].Energy == 3);
    assert(not Duel.play(tState.Players[2].Hand[1].ID));
    assert(not Duel.play("unknown"));
    tState.Players[1].Health = 0;
    assert(Duel.getSnapshot().Players[1].Health == 30, "Snapshots must not expose mutable state.");
    local nActions = 0;
    while (Duel.getSnapshot().Winner == 0 and nActions < 1200) do
        tState = Duel.getSnapshot();
        if (tState.Active == 2) then Duel.stepComputer();
        else
            local sPlayable;
            for _, tCard in ipairs(tState.Players[1].Hand) do
                if (Duel.canPlay(tCard.ID)) then sPlayable = tCard.ID; break; end
            end
            if (sPlayable) then
                local tBefore = Duel.getLocation(sPlayable);
                assert(Duel.play(sPlayable) and not Duel.play(sPlayable));
                assert(Duel.getLocation(sPlayable).ZoneID ~= tBefore.ZoneID);
            else Duel.endTurn(); end
        end
        assert(Duel.audit()); nActions = nActions + 1;
    end
    tState = Duel.getSnapshot();
    assert(tState.Winner ~= 0, "Duel failed to finish for seed "..nSeed);
    assert(not Duel.endTurn() and not Duel.stepComputer());
    print("PASS duel "..nSeed..": winner "..tState.Winner..", "..tState.Turn.." turns, "..nActions.." actions");
end
print("PASS: twenty definitions, legal turns, energy, win/stop, detached snapshots and all forty cards in exactly one zone after every action.");