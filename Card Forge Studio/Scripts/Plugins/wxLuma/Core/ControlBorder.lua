local _wx = require("wx");
local ControlBorder = {};
local _tAllowed = {};
for _, nBorder in ipairs({_wx.wxBORDER_DEFAULT, _wx.wxBORDER_NONE, _wx.wxBORDER_SIMPLE,
    _wx.wxBORDER_SUNKEN, _wx.wxBORDER_RAISED, _wx.wxBORDER_STATIC, _wx.wxBORDER_THEME}) do
    _tAllowed[nBorder] = true;
end

--[[!
@fqxn wxLuma.UI.ControlBorder.style
@desc Applies the public Border option to a native host's creation style.
    Omission delegates to wxWidgets. An explicit native border constant replaces
    only border bits, preserving keyboard, traversal and other control styles.
@param table|nil tOptions Constructor options with optional Border.
@param number|nil nStyle Existing native creation flags.
@ret number nStyle Combined native style.
!]]
function ControlBorder.style(tOptions, nStyle)
    local nBorder = tOptions and tOptions.Border;
    if (nBorder == nil) then nBorder = _wx.wxBORDER_DEFAULT; end
    assert(_tAllowed[nBorder], "Border must be a wxBORDER_* constant.");
    return ((nStyle or 0) & ~_wx.wxBORDER_MASK) | nBorder;
end

--[[!
@fqxn wxLuma.UI.ControlBorder.hostOptions
@desc Copies composite options while leaving the layout host at its native
    default. The actual native editor/tree/table receives the requested border,
    avoiding two frames around a single public control.
!]]
function ControlBorder.hostOptions(tOptions)
    ControlBorder.style(tOptions);
    local tCopy = {};
    for sKey, vValue in pairs(tOptions) do tCopy[sKey] = vValue; end
    tCopy.Border = nil;
    return tCopy;
end

--[[!
@fqxn wxLuma.UI.ControlBorder.withDefault
@desc Supplies a control-specific border default without changing caller options.
    Shape controls and labels can omit a rectangular host frame while honoring
    every explicit native border override, including wxBORDER_DEFAULT.
!]]
function ControlBorder.withDefault(tOptions, nDefault)
    if (tOptions.Border ~= nil) then ControlBorder.style(tOptions); return tOptions; end
    local tCopy = {};
    for sKey, vValue in pairs(tOptions) do tCopy[sKey] = vValue; end
    tCopy.Border = nDefault;
    ControlBorder.style(tCopy);
    return tCopy;
end

return ControlBorder;
