--[[!
@fqxn CardForgeEngine.TestSuite.Runner
@desc Runs built-in tests in the application's initialized Lua runtime.
!]]
local _Framework    = require("Scripts.Test Suite.Framework");
local _RoomGeometry = require("Scripts.Test Suite.RoomGeometry");
local _KeyBindingChecks = require("Scripts.Test Suite.KeyBindingChecks");
local _Zones = require("Scripts.Test Suite.Zones");
local Runner = {};

--[[!
@fqxn CardForgeEngine.TestSuite.Runner.run
@desc Runs each built-in check group and captures failures with a Lua traceback.
@ret boolean bPassed Whether every test group passed.
@ret string sReport The result of each test group.
!]]
function Runner.run()
    local tGroups = {
        {Name = "Engine framework", Run = _Framework.run},
        {Name = "Zones and movement", Run = _Zones.run},
        {Name = "Game room geometry", Run = _RoomGeometry.run},
        {Name = "Keyboard shortcuts", Run = _KeyBindingChecks.run},
    };
    local tReports = {};
    local bPassed = true;

    -- Run all groups even if one fails so the result covers the entire suite.
    for _, tGroup in ipairs(tGroups) do
        local bOK, sResult = xpcall(tGroup.Run, debug.traceback);
        bPassed = bPassed and bOK;
        tReports[#tReports + 1] = (bOK and "PASS" or "FAIL").." | "..tGroup.Name.."\n"..sResult;
    end

    return bPassed, table.concat(tReports, "\n\n");
end

return Runner;
