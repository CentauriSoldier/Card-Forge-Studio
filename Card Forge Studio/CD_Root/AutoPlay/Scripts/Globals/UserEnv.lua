--[[
██╗   ██╗███████╗███████╗██████╗ ███████╗███╗   ██╗██╗   ██╗
██║   ██║██╔════╝██╔════╝██╔══██╗██╔════╝████╗  ██║██║   ██║
██║   ██║███████╗█████╗  ██████╔╝█████╗  ██╔██╗ ██║██║   ██║
██║   ██║╚════██║██╔══╝  ██╔══██╗██╔══╝  ██║╚██╗██║╚██╗ ██╔╝
╚██████╔╝███████║███████╗██║  ██║███████╗██║ ╚████║ ╚████╔╝
 ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝  ╚═══╝

█ █ █▀▄ █   ▄▀▄ ▄▀▄ █▀▄   ▀█▀ █▄█ ██▀   █ █ ▄▀▀ ██▀ █▀▄   ██▀ █▄ █ █ █   ▀█▀ ▄▀▄ ██▄ █   ██▀   █ █▄ █ ▀█▀ ▄▀▄   ▀█▀ █▄█ ██▀   █▀▄ ██▀ █▀▄ ▄▀▄
▀▄█ █▀  █▄▄ ▀▄▀ █▀█ █▄▀    █  █ █ █▄▄   ▀▄█ ▄██ █▄▄ █▀▄   █▄▄ █ ▀█ ▀▄▀    █  █▀█ █▄█ █▄▄ █▄▄   █ █ ▀█  █  ▀▄▀    █  █ █ █▄▄   █▀▄ █▄▄ █▀  ▀▄▀
]]


local tEnv = { --TODO QUESTION do i need to protect this?
   ipairs           = ipairs,
   pairs            = pairs,
   ---
   tonumber         = tonumber,
   tostring         = tostring,
   ---
   type             = rawtype,
   --
   p                = p,
   print            = p,
   ---
   serialize        = serialize,
   deserialize      = deserialize,
   --
   select           = select,
   --Forge            = tForgeDecoy,
   --ProcSys          = tProcSysDecoy,
   Import           = Import,
   ---
   --User             = {}, --from Init
};

-- decoy -> real backing table map (weak keys so nothing is kept alive)
local tEnvBacking = setmetatable({}, { __mode = "k" })

local function InjectEnv(sName, tActual)

    if not (rawtype(sName) == "string" and not sName:isempty()) then
        error("InjectEnv: sName must be non-empty string. Got " .. rawtype(sName) .. ".", 2);
    end

    if (rawtype(tActual) ~= "table") then
        error("InjectEnv: tActual must be table. Got " .. rawtype(tActual) .. ".", 2);
    end

    local tDecoy = {};

    -- map decoy -> actual (for command listing)
    tEnvBacking[tDecoy] = tActual;

    -- create meta
    local tMeta = {
        __index = tActual,
        __newindex = function()
            error("Attempt to write to read-only '" .. sName .. "'.", 2);
        end,
        --__metatable = false,
    }

    -- apply read-only decoy metatable
    setmetatable(tDecoy, tMeta);

    -- 3) Inject into env
    tEnv[sName] = tDecoy;
    return tDecoy, tMeta;
end


--[[
██████╗  █████╗ ███████╗███████╗ ██████╗ ██╗  ██╗
██╔══██╗██╔══██╗██╔════╝██╔════╝██╔════╝ ██║  ██║
██████╔╝███████║███████╗█████╗  ███████╗ ███████║
██╔══██╗██╔══██║╚════██║██╔══╝  ██╔═══██╗╚════██║
██████╔╝██║  ██║███████║███████╗╚██████╔╝     ██║
╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝ ╚═════╝      ╚═╝
]]
InjectEnv("base64", {
    dec = base64.dec,
    enc = base64.enc,
});


--[[
██████╗ ██████╗ ██╗      ██████╗ ██████╗
██╔════╝██╔═══██╗██║     ██╔═══██╗██╔══██╗
██║     ██║   ██║██║     ██║   ██║██████╔╝
██║     ██║   ██║██║     ██║   ██║██╔══██╗
╚██████╗╚██████╔╝███████╗╚██████╔╝██║  ██║
╚═════╝ ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═╝
]]
InjectEnv("Color", {
    AlphaBlend         = Color.AlphaBlend,
    AlphaMix           = Color.AlphaMix,
    GetAlpha           = Color.GetAlpha,
    GetBlue            = Color.GetBlue,
    GetGreen           = Color.GetGreen,
    GetRed             = Color.GetRed,
    HexToRGB           = Color.HexToRGB,
    HexToRGBA          = Color.HexToRGBA,
    RGBA               = Color.RGBA,
    RGBAAtOffset       = Color.RGBAAtOffset,
    RGBAGradientColors = Color.RGBAGradientColors,
    RGB                = Color.RGB,
    RGBAtOffset        = Color.RGBAtOffset,
    RGBGradientColors  = Color.RGBGradientColors,
    RGBAToHex          = Color.RGBAToHex,
    RGBToHex           = Color.RGBToHex,
    SetAlpha           = Color.SetAlpha,
    SetBlue            = Color.SetBlue,
    SetGreen           = Color.SetGreen,
    SetRed             = Color.SetRed,
});


--[[
 ██████╗ █████╗ ██████╗ ██████╗
██╔════╝██╔══██╗██╔══██╗██╔══██╗
██║     ███████║██████╔╝██║  ██║
██║     ██╔══██║██╔══██╗██║  ██║
╚██████╗██║  ██║██║  ██║██████╔╝
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝
]]
local tCard = {};
InjectEnv("Card", tCard); ---QUESTION DID PROCSYS REPLACE THIS?


--[[
██████╗███████╗ ██████╗
██╔════╝██╔════╝██╔════╝
██║     █████╗  ██║  ███╗
██║     ██╔══╝  ██║   ██║
╚██████╗██║     ╚██████╔╝
╚═════╝╚═╝      ╚═════╝
]]
--user CFG table. It gets swapped on game load
local _tCFG = {};
local _tCFGDecoy, _tCFGMeta = InjectEnv("CFG", _tCFG);
--[[local _tCFGDecoy    = {};
local _tCFGMeta     = {
    __index = function(t, k)
        return _tCFG[k];
    end,
    __newindex = function(t, k, v)
        error("Attempt to write to read-only user Config table.");
    end
};
setmetatable(_tCFGDecoy, _tCFGMeta);
tEnv.CFG = _tCFGDecoy;]]


--[[
██████╗ ██████╗  █████╗ ██╗    ██╗██╗███╗   ██╗ ██████╗
██╔══██╗██╔══██╗██╔══██╗██║    ██║██║████╗  ██║██╔════╝
██║  ██║██████╔╝███████║██║ █╗ ██║██║██╔██╗ ██║██║  ███╗
██║  ██║██╔══██╗██╔══██║██║███╗██║██║██║╚██╗██║██║   ██║
██████╔╝██║  ██║██║  ██║╚███╔███╔╝██║██║ ╚████║╚██████╔╝
╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝
]]
InjectEnv("Drawing",{
    ClearGradientColors          = Drawing.ClearGradientColors,
    DrawAlphaImage               = Drawing.DrawAlphaImage,
    DrawAngledText               = Drawing.DrawAngledText,
    DrawArc                      = Drawing.DrawArc,
    DrawBoldLine                 = Drawing.DrawBoldLine,
    DrawCircle                   = Drawing.DrawCircle,
    DrawEllipse                  = Drawing.DrawEllipse,
    DrawImage                    = Drawing.DrawImage,
    DrawLine                     = Drawing.DrawLine,
    DrawLineEx                   = Drawing.DrawLineEx,
    DrawPie                      = Drawing.DrawPie,
    DrawPixel                    = Drawing.DrawPixel,
    DrawPolygon                  = Drawing.DrawPolygon,
    DrawRectangle                = Drawing.DrawRectangle,
    DrawRoundedRectangle         = Drawing.DrawRoundedRectangle,
    DrawText                     = Drawing.DrawText,
    FillOutlinedRegion           = Drawing.FillOutlinedRegion,
    GetAvailableCollibFilters    = Drawing.GetAvailableCollibFilters,
    GetPixel                     = Drawing.GetPixel,
    GetTextHeight                = Drawing.GetTextHeight,
    GetTextWidth                 = Drawing.GetTextWidth,
    PrepareCircularGradient      = Drawing.PrepareCircularGradient,
    PrepareConicalGradient       = Drawing.PrepareConicalGradient,
    PrepareEllipticalGradient    = Drawing.PrepareEllipticalGradient,
    PrepareLinearGradient        = Drawing.PrepareLinearGradient,
    PrepareRectangularGradient   = Drawing.PrepareRectangularGradient,
    SetBackColor                 = Drawing.SetBackColor,
    SetCollibFilter              = Drawing.SetCollibFilter,
    SetDrawingFont               = Drawing.SetDrawingFont,
    SetFilteringMode             = Drawing.SetFilteringMode,
    SetFrontColor                = Drawing.SetFrontColor,
    SetGradientColors            = Drawing.SetGradientColors,
    SetSingleGradientColor       = Drawing.SetSingleGradientColor,
});


--[[
███████╗ ██████╗ ██████╗  ██████╗ ███████╗
██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
█████╗  ██║   ██║██████╔╝██║  ███╗█████╗
██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
]]
local tForge        = {};
local tForgeKeys    = {};
InjectEnv("Forge", {
    DrawImage       = Forge.DrawImage,
    DrawText        = Forge.DrawText,
    DrawStyledText  = Forge.DrawStyledText,
});


--[[
██████╗ ███████╗ ██████╗ ███╗   ███╗███████╗████████╗██████╗ ██╗   ██╗
██╔════╝ ██╔════╝██╔═══██╗████╗ ████║██╔════╝╚══██╔══╝██╔══██╗╚██╗ ██╔╝
██║  ███╗█████╗  ██║   ██║██╔████╔██║█████╗     ██║   ██████╔╝ ╚████╔╝
██║   ██║██╔══╝  ██║   ██║██║╚██╔╝██║██╔══╝     ██║   ██╔══██╗  ╚██╔╝
╚██████╔╝███████╗╚██████╔╝██║ ╚═╝ ██║███████╗   ██║   ██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝   ╚═╝
]]
InjectEnv("geometry", {
    fitrect             = math.geometry.fitrect,
    rectcontains        = math.geometry.rectcontains,
    rectcontainsfully   = math.geometry.rectcontainsfully,
});


--[[
███╗   ███╗ █████╗ ████████╗██╗  ██╗
████╗ ████║██╔══██╗╚══██╔══╝██║  ██║
██╔████╔██║███████║   ██║   ███████║
██║╚██╔╝██║██╔══██║   ██║   ██╔══██║
██║ ╚═╝ ██║██║  ██║   ██║   ██║  ██║
╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝
]]
InjectEnv("math", {
    abs                 = math.abs,
    acos                = math.acos,
    asin                = math.asin,
    atan                = math.atan,
    atan2               = math.atan2,        -- present in some Lua builds; safe if it exists
    ceil                = math.ceil,
    clamp               = math.clamp,
    convertbase         = math.convertbase,
    cos                 = math.cos,
    counting            = math.counting,
    deg                 = math.deg,
    drift               = math.drift,
    driftf              = math.driftf,
    e                   = math.e,
    exp                 = math.exp,
    factorial           = math.factorial,
    floor               = math.floor,
    fmod                = math.fmod,
    gcf                 = math.gcf,
    geometry            = tGeometry,
    huge                = math.huge,
    inttorgb            = math.inttorgb,
    iseven              = math.iseven,
    isinteger           = math.isinteger,
    isodd               = math.isodd,
    log                 = math.log,
    max                 = math.max,
    min                 = math.min,
    modf                = math.modf,
    pi                  = math.pi,
    rad                 = math.rad,
    random              = math.random,
    randomf             = math.randomf,
    randomseed          = math.randomseed,
    ratio               = math.ratio,
    rgbtohex            = math.rgbtohex,
    rgbtoint            = math.rgbtoint,
    sin                 = math.sin,
    sqrt                = math.sqrt,
    sum                 = math.sum,
    tan                 = math.tan,
    tointeger           = math.tointeger,
    type                = math.type,
    ult                 = math.ult,
    whole               = math.whole,
});


--[[
██████╗ ██████╗  ██████╗  ██████╗███████╗██╗   ██╗███████╗
██╔══██╗██╔══██╗██╔═══██╗██╔════╝██╔════╝╚██╗ ██╔╝██╔════╝
██████╔╝██████╔╝██║   ██║██║     ███████╗ ╚████╔╝ ███████╗
██╔═══╝ ██╔══██╗██║   ██║██║     ╚════██║  ╚██╔╝  ╚════██║
██║     ██║  ██║╚██████╔╝╚██████╗███████║   ██║   ███████║
╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚══════╝   ╚═╝   ╚══════╝
]]
local tProcSys      = {};
local tProcSysKeys  = {};
InjectEnv("ProcSys", tProcSys); --TODO QUESTION, why is this being injected still?


--[[
██████╗ ███╗   ██╗ ██████╗
██╔══██╗████╗  ██║██╔════╝
██████╔╝██╔██╗ ██║██║  ███╗
██╔══██╗██║╚██╗██║██║   ██║
██║  ██║██║ ╚████║╚██████╔╝
╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝
]]
InjectEnv("RNG", {
    binary          = RNG.binary,
    bipolar         = RNG.bipolar,
    boolean         = RNG.boolean,
    choice          = RNG.choice,
    multiChoice     = RNG.multiChoice,
    percent         = RNG.percent,
    pick            = RNG.pick,
    randomx         = RNG.randomx,
    rollCheck       = RNG.rollCheck,
    rollDice        = RNG.rollDice,
    rollPercentage  = RNG.rollPercentage,
});


--[[
███████╗████████╗██████╗ ██╗███╗   ██╗ ██████╗
██╔════╝╚══██╔══╝██╔══██╗██║████╗  ██║██╔════╝
███████╗   ██║   ██████╔╝██║██╔██╗ ██║██║  ███╗
╚════██║   ██║   ██╔══██╗██║██║╚██╗██║██║   ██║
███████║   ██║   ██║  ██║██║██║ ╚████║╚██████╔╝
╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝
]]
InjectEnv("string", {
    byte                = string.byte,
    cap                 = string.cap,
    capall              = string.capall,
    char                = string.char,
    collapse            = string.collapse,
    find                = string.find,
    format              = string.format,
    gmatch              = string.gmatch,
    gsub                = string.gsub,
    htmltomd            = string.htmltomd,
    isempty             = string.isempty,
    isdatevalid         = string.isdatevalid,
    isfilesafe          = string.isfilesafe,
    iskeyword           = string.iskeyword,
    isnumeric           = string.isnumeric,
    isuuid              = string.isuuid,
    isvariablecompliant = string.isvariablecompliant,
    len                 = string.len,
    lower               = string.lower,
    makefilesafe        = string.makefilesafe,
    match               = string.match,
    rep                 = string.rep,
    reverse             = string.reverse,
    sub                 = string.sub,
    tosid               = string.tosid,
    totable             = string.totable,
    trim                = string.trim,
    trimleft            = string.trimleft,
    trimright           = string.trimright,
    upper               = string.upper,
    uuid                = string.uuid,
});

--[[
████████╗ █████╗ ██████╗ ██╗     ███████╗
╚══██╔══╝██╔══██╗██╔══██╗██║     ██╔════╝
   ██║   ███████║██████╔╝██║     █████╗
   ██║   ██╔══██║██╔══██╗██║     ██╔══╝
   ██║   ██║  ██║██████╔╝███████╗███████╗
   ╚═╝   ╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝
]]
InjectEnv("table", {
    concat  = table.concat,
    insert  = table.insert,
    move    = table.move,
    pack    = table.pack,
    remove  = table.remove,
    sort    = table.sort,
    unpack  = table.unpack,
});


--[[
██╗   ██╗███████╗███████╗██████╗
██║   ██║██╔════╝██╔════╝██╔══██╗
██║   ██║███████╗█████╗  ██████╔╝
██║   ██║╚════██║██╔══╝  ██╔══██╗
╚██████╔╝███████║███████╗██║  ██║
 ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝
]]
local tUser     = {};
local tUserKeys = {}; --tracks keys since user can inject into the base table.
InjectEnv("Session", tUser);

--[[
██╗   ██╗███████╗ ██████╗████████╗ ██████╗ ██████╗ ██████╗ ██████╗  █████╗ ██╗    ██╗██╗███╗   ██╗ ██████╗
██║   ██║██╔════╝██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗██║    ██║██║████╗  ██║██╔════╝
██║   ██║█████╗  ██║        ██║   ██║   ██║██████╔╝██║  ██║██████╔╝███████║██║ █╗ ██║██║██╔██╗ ██║██║  ███╗
╚██╗ ██╔╝██╔══╝  ██║        ██║   ██║   ██║██╔══██╗██║  ██║██╔══██╗██╔══██║██║███╗██║██║██║╚██╗██║██║   ██║
 ╚████╔╝ ███████╗╚██████╗   ██║   ╚██████╔╝██║  ██║██████╔╝██║  ██║██║  ██║╚███╔███╔╝██║██║ ╚████║╚██████╔╝
  ╚═══╝  ╚══════╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝
]]
InjectEnv("VectorDrawing", {
    Arc         = VectorDrawing.Arc,
    FillPath   = VectorDrawing.FillPath,
    LineTo     = VectorDrawing.LineTo,
    MoveTo     = VectorDrawing.MoveTo,
    SetColor   = VectorDrawing.SetColor,
    StrokePath = VectorDrawing.StrokePath,
});


--[[
███████╗██╗   ██╗███╗   ██╗ ██████╗████████╗██╗ ██████╗ ███╗   ██╗███████╗
██╔════╝██║   ██║████╗  ██║██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
█████╗  ██║   ██║██╔██╗ ██║██║        ██║   ██║██║   ██║██╔██╗ ██║███████╗
██╔══╝  ██║   ██║██║╚██╗██║██║        ██║   ██║██║   ██║██║╚██╗██║╚════██║
██║     ╚██████╔╝██║ ╚████║╚██████╗   ██║   ██║╚██████╔╝██║ ╚████║███████║
╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝
]]
local tUserEnv = {
    Get = function()
        return tEnv;
    end,
    -- Returns a numerically-indexed, alphabetically-sorted list of callable commands
    -- exposed by tEnv (including decoy tables that expose their real members via __index = table).
    --
    -- Example output entries:
    --   "math.abs"
    --   "Drawing.DrawLine"
    --   "Color.RGBA"
    --
    GetCommandList = function()
        local tRoot = tEnv -- upvalue

        local tVisited = {}
        local tOutSet  = {}
        local tOut     = {}

        local function AddCommand(sPath)
            if (sPath ~= "" and not tOutSet[sPath]) then
                tOutSet[sPath] = true
                tOut[#tOut + 1] = sPath
            end
        end

        local function EnumKeys(t)
            local tKeys = {}

            for k in pairs(t) do
                if (rawtype(k) == "string") then
                    tKeys[k] = true
                end
            end

            local tBack = tEnvBacking[t]
            if (rawtype(tBack) == "table") then
                for k in pairs(tBack) do
                    if (rawtype(k) == "string") then
                        tKeys[k] = true
                    end
                end
            end

            return tKeys
        end

        local function Walk(t, sPrefix)
            if (tVisited[t]) then return end
            tVisited[t] = true

            for k in pairs(EnumKeys(t)) do
                local v = t[k]
                local sPath = sPrefix and (sPrefix .. "." .. k) or k

                if (rawtype(v) == "function") then
                    AddCommand(sPath)
                elseif (rawtype(v) == "table") then
                    Walk(v, sPath)
                end
            end
        end

        Walk(tRoot, nil)
        table.sort(tOut, function(a, b) return a:lower() < b:lower() end)
        return tOut
    end,
    Refresh = function()
        --TODO FINISH CLEAN THIS OUT!!! On game  load, it should be clean
    end,
    --expects new CFG to have brought in through the user env
    UpdateCFG = function(tInput)
        _tCFG = {};

        if (rawtype(tInput) == "table") then
            _tCFG = tInput--table.shadowreadonly(tInput);
        end

        _tCFGMeta.__index = _tCFG;

    end,
    --[[UpdateForge = function(tInput)

        if (rawtype(tInput) == "table") then

            --delete the existing keys
            for sKey in pairs(tForge) do
                tForge[sKey] = nil;
            end

            --import the new keys
            for sIndex, vItem in pairs(tInput) do

                if (rawtype(sIndex) == "string") then
                    tForge[sIndex] = vItem;
                end

            end

        end

    end,]]
    --[[ForgeUpdateRoot = function(tInput)

        if (rawtype(tInput) == "table") then

            --delete the previous user keys from the env
            for sKey in pairs(tForgeKeys) do
                tEnv[sKey] = nil;
            end

            tForgeKeys = {}; --clear the keys

            --import (and record) the new keys
            for sIndex, vItem in pairs(tInput) do

                if (rawtype(sIndex) == "string") then
                    tForgeKeys[sIndex]    = true;
                    tEnv[sIndex]          = vItem;
                end

            end

        end
    end,
    UpdateProcSysOLD = function(tInput)

        if (rawtype(tInput) == "table") then

            --delete the existing keys
            for sKey in pairs(tProcSys) do
                tProcSys[sKey] = nil;
            end

            --import the new keys
            for sIndex, vItem in pairs(tInput) do

                if (rawtype(sIndex) == "string") then
                    tProcSys[sIndex] = vItem;
                end

            end

        end

    end,]]
    ProcSysUpdateRoot = function(tInput, bPurge) --permits additions/replacement to/of existing keys or a full purge, then new items added

        if (rawtype(tInput) == "table") then

            if (bPurge) then
                --delete the previous user keys from the env
                for sKey in pairs(tProcSysKeys) do
                    tEnv[sKey] = nil;
                end

                tProcSysKeys = {}; --clear the keys
            end

            --import (and record) the new keys
            for sIndex, vItem in pairs(tInput) do

                if (rawtype(sIndex) == "string") then
                    tProcSysKeys[sIndex]    = true;
                    tEnv[sIndex]            = vItem;
                end

            end

        end
    end,
    UserUpdateRoot = function(tInput) --TODO BUG update this to use protected env when able : the user table will get input thourgh forge constructor, then run through the safe env filter, then iterated over and dumped into main env table (error on overwriteing ofc.)
        --local tInput = --GetUserEnv();

        if (rawtype(tInput) == "table") then

            --delete the previous user keys from the env
            for sKey in pairs(tUserKeys) do
                tEnv[sKey] = nil;
            end

            tUserKeys = {}; --clear the user keys

            --import (and record) the new keys
            for sIndex, vItem in pairs(tInput) do

                if (rawtype(sIndex) == "string") then
                    tUserKeys[sIndex]   = true;
                    tEnv[sIndex]        = vItem;
                end

            end

        end
    end,
    --UpdateGame
    --[[UpdateCardSet = function(tInput)

        if (rawtype(tInput) == "table") then

            --delete the existing keys
            for sKey in pairs(tCard) do
                tCard[sKey] = nil;
            end

            --import the new keys
            for sIndex, vItem in pairs(tInput) do

                if (rawtype(sIndex) == "string") then
                    tCard[sIndex] = vItem;
                end

            end

        end

    end,]]
};
local tUserEnvDecoy = {};
local tUserEnvMeta  = {
    __index = function(t, k)
        return tUserEnv[k];
    end,
    __newindex = function(t, k, v)
        error("Attempt to write to read-only 'UserEnv'.", 2);
    end,
    __metatable = false,
};

setmetatable(tUserEnvDecoy, tUserEnvMeta);

return tUserEnvDecoy;
