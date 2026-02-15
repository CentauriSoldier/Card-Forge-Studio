local class         = class;
local math          = math;
    local clamp     = math.clamp;
local rawtype       = rawtype;
local string        = string;
local toboolean     = toboolean;
local tonumber      = tonumber;
local tostring      = tostring;
local type          = type;
    local clamp         = math.clamp;
    local floor         = math.floor;
    local isnumber      = type.isnumber;
    local isstring      = type.istring;
    local istable       = type.istable;

if type(Color) == "table" then
    function Color.TryFromString(vInput, bForceAlpha)
        local nRet = nil;

        if (type.isstring(vInput)) then
            local sTrimmed = vInput:trim();

            -- HEX: RRGGBB / #RRGGBB / RRGGBBAA / #RRGGBBAA
            local sHex = sTrimmed:sub(1,1) == "#" and sTrimmed:sub(2) or sTrimmed;
            if (sHex:match("^[%x]+$")) then
                local nLen = #sHex;

                if (nLen == 6 or nLen == 8) then
                    local nRed   = tonumber(sHex:sub(1,2), 16);
                    local nGreen = tonumber(sHex:sub(3,4), 16);
                    local nBlue  = tonumber(sHex:sub(5,6), 16);

                    if (nLen == 8) then
                        local nAlpha = tonumber(sHex:sub(7,8), 16);
                        nRet = Color.RGBA(nRed, nGreen, nBlue, nAlpha);
                    else
                        if (toboolean(bForceAlpha)) then
                            nRet = Color.RGBA(nRed, nGreen, nBlue, 255);
                        else
                            nRet = Color.RGB(nRed, nGreen, nBlue);
                        end
                    end
                end
            end

            -- CSV: r,g,b or r,g,b,a (only if hex path didn’t succeed)
            if (nRet == nil) then
                local tValuesRaw = (not sTrimmed:isempty()) and sTrimmed:totable(',') or nil;

                if (tValuesRaw) then
                    local tValues = {};
                    local bValid  = true;

                    for _, vValue in ipairs(tValuesRaw) do
                        local nVal = tonumber(vValue);

                        if not type.isnumber(nVal) then
                            bValid = false;
                            break;
                        end

                        tValues[#tValues + 1] = nVal;
                    end

                    local nValues = #tValues;

                    if (bValid) then
                        if (nValues == 3) then
                            local nRed   = clamp(tValues[1], 0, 255);
                            local nGreen = clamp(tValues[2], 0, 255);
                            local nBlue  = clamp(tValues[3], 0, 255);

                            if (toboolean(bForceAlpha)) then
                                nRet = Color.RGBA(nRed, nGreen, nBlue, 255);
                            else
                                nRet = Color.RGB(nRed, nGreen, nBlue);
                            end

                        elseif (nValues == 4) then
                            nRet = Color.RGBA(
                                clamp(tValues[1], 0, 255),
                                clamp(tValues[2], 0, 255),
                                clamp(tValues[3], 0, 255),
                                clamp(tValues[4], 0, 255)
                            );
                        end
                    end
                end
            end
        end

        if (nRet) then
            nRet = math.floor(nRet);
        end

        return nRet;
    end

end
