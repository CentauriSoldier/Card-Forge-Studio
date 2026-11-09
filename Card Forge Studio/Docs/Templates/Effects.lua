--[[!
@fqxn Game.Effects
@desc Returns game-defined text effects. Each named entry supplies Padding (integer 0..64) and Shade(tMask, nX, nY), returning red, green, blue, alpha (0..255). Coordinates are zero-based pixels. tMask.Width/Height include padding; FontHeight is the native font line height. Alpha(x,y) samples the original antialiased font mask; Distance(x,y) measures distance inside its edge. Both return zero outside the raster. Use integer sample coordinates. Keep processors deterministic: rendered runs are cached. Names are case-sensitive and may override built-ins. This file runs in the user environment; no wx objects or filesystem access are required. Save changes, then request a preview redraw to reload them.
@ex
--Add inside the returned table, then draw with effect name "Copper":
--Copper = {
--    Padding = 2,
--    Shade = function(tMask, nX, nY)
--        return 184, 115, 51, tMask.Alpha(nX, nY);
--    end,
--},
--Forge.DrawTextEffect("NAME", 412.5, 100, "Example", "Copper", true, true);
!]]
return {};
