--[[!
@fqxn CardForgeEngine.init
@desc Application entry point executed by the native launcher. All application
    startup remains Lua; C only locates the runtime and forwards arguments.
!]]
assert(CARD_FORGE_ENGINE_ROOT, "Start Card Forge Engine using the Windows launcher.");
require("Scripts.Bootstrap").run(CARD_FORGE_ENGINE_ROOT, arg or {});
