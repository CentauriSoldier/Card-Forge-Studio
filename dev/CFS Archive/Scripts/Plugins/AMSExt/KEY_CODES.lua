local next      = next;
local rawtype   = rawtype;
local string    = string;


local tKeys = {
    backspace   = { hex = "08", dec = 8 },
    tab         = { hex = "09", dec = 9 },
    enter       = { hex = "0D", dec = 13 },
    shift       = { hex = "10", dec = 16 },
    ctrl        = { hex = "11", dec = 17 },
    alt         = { hex = "12", dec = 18 },
    pause       = { hex = "13", dec = 19 },
    capslock    = { hex = "14", dec = 20 },
    esc         = { hex = "1B", dec = 27 },
    space       = { hex = "20", dec = 32 },

    pageup      = { hex = "21", dec = 33 },
    pagedown    = { hex = "22", dec = 34 },
    ["end"]     = { hex = "23", dec = 35 },
    home        = { hex = "24", dec = 36 },

    left        = { hex = "25", dec = 37 },
    up          = { hex = "26", dec = 38 },
    right       = { hex = "27", dec = 39 },
    down        = { hex = "28", dec = 40 },

    insert      = { hex = "2D", dec = 45 },
    delete      = { hex = "2E", dec = 46 },

    ["0"] = { hex = "30", dec = 48 },
    ["1"] = { hex = "31", dec = 49 },
    ["2"] = { hex = "32", dec = 50 },
    ["3"] = { hex = "33", dec = 51 },
    ["4"] = { hex = "34", dec = 52 },
    ["5"] = { hex = "35", dec = 53 },
    ["6"] = { hex = "36", dec = 54 },
    ["7"] = { hex = "37", dec = 55 },
    ["8"] = { hex = "38", dec = 56 },
    ["9"] = { hex = "39", dec = 57 },

    a = { hex = "41", dec = 65 },
    b = { hex = "42", dec = 66 },
    c = { hex = "43", dec = 67 },
    d = { hex = "44", dec = 68 },
    e = { hex = "45", dec = 69 },
    f = { hex = "46", dec = 70 },
    g = { hex = "47", dec = 71 },
    h = { hex = "48", dec = 72 },
    i = { hex = "49", dec = 73 },
    j = { hex = "4A", dec = 74 },
    k = { hex = "4B", dec = 75 },
    l = { hex = "4C", dec = 76 },
    m = { hex = "4D", dec = 77 },
    n = { hex = "4E", dec = 78 },
    o = { hex = "4F", dec = 79 },
    p = { hex = "50", dec = 80 },
    q = { hex = "51", dec = 81 },
    r = { hex = "52", dec = 82 },
    s = { hex = "53", dec = 83 },
    t = { hex = "54", dec = 84 },
    u = { hex = "55", dec = 85 },
    v = { hex = "56", dec = 86 },
    w = { hex = "57", dec = 87 },
    x = { hex = "58", dec = 88 },
    y = { hex = "59", dec = 89 },
    z = { hex = "5A", dec = 90 },

    lwin        = { hex = "5B", dec = 91 },
    rwin        = { hex = "5C", dec = 92 },
    app         = { hex = "5D", dec = 93 },

    num0        = { hex = "60", dec = 96 },
    num1        = { hex = "61", dec = 97 },
    num2        = { hex = "62", dec = 98 },
    num3        = { hex = "63", dec = 99 },
    num4        = { hex = "64", dec = 100 },
    num5        = { hex = "65", dec = 101 },
    num6        = { hex = "66", dec = 102 },
    num7        = { hex = "67", dec = 103 },
    num8        = { hex = "68", dec = 104 },
    num9        = { hex = "69", dec = 105 },

    nummul      = { hex = "6A", dec = 106 },
    numadd      = { hex = "6B", dec = 107 },
    numsub      = { hex = "6D", dec = 109 },
    numdot      = { hex = "6E", dec = 110 },
    numdiv      = { hex = "6F", dec = 111 },

    f1  = { hex = "70", dec = 112 },
    f2  = { hex = "71", dec = 113 },
    f3  = { hex = "72", dec = 114 },
    f4  = { hex = "73", dec = 115 },
    f5  = { hex = "74", dec = 116 },
    f6  = { hex = "75", dec = 117 },
    f7  = { hex = "76", dec = 118 },
    f8  = { hex = "77", dec = 119 },
    f9  = { hex = "78", dec = 120 },
    f10 = { hex = "79", dec = 121 },
    f11 = { hex = "7A", dec = 122 },
    f12 = { hex = "7B", dec = 123 },

    numlock     = { hex = "90", dec = 144 },
    scrolllock  = { hex = "91", dec = 145 },

    [";"] = { hex = "BA", dec = 186 },
    ["="] = { hex = "BB", dec = 187 },
    [","] = { hex = "BC", dec = 188 },
    ["-"] = { hex = "BD", dec = 189 },
    ["."] = { hex = "BE", dec = 190 },
    ["/"] = { hex = "BF", dec = 191 },
    ["`"] = { hex = "C0", dec = 192 },

    ["["] = { hex = "DB", dec = 219 },
    ["\\"]= { hex = "DC", dec = 220 },
    ["]"] = { hex = "DD", dec = 221 },
    ["'"] = { hex = "DE", dec = 222 },
}

local nCount = 0;

for k, v in pairs(tKeys) do
    nCount = nCount + 1;
end

local tKeysDecoy    = {};
local tKeysMeta     = {
    __call = function(t, vValue, vKey, vUseHex)
        local bRet = false;

        if (rawtype(vValue) == "number" and rawtype(vKey) == "string") then
            local sKey      = vKey:lower();
            local bUseHex   = rawtype(vUseHex) == "boolean" and vUseHex or false;
            local sIndex    = bUseHex and "hex" or "dec";

            if (tKeys[sKey] ~= nil) then
                bRet = tKeys[sKey][sIndex] == vValue;
            end

        end

        return bRet;
    end,
    __index = function(t, k)

        if (rawtype(k) == "string") then
            return tKeys[k:lower()];
        end

    end,
    __newindex = function(t, k, v) error("Attempt to write to read-only KEY_CODES table.", 3) end,
    __len = function() return nCount; end,
    __pairs = function(t)
        local sKey = nil;

        return function()
            sKey = next(tKeys, sKey);

            if (sKey ~= nil) then
                local tKey = tKeys[sKey];
                return sKey, tKey.dec, tKey.hex;
            end
        end
    end
};

setmetatable(tKeysDecoy, tKeysMeta);
constant("KEY_CODES", tKeysDecoy);
