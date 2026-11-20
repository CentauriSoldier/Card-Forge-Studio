--[[!
@fqxn CardForgeEngine.TestSuite.KeyBindingChecks
@desc Verifies the effective shortcut profile using isolated INI text.
!]]
local _wx          = require("wx");
local _KeyBindings = require("Scripts.Input.KeyBindings");
local KeyBindingChecks = {};

--[[!
@fqxn CardForgeEngine.TestSuite.KeyBindingChecks.keyEvent
@desc Supplies the event fields needed by the shortcut resolver.
!]]
local function keyEvent(nKey, bCtrl, bShift)
    return {
        GetKeyCode = function() return nKey; end,
        ControlDown = function() return bCtrl == true; end,
        ShiftDown = function() return bShift == true; end,
        AltDown = function() return false; end,
        MetaDown = function() return false; end,
    };
end

--[[!
@fqxn CardForgeEngine.TestSuite.KeyBindingChecks.run
@desc Checks defaults, modifiers, disabling, conflict fallback and diagnostics.
@ret string Summary of covered behavior.
!]]
function KeyBindingChecks.run()
    local Defaults, tIssues = _KeyBindings.fromIni();
    assert(#tIssues == 0 and Defaults.resolve("GameRoom", keyEvent(_wx.WXK_HOME)) == "TopView");
    assert(Defaults.resolve("GameRoom", keyEvent(_wx.WXK_LEFT, false, true)) == "PanLeft");
    assert(Defaults.resolve("GameRoom", keyEvent(43.0)) == "ZoomIn", "Numeric keycodes must match across wx builds.");

    local Custom, tCustomIssues = _KeyBindings.fromIni(
        "[GameRoom]\nTopView=Ctrl+T\nPanUp=None\nZoomOut=InvalidKey\n");
    assert(#tCustomIssues == 1 and Custom.resolve("GameRoom", keyEvent(116, true)) == "TopView");
    assert(not Custom.resolve("GameRoom", keyEvent(116)), "A binding must match its modifiers exactly.");
    assert(not Custom.resolve("GameRoom", keyEvent(_wx.WXK_HOME)), "A replacement removes the former shortcut.");
    assert(not Custom.resolve("GameRoom", keyEvent(_wx.WXK_UP, false, true)), "None disables the action.");
    assert(Custom.resolve("GameRoom", keyEvent(45)) == "ZoomOut", "Invalid entries fall back independently.");

    local Collision, tCollisionIssues = _KeyBindings.fromIni("[GameRoom]\nTopView=Left\n");
    assert(#tCollisionIssues == 1 and Collision.resolve("GameRoom", keyEvent(_wx.WXK_HOME)) == "TopView");
    assert(Collision.resolve("GameRoom", keyEvent(_wx.WXK_LEFT)) == "OrbitLeft", "An override must not steal a default.");

    local Swapped, tSwapIssues = _KeyBindings.fromIni("[GameRoom]\nTopView=Left\nOrbitLeft=Home\n");
    assert(#tSwapIssues == 0 and Swapped.resolve("GameRoom", keyEvent(_wx.WXK_LEFT)) == "TopView");
    assert(Swapped.resolve("GameRoom", keyEvent(_wx.WXK_HOME)) == "OrbitLeft", "Compatible overrides apply together.");

    return "Default shortcuts, exact modifiers, replacement, unbinding, and conflict fallback.";
end

return KeyBindingChecks;
