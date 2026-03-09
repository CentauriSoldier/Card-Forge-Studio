local floor = math.floor;
local type  = type;
    local isnumber = type.isnumber;
RGBToNumber = Math.RGBToNumber;

local tInputs = {
    Family              = "Times New Roman",
    Size                = 12,
    Bold                = false,
    Italic              = false,
    Underline           = false,
    StrikeOut           = false,
    ShadowX             = 0,
    ShadowY             = 0,
    OutlineThickness    = 0,
    OutlineColor        = 0,
    ["3DColor"]         = "",
    ["3DDepth"]         = "",
    ["3DStepX"]         = "",
    ["3DStepY"]         = ""
};
local tCheckBoxes 	= {

};--Bold = false, Italic = false, Underline = false, StrikeOut = false, HQ = true};
local tColorSelectors = {
    Color       = "",
    ShadowColor = "",

};

--local _tSilderPos       = {};
local _sActiveStyle     = "";
--local _sRefStyle        = "";
local _sCanvasPrefix    = "cvs sample text";
local _sComboStyles     = "cmb styles";
local _sListStyles      = "lst styles";
local _sChainDisplay    = "par chain display";
--local _tActiveColor;
local _nMouseX          = 0;
local _nMouseY          = 0;
local _oClear           = Color.RGBA(0, 0, 0, 0)
local _oBlack           = Color.RGBA(0, 0, 0, 255);
local _oWhite           = Color.RGBA(255, 255, 255, 255);
local _oCanvasColor     = Color.RGBA(102, 93, 75, 255);
local _tDrawSystem      = {}; --used to store canvases, handles and numbers
local _nUpdateTimerID    = 1;
local _nUpdateTimerInt   = 300;

local _tStyles; --updated OnShow

local function GetValue(sValue, bChain)
    return INIFile.GetValue(_tStyles, _sActiveStyle, sValue, bChain);
end

local function SaveValue(sValue, sData, bChain)

    if not (_sActiveStyle:isempty()) then
        INIFile.SetValue(_tStyles, _sActiveStyle, sValue, sData, bChain);
    end

end

local function GetValueNameFromObject(sObject)
    local nStart = sObject:find(" ");

    if not (nStart) then
        return "";
    end

    local sRest = sObject:sub(nStart + 1);
    local nEnd  = sRest:find(" ");

    return nEnd and sRest:sub(1, nEnd - 1) or sRest;
end

local function GetChainString(sValue)
    local sValue, tChain = GetValue(sValue, true);
    local sRet = "";

    if (tChain) then
        local sLink = "";

        for nIndex, sEntry in ipairs(tChain) do
            sRet    = sRet..sLink..sEntry;
            sLink   = " -> ";
        end

    end

    return sRet;
end



local function SetCheckBox(sValue)
    local sData, tChain = INIFile.GetValue(_tStyles, _sActiveStyle, sValue);
    local bChecked 	= toboolean(sValue);
    bChecked		= type(bChecked) == "boolean" and bChecked or tCheckBoxes[sValue];
    CheckBox.SetChecked("chk "..sValue, bChecked);
end

local function SetInput(sValue)
    local sData         = INIFile.GetValue(_tStyles, _sActiveStyle, sValue);
    local sChainData    = INIFile.GetValue(_tStyles, _sActiveStyle, sValue, true);
    Input.SetText("inp "..sValue, sData);
    Input.SetText("inp "..sValue.. " chain", sChainData);
end



local function Reset()

    for _, sInput in pairs(tInputs) do
        Input.SetText("inp "..sInput, "");
    end

    for sCheckBox, bEnabled in pairs(tCheckBoxes) do
        CheckBox.SetChecked("chk "..sCheckBox, bEnabled);
    end

end

function InvertColor(tColor)
    if (type(tColor) ~= "table") then
        return nil;
    end

    local r = tonumber(tColor.Red);
    local g = tonumber(tColor.Green);
    local b = tonumber(tColor.Blue);

    if (not r or not g or not b) then
        return nil;
    end

    return {
        Red   = 255 - r,
        Green = 255 - g,
        Blue  = 255 - b
    };
end


local function UpdateColorSelector(sObject, vColor, bSkipSliderUpdate)
    local sRet = "";
    local zColor = type(vColor);
    local tColor = (zColor == "table")  and vColor or false
    local sColor = (zColor == "string") and vColor or false;
    local nColor = (zColor == "number") and vColor or false;

    local sObjectSuffix = GetValueNameFromObject(sObject);
    --_tActiveColor = nil;

    if (sColor) then
        nColor = Color.TryFromString(sColor, true);
    end

    if (nColor) then
        local nRed 		= Color.GetRed(nColor);
        local nGreen 	= Color.GetGreen(nColor);
        local nBlue		= Color.GetBlue(nColor);
        local nAlpha    = Color.GetAlpha(nColor)--Slider.GetSliderPos("sld "..sObjectSuffix);

        if (isnumber(nRed) and isnumber(nGreen) and isnumber(nBlue) and isnumber(nAlpha)) then
            tColor = {
                Red      = nRed,
                Green    = nGreen,
                Blue     = nBlue,
                Alpha    = nAlpha,
            };
        end

    end

    if (tColor and not tColor.Alpha) then-- and _tSilderPos[sObjectSuffix]) then
        tColor.Alpha = floor(Slider.GetSliderPos("sld "..sObjectSuffix));--_tSilderPos[sObjectSuffix]);
        --_tSilderPos[sObjectSuffix]  = nil;
        --bSkipSliderUpdate           = true;
    end

    Paragraph.SetProperties("par "..sObjectSuffix, {BGColor = RGBToNumber(0, 0, 0), Text = "0,0,0,0"});--Text = "???,???,???,???"});

    if (tColor and tColor.Red and tColor.Green and tColor.Blue and tColor.Alpha) then
        local tInverted = InvertColor(tColor);
        local nRed 		= floor(tColor.Red);
        local nGreen 	= floor(tColor.Green);
        local nBlue 	= floor(tColor.Blue);
        local nAlpha    = floor(tColor.Alpha);

        local nColor 	= RGBToNumber(nRed, nGreen, nBlue);
        local nColorInv = RGBToNumber(tInverted.Red, tInverted.Green, tInverted.Blue);
        local sMyText 	= nRed..','..nGreen..','..nBlue..','..floor(nAlpha);

        local tProps = {
            ColorNormal 	= nColorInv,
            ColorHighlight	= nColorInv,
            ColorDisabled   = nColorInv,
            ColorDown       = nColor,
            BGColor 		= nColor,
            Text 		    = sMyText,
        };

        Paragraph.SetProperties("par "..sObjectSuffix, tProps);

        if not (bSkipSliderUpdate) then
            Slider.SetSliderPos("sld "..sObjectSuffix, nAlpha);
        end

        sRet = sMyText;
        SaveValue(sObjectSuffix, sMyText);
        --_tActiveColor = {Red = nRed, Green = nGreen, Blue = nBlue, Alpha = nAlpha};
    end
    --TODO reset colorsector to default if no color present and indicate issue???
    return sRet;
end

local _sDisplayText = "The quick brown fox jumped over the lazy dog.";
local function UpdateDisplayText(...)
    local oFontStyle  = Forge.STYLE[_sActiveStyle];
    oFontStyle:Update();

    for nIndex, tDrawSystem in pairs(_tDrawSystem) do
        tDrawSystem.FontStyle = oFontStyle;
        tDrawSystem.Handle:Draw(tDrawSystem.ImageDraw);
        Canvas.Draw(tDrawSystem.Canvas, tDrawSystem.CanvasDraw);
    end

end

local _sChainTarget = "";

return class("StyleEditor",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --StyleEditor = function(this, sAuthCode) end, --static constructor (runs after class object creation)\
        ChainOnClick = function(sObject);
            local tPos  = Image.GetPos(sObject);
            local nX = tPos.X + 10;
            local nY = tPos.Y + 5;
            ComboBox.SetPos(_sComboStyles, nX, nY);
            ComboBox.SetVisible(_sComboStyles, true);
            ComboBox.SetEnabled(_sComboStyles, true);
            --update the chain target
            _sChainTarget = GetValueNameFromObject(sObject);
        end,
        ChainOnSelect = function(sObject);
            local nSelected     = ComboBox.GetSelected(_sComboStyles);
            local sChainStyle   = ComboBox.GetItemText(_sComboStyles, nSelected);

            if (sChainStyle and not sChainStyle:isempty()) then
                --TODO set stuff here
                local sValue = GetValueNameFromObject(sObject);
                SaveValue(_sChainTarget, '<'..sChainStyle..'>');

                local nIndex = ListBox.FindItem(_sListStyles, -1, LB_BYTEXT, _sActiveStyle);
                ListBox.SelectItem(_sListStyles, nIndex);

                UpdateDisplayText();
            end

            ComboBox.SetPos(_sComboStyles, -500, -500); --magic numbers = offscreen
            ComboBox.SetVisible(_sComboStyles, false);
            ComboBox.SetEnabled(_sComboStyles, false);

            --update the chain target
            _sChainTarget = "";
        end,
        OnColorSelect = function(sObject)
            local tColor = ColorPicker.Pick(DialogEx.GetWndHandle());

            if (tColor) then
                UpdateColorSelector(sObject, tColor, true);
            end

            UpdateDisplayText();
        end,
        OnColorSliderPosChange = function(sObject, nPos)
            local sValue = GetValueNameFromObject(sObject);

            --get/set the old/new color
            local sColor    = Paragraph.GetText("par "..sValue);
            local tColorRaw = sColor:totable(',');
            tColor = {
                Red     = tColorRaw[1],
                Green   = tColorRaw[2],
                Blue    = tColorRaw[3],
                Alpha   = nPos,
            };
            UpdateColorSelector(sObject, tColor, true);
        end,
        OnComboBoxSelect = function(this)--TODO resolve "this" as arg issue
            local nSelected = ComboBox.GetSelected(_sComboStyles);

            if (nSelected ~= -1) then
                _sRefStyle = ComboBox.GetItemText(_sComboStyles, 1);
            end

        end,
        OnEnter = function(sObject)
            local sChain = GetChainString(GetValueNameFromObject(sObject));
            Paragraph.SetText(_sChainDisplay, sChain);
        end,
        InputOnKey = function(sObject, nKey, tModifiers)
            local sValue = GetValueNameFromObject(sObject);
            SaveValue(sValue, Input.GetText(sObject));
            Forge.STYLE[_sActiveStyle].Update();
        end,
        OnLeave = function(sObject)
            Paragraph.SetText(_sChainDisplay, "");
        end,
        OnListBoxSelect = function(sObject)
            local tSelected = ListBox.GetSelected(sObject);

            if (tSelected and #tSelected > 0) then
            	local nSelected 	= tSelected[1];
            	local sStyle 		= ListBox.GetItemText(sObject, nSelected);
                _sActiveStyle       = sStyle;
            	local tValueNames 	= INIFile.GetValueNames(_tStyles, sStyle)

            	if (tValueNames and #tValueNames > 0) then

            		for _, sValueName in pairs(tValueNames) do

            			if (tInputs[sValueName] ~= nil) then
            				SetInput(sValueName);

            			elseif (type(tCheckBoxes[sValueName]) == "boolean") then
            				SetCheckBox(sValueName);

                        elseif (tColorSelectors[sValueName]) then
                            local sColor = GetValue(sValueName);
                            --p(_sActiveStyle, sValueName, "par "..sValueName, sColor)
                            UpdateColorSelector("par "..sValueName, sColor);

                        end

            		end

            	end

                UpdateDisplayText();
            end
            --DISPLAY TEXT
            --abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,:;!?'"()-_/@#&+=*%$

        end,
        OnMouseMove = function(nX, nY)
            _nMouseX = nX;
            _nMouseY = nY;
            Paragraph.SetText("par mouse", "X: ".._nMouseX.." Y:".._nMouseY);
        end,
        OnShow = function()
            _tDrawSystem = {};
            _tStyles = FS.Styles;
            p(_tStyles)
            for x = 1, 2 do
                _tDrawSystem[x] = {};
                local tDS = _tDrawSystem[x];

                tDS.Canvas = _sCanvasPrefix..x;
                tDS.BGColor = x == 1 and _oBlack or _oWhite;

                local sCanvas = tDS.Canvas;

            	Canvas.Create(sCanvas);
                local tSize = Input.GetSize(sCanvas);

            	tDS.Handle = DrawingImage.New(tSize.Width, tSize.Height, BIT_DEPTH_32, DRAW_IMAGE_TRANSPARENT);

                if not (tDS.Handle) then
                    error("Error in StyleEditor.OnShow: could not create image.", 2);
                end

                tDS.Number = DrawingImage.GetID(tDS.Handle);

                if not (tDS.Number) then
                    error("Error in StyleEditor.OnShow: could not get image ID.", 2);
                end

                local function ImageDraw(sObject, D, DC)
                    -- Make sure we're not in outline/alpha-only mode when clearing
                    D.SetFilteringMode(DRAW_BLEND_ALLCHANNELS);

                    -- CLEAR THE DRAWING IMAGE (use image size)
                    D.DrawRectangle(0, 0, tSize.Width, tSize.Height, _oClear); -- alpha=0 color

                    -- Now draw the text onto the cleared image
                    tDS.FontStyle.Draw(sObject, D, DC, 12, 0, _sDisplayText);
                end

                tDS.ImageDraw = ImageDraw;

                local function CanvasDraw(sObject, D, hInternalDC)
                    D.SetFilteringMode(DRAW_BLEND_DEFAULT);
                    D.DrawRectangle(0, 0, tSize.Width, tSize.Height, tDS.BGColor);
                    D.SetFilteringMode(DRAW_BLEND_ALPHABLEND, DRAW_BLEND_TEXT_TRANSPARENT);
                    D.DrawImage(tDS.Number, 0, 0);
                end

                tDS.CanvasDraw = CanvasDraw;
            end

            DialogEx.StartTimer(_nUpdateTimerInt, _nUpdateTimerID);
        end,
        OnTimer = function(nID)

            if (nID == _nUpdateTimerID and _sActiveStyle ~= "") then
                UpdateDisplayText(); --so we don't have to do this in silder pos changes operations and in InputOnKey
            end

        end,
        UpdateStyles = function()
            local tStyles = INIFile.GetSectionNames(_tStyles);

            if (tStyles and #tStyles > 0) then
            	ListBox.DeleteItem(_sListStyles, LB_ALLITEMS);
                ComboBox.ResetContent(_sComboStyles);

            	for _, sStyle in pairs(tStyles) do
            		ListBox.AddItem(_sListStyles, sStyle, "");
                    ComboBox.AddItem(_sComboStyles, sStyle, "");
            	end

            end

        end,
    },
    {--PRIVATE
    StyleEditor = function(this, cdat)--, super)

    end,
    },
    {--PROTECTED

    },
    {--PUBLIC

    },
    nil,   --extending class
    true, --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);
