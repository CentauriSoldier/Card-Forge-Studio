constant("EDITOR_OBJECT", "web editor");
local _sEditorObject = EDITOR_OBJECT;
local _sContent = "--Card Forge Lua Editor";

local _sHTML = [[

]];

--TODO change this to be a global editor for any language...make it modular (later ofc)
local function JSQuote(s)
    s = tostring(s or "");
    s = string.gsub(s, "\\", "\\\\");
    s = string.gsub(s, "\r", "\\r");
    s = string.gsub(s, "\n", "\\n");
    s = string.gsub(s, "\"", "\\\"");
    return "\"" .. s .. "\"";
end

local function URLDecode(s)
    if not (type(s) == "string") then
        return "";
    end

    s = string.gsub(s, "+", " ");
    s = string.gsub(s, "%%(%x%x)", function(h)
        return string.char(tonumber(h, 16));
    end);

    return s;
end

local function ExtractHashValue(sURL, sKey)
    if not (type(sURL) == "string") then
        return nil;
    end

    local sPat = "#"..sKey.."=";
    local nPos = string.find(sURL, sPat, 1, true);

    if not nPos then
        return nil;
    end

    return string.sub(sURL, nPos + #sPat);
end


return class("Editor",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --Editor = function(this, sAuthCode) end, --static constructor (runs after class object creation)
        GetText = function()
            return _sContent;
        end,
        -- OnClose = function()
        --return Edge.ExecuteScript(_sEditorObject, "GetText();");
        --end,
        OnLoaded = function(sURL)
            Edge.ExecuteScript(_sEditorObject, "SetText("..JSQuote(_sContent)..");");
        end,
        OnNavigate = function(sURL)
            local sEnc = ExtractHashValue(sURL, "ACE");
            
            if sEnc then
                _sContent = URLDecode(sEnc);
            end
        end,
        OnShow = function(sPD)
    	    Edge.LoadURL(_sEditorObject, _Docs.."\\Editor.html");
           --Edge.LoadHTML(_sEditorObject, _sHTML);
        end,
        PushText = function()
            Edge.ExecuteScript(_sEditorObject, "PushText();");
        end,
        SetText = function(sText)

            if not (type(sText) == "string") then
                return;
            end

            _sContent = sText;
        end,
    },
    {--PRIVATE
    Editor = function(this, cdat) end,
    },
    {},--PROTECTED
    {},--PUBLIC
    nil,   --extending class
    true, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
