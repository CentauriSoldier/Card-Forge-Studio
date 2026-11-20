local _pRoot = assert(arg[1], "Supply the Card Forge Engine installation root.");
package.path = _pRoot.."/?.lua;".._pRoot.."/?/init.lua;"
    .._pRoot.."/../Scripts/Plugins/?.lua;".._pRoot.."/../Scripts/Plugins/?/init.lua;".._pRoot.."/Scripts/Plugins/?.lua;".._pRoot.."/Scripts/Plugins/?/init.lua";
require("LuaEx.init");
require("cog.load")();
print("PASS: "..require("Scripts.Test Suite.Zones").run());