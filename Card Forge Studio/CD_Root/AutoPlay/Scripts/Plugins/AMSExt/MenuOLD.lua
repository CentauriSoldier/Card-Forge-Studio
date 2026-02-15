-- simplest stable numeric ID from a menu path string
-- example input: "File>New" or "Options>Draw>Ruler"
Menu = {};

--TODO move this a module...CoG?
-- Unique numeric ID from a path of non-negative integers (or 1-based indices).
-- Uses Cantor pairing folded across the whole path.
-- Note: IDs grow quickly with depth/size.

local function CantorPair(a, b)
    -- a, b must be integers >= 0
    local s = a + b
    return (s * (s + 1)) // 2 + b;
end

local function PathToID(tPath)
    if type(tPath) ~= "table" or #tPath == 0 then
        return nil, "PathToID: tPath must be a non-empty array"
    end

    local id = tPath[1]
    if type(id) ~= "number" or id < 0 or id ~= math.floor(id) then
        return nil, "PathToID: path values must be integers >= 0"
    end

    for i = 2, #tPath do
        local v = tPath[i]
        if type(v) ~= "number" or v < 0 or v ~= math.floor(v) then
            return nil, ("PathToID: path[%d] must be an integer >= 0"):format(i)
        end
        id = CantorPair(id, v)
    end

    return id
end

local ID = PathToID;

function Menu.PathToID(sPath)
    -- canonicalize
    sPath = tostring(sPath):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    -- FNV-1a 32-bit
    local h = 2166136261;
    for i = 1, #sPath do
        h = h ~ sPath:byte(i)
        h = (h * 16777619) & 0xFFFFFFFF
    end

    return h
end

-- examples:
--print(MenuPathToID("File>New"))
--print(MenuPathToID("Options>Draw>Ruler"))
