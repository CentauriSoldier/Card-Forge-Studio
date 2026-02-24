--[[
██████╗  █████╗ ███████╗███████╗ ██████╗ ██╗  ██╗
██╔══██╗██╔══██╗██╔════╝██╔════╝██╔════╝ ██║  ██║
██████╔╝███████║███████╗█████╗  ███████╗ ███████║
██╔══██╗██╔══██║╚════██║██╔══╝  ██╔═══██╗╚════██║
██████╔╝██║  ██║███████║███████╗╚██████╔╝     ██║
╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝ ╚═════╝      ╚═╝
]]
local tBase64 = {
    dec = base64.dec,
    enc = base64.enc,
};
local base64Decoy = {};

setmetatable(base64Decoy, {
    __index = tBase64,
    __newindex = function()
        error("Attempt to write to read-only 'base64'.", 2);
    end,
    __metatable = false,
});


--[[
██████╗███████╗ ██████╗
██╔════╝██╔════╝██╔════╝
██║     █████╗  ██║  ███╗
██║     ██╔══╝  ██║   ██║
╚██████╗██║     ╚██████╔╝
╚═════╝╚═╝      ╚═════╝
]]
local tCFG       = {};
local tCFGDecoy  = {};

setmetatable(tCFGDecoy, {
    __index = tCFG,
    __newindex = function(t, k, v)
        tCFG[k] = v; -- user writes allowed
    end,
    __metatable = false,
});


--[[
██████╗ ██████╗ ██╗      ██████╗ ██████╗
██╔════╝██╔═══██╗██║     ██╔═══██╗██╔══██╗
██║     ██║   ██║██║     ██║   ██║██████╔╝
██║     ██║   ██║██║     ██║   ██║██╔══██╗
╚██████╗╚██████╔╝███████╗╚██████╔╝██║  ██║
╚═════╝ ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═╝
]]
local tColor = {
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
};
local tColorDecoy = {};

setmetatable(tColorDecoy, {
    __index = tColor,
    __newindex = function()
        error("Attempt to write to read-only 'Color'.", 2);
    end,
    __metatable = false,
});


--[[
██████╗ ██████╗  █████╗ ██╗    ██╗██╗███╗   ██╗ ██████╗
██╔══██╗██╔══██╗██╔══██╗██║    ██║██║████╗  ██║██╔════╝
██║  ██║██████╔╝███████║██║ █╗ ██║██║██╔██╗ ██║██║  ███╗
██║  ██║██╔══██╗██╔══██║██║███╗██║██║██║╚██╗██║██║   ██║
██████╔╝██║  ██║██║  ██║╚███╔███╔╝██║██║ ╚████║╚██████╔╝
╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝
]]
local tDrawing = {
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
};
local tDrawingDecoy = {};

setmetatable(tDrawingDecoy, {
    __index = tDrawing,
    __newindex = function()
        error("Attempt to write to read-only 'Drawing'.", 2);
    end,
    __metatable = false,
});


--[[
███████╗ ██████╗ ██████╗  ██████╗ ███████╗
██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
█████╗  ██║   ██║██████╔╝██║  ███╗█████╗
██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
]]
local tForge = {};
local tForgeDecoy   = {};

setmetatable(tForgeDecoy, {
    __index = tForge,
    __newindex = function()
        error("Attempt to write to read-only 'Forge'.", 2);
    end,
    __metatable = false,
});


--[[
███╗   ███╗ █████╗ ████████╗██╗  ██╗
████╗ ████║██╔══██╗╚══██╔══╝██║  ██║
██╔████╔██║███████║   ██║   ███████║
██║╚██╔╝██║██╔══██║   ██║   ██╔══██║
██║ ╚═╝ ██║██║  ██║   ██║   ██║  ██║
╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝
]]
local tGeometry = {
    fitrect             = math.geometry.fitrect,
    rectcontains        = math.geometry.rectcontains,
    rectcontainsfully   = math.geometry.rectcontainsfully,
};
local tGeometryDecoy = {};

setmetatable(tGeometryDecoy, {
    __index = tGeometry,
    __newindex = function()
        error("Attempt to write to read-only 'math.geometry'.", 2);
    end,
    __metatable = false,
});

local tMath = {
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
};
local tMathDecoy = {};

setmetatable(tMathDecoy, {
    __index = tMath,
    __newindex = function()
        error("Attempt to write to read-only 'math'.", 2);
    end,
    __metatable = false,
});


--[[
██████╗ ██████╗  ██████╗  ██████╗███████╗██╗   ██╗███████╗
██╔══██╗██╔══██╗██╔═══██╗██╔════╝██╔════╝╚██╗ ██╔╝██╔════╝
██████╔╝██████╔╝██║   ██║██║     ███████╗ ╚████╔╝ ███████╗
██╔═══╝ ██╔══██╗██║   ██║██║     ╚════██║  ╚██╔╝  ╚════██║
██║     ██║  ██║╚██████╔╝╚██████╗███████║   ██║   ███████║
╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚══════╝   ╚═╝   ╚══════╝
]]
local tProcSys = {};
local tProcSysDecoy = {};

setmetatable(tProcSysDecoy, {
    __index = tProcSys,
    __newindex = function()
        error("Attempt to write to read-only 'ProcSys'.", 2);
    end,
    __metatable = false,
});


--[[
██████╗ ███╗   ██╗ ██████╗
██╔══██╗████╗  ██║██╔════╝
██████╔╝██╔██╗ ██║██║  ███╗
██╔══██╗██║╚██╗██║██║   ██║
██║  ██║██║ ╚████║╚██████╔╝
╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝
]]
local tRNG = {
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
};
local tRNGDecoy = {};
setmetatable(tRNGDecoy, {
    __index = tRNG,
    __newindex = function()
        error("Attempt to write to read-only 'RNG'.", 2);
    end,
    __metatable = false,
});


--[[
███████╗████████╗██████╗ ██╗███╗   ██╗ ██████╗
██╔════╝╚══██╔══╝██╔══██╗██║████╗  ██║██╔════╝
███████╗   ██║   ██████╔╝██║██╔██╗ ██║██║  ███╗
╚════██║   ██║   ██╔══██╗██║██║╚██╗██║██║   ██║
███████║   ██║   ██║  ██║██║██║ ╚████║╚██████╔╝
╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝
]]
local tString = {
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
};
local tStringDecoy = {};

setmetatable(tStringDecoy, {
    __index = tString,
    __newindex = function()
        error("Attempt to write to read-only 'string'.", 2);
    end,
    __metatable = false,
});


--[[
████████╗ █████╗ ██████╗ ██╗     ███████╗
╚══██╔══╝██╔══██╗██╔══██╗██║     ██╔════╝
   ██║   ███████║██████╔╝██║     █████╗
   ██║   ██╔══██║██╔══██╗██║     ██╔══╝
   ██║   ██║  ██║██████╔╝███████╗███████╗
   ╚═╝   ╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝
]]
local tTable = {
    concat  = table.concat,
    insert  = table.insert,
    move    = table.move,
    pack    = table.pack,
    remove  = table.remove,
    sort    = table.sort,
    unpack  = table.unpack,
};
local tTableDecoy = {};

setmetatable(tTableDecoy, {
    __index = tTable,
    __newindex = function()
        error("Attempt to write to read-only 'table'.", 2);
    end,
    __metatable = false,
});


--[[
██╗   ██╗███████╗███████╗██████╗
██║   ██║██╔════╝██╔════╝██╔══██╗
██║   ██║███████╗█████╗  ██████╔╝
██║   ██║╚════██║██╔══╝  ██╔══██╗
╚██████╔╝███████║███████╗██║  ██║
 ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝
]]
local tUser       = {};
local tUserDecoy  = {};

setmetatable(tUserDecoy, {
    __index = tUser,
    __newindex = function(t, k, v)
        error("Attempt to write to read-only 'User'.", 2);
    end,
    __metatable = false,
});


--[[
██╗   ██╗███████╗ ██████╗████████╗ ██████╗ ██████╗ ██████╗ ██████╗  █████╗ ██╗    ██╗██╗███╗   ██╗ ██████╗
██║   ██║██╔════╝██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗██║    ██║██║████╗  ██║██╔════╝
██║   ██║█████╗  ██║        ██║   ██║   ██║██████╔╝██║  ██║██████╔╝███████║██║ █╗ ██║██║██╔██╗ ██║██║  ███╗
╚██╗ ██╔╝██╔══╝  ██║        ██║   ██║   ██║██╔══██╗██║  ██║██╔══██╗██╔══██║██║███╗██║██║██║╚██╗██║██║   ██║
 ╚████╔╝ ███████╗╚██████╗   ██║   ╚██████╔╝██║  ██║██████╔╝██║  ██║██║  ██║╚███╔███╔╝██║██║ ╚████║╚██████╔╝
  ╚═══╝  ╚══════╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝
]]
local tVectorDrawing = {
    Arc         = VectorDrawing.Arc,
    FillPath   = VectorDrawing.FillPath,
    LineTo     = VectorDrawing.LineTo,
    MoveTo     = VectorDrawing.MoveTo,
    SetColor   = VectorDrawing.SetColor,
    StrokePath = VectorDrawing.StrokePath,
};
local tVectorDrawingDecoy = {};

setmetatable(tVectorDrawingDecoy, {
    __index = tVectorDrawing,
    __newindex = function()
        error("Attempt to write to read-only 'VectorDrawing'.", 2);
    end,
    __metatable = false,
});



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
--envrepo.User = {
local tEnv = { --TODO QUESTION do i need to protect this?
   math             = tMathDecoy,
   string           = tStringDecoy,
   ---
   Color            = tColorDecoy,
   Drawing          = tDrawingDecoy,
   VectorDrawing    = tVectorDrawingDecoy,
   ---
   RNG              = tRNGDecoy,
   ---
   ipairs           = ipairs,
   pairs            = pairs,
   ---
   tonumber         = tonumber,
   tostring         = tostring,
   ---
   type             = rawtype,
   --
   p                = p,
   ---
   serialize        = serialize,
   deserialize      = deserialize,
   --
   Forge            = tForgeDecoy,
   ProcSys          = tProcSysDecoy,
   ---
   CFG              = tCFGDecoy,
   ---
   --User             = {}, --from InitForge
};

--CFG              = {},--TODO REMOVE/REVISE -- MOST LIKELY MOVE TO PROCSYS

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
    --expects new CFG to have brought in through the user env
    UpdateCFG = function(tInput)

        if (rawtype(tInput) == "table") then

            --delete the existing keys
            for sKey in pairs(tCFG) do
                tCFG[sKey] = nil;
            end

            --import the new keys
            for sIndex, vItem in pairs(tInput) do

                if (rawtype(sIndex) == "string") then
                    tCFG[sIndex] = vItem;
                end

            end

        end

    end,
    UpdateForge = function(tInput)

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

    end,
    UpdateProcSys = function(tInput)

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

    end,
    UpdateUser = function() --TODO BUG update this to use prot env when able : the user table will get input thourgh foge constructor, then run through the safe env filter, then iterated over and dumped into main env table (error on overwriteing ofc.)
        local tInput = GetUserEnv();

        if (rawtype(tInput) == "table") then

            --delete the existing keys
            --for sKey in pairs(tEnv) do
                --tUser[sKey] = nil;
            --end

            --import the new keys
            for sIndex, vItem in pairs(tInput) do

                if (rawtype(sIndex) == "string") then                    
                    tEnv[sIndex] = vItem;
                end

            end

        end
    end,
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
