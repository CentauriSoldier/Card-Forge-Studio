-- One native command row remains available while the editor is hidden.
local wx = require("wx");
local Toolbar = {};
local pRoot = assert(debug.getinfo(1, "S").source:match("^@(.+[/\\])")).."../../Images/Manual/";
local tNames = {edit = "HideEditor", save = "Save", undo = "Undo", redo = "Redo", refresh = "Refresh", styles = "Styles", options = "Options", fit = "Fit", grid = "Grid", snap = "Snap"};

function Toolbar.create(dParent)
    local dPanel = wx.wxPanel(dParent, wx.wxID_ANY);
    local oLayout = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local tControls, tSeparators = {}, {};
    local sVariant = "Dark";
    local nScale = 1;
    local nPointSize = dPanel:GetFont():GetPointSize();
    local function bitmap(sName)
        local oImage = wx.wxImage(pRoot.."Toolbar"..sName..sVariant..".png", wx.wxBITMAP_TYPE_PNG);
        local nSize = math.floor(24 * nScale + 0.5);
        local oScaled = oImage:Scale(nSize, nSize, wx.wxIMAGE_QUALITY_HIGH);
        local oBitmap = wx.wxBitmap(oScaled); oScaled:delete(); oImage:delete(); return oBitmap;
    end
    local function add(sKey, sHint, bToggle)
        local oBitmap = bitmap(tNames[sKey]);
        local dControl;
        if (bToggle) then dControl = wx.wxToggleButton(dPanel, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize(34, 34), wx.wxBORDER_NONE); dControl:SetBitmap(oBitmap);
        else dControl = wx.wxBitmapButton(dPanel, sKey == "save" and wx.wxID_SAVE or wx.wxID_ANY, oBitmap, wx.wxDefaultPosition, wx.wxSize(34, 34), wx.wxBORDER_NONE); end
        oBitmap:delete(); dControl:SetThemeEnabled(false); dControl:SetToolTip(sHint); tControls[sKey] = dControl; oLayout:Add(dControl, 0, wx.wxALL, 3);
    end
    local function separator()
        local dLine = wx.wxStaticLine(dPanel, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(1, 24), wx.wxLI_VERTICAL);
        tSeparators[#tSeparators + 1] = dLine; oLayout:Add(dLine, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxLEFT + wx.wxRIGHT, 6);
    end
    add("edit", "Hide editor", true); tControls.edit:SetValue(true); add("save", "Save (Ctrl+S)"); separator();
    add("undo", "Undo (Ctrl+Z)"); add("redo", "Redo (Ctrl+Shift+Z)"); separator();
    add("refresh", "Refresh preview"); add("styles", "Game and manual styles"); add("options", "Manual options"); separator();
    add("fit", "Fit page");
    local oZoom = wx.wxSlider(dPanel, wx.wxID_ANY, 70, 10, 400, wx.wxDefaultPosition, wx.wxSize(150, 28), wx.wxSL_HORIZONTAL);
    oZoom:SetLineSize(4); oZoom:SetPageSize(4); oZoom:SetThemeEnabled(false); oZoom:SetToolTip("Page zoom; step size is set in Manual Options; Ctrl+wheel zooms the page"); oLayout:Add(oZoom, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 3); tControls.zoom = oZoom;
    local oZoomLabel = wx.wxStaticText(dPanel, wx.wxID_ANY, "70%", wx.wxDefaultPosition, wx.wxSize(48, -1)); oLayout:Add(oZoomLabel, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 3); tControls.zoomLabel = oZoomLabel;
    local oZoomReset = wx.wxButton(dPanel, wx.wxID_ANY, "100%", wx.wxDefaultPosition, wx.wxSize(52, 30), wx.wxBORDER_NONE); oZoomReset:SetThemeEnabled(false); oZoomReset:SetToolTip("Reset page zoom to 100%"); oLayout:Add(oZoomReset, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 3); tControls.zoomReset = oZoomReset;
    add("grid", "Show/hide grid", true); add("snap", "Automatic snapping; hold Alt while moving for temporary snapping", true);
    dPanel:SetSizer(oLayout);
    local sPalette;
    return {panel = dPanel, controls = tControls,
        editorVisible = function(bVisible)
            tControls.edit:SetValue(bVisible); tControls.edit:SetToolTip(bVisible and "Hide editor" or "Show editor");
            local oBitmap = bitmap(bVisible and "HideEditor" or "ShowEditor"); tControls.edit:SetBitmap(oBitmap); oBitmap:delete();
            for _, sKey in ipairs({"undo", "redo", "fit", "zoom", "zoomLabel", "zoomReset", "grid", "snap"}) do tControls[sKey]:Enable(bVisible); end
        end,
        scale = function(nValue)
            nValue = math.max(0.75, math.min(1.5, nValue));
            if (math.abs(nScale - nValue) < 0.005) then return; end nScale = nValue;
            local oFont = wx.wxFont(math.max(6, math.floor(nPointSize * nScale + 0.5)), wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL);
            for sKey, dControl in pairs(tControls) do
                local nSize = math.floor(34 * nScale + 0.5);
                dControl:SetFont(oFont); dControl:SetMinSize(wx.wxSize((sKey == "zoom" and math.floor(150 * nScale + 0.5) or sKey == "zoomLabel" and math.floor(48 * nScale + 0.5) or sKey == "zoomReset" and math.floor(52 * nScale + 0.5) or nSize), nSize));
                if (tNames[sKey]) then local oBitmap = bitmap(sKey == "edit" and (tControls.edit:GetValue() and "HideEditor" or "ShowEditor") or tNames[sKey]); dControl:SetBitmap(oBitmap); oBitmap:delete(); end
            end
            oFont:delete(); dPanel:GetParent():Layout();
        end,
        palette = function(sBackground, sText)
            if (sPalette == sBackground..sText) then return; end
            local oBackground, oText = wx.wxColour(sBackground), wx.wxColour(sText);
            sVariant = (oText:Red() + oText:Green() + oText:Blue()) > 384 and "Dark" or "Light";
            dPanel:SetBackgroundColour(oBackground);
            for sKey, dControl in pairs(tControls) do
                dControl:SetBackgroundColour(oBackground); dControl:SetForegroundColour(oText);
                if (tNames[sKey]) then local oBitmap = bitmap(sKey == "edit" and (tControls.edit:GetValue() and "HideEditor" or "ShowEditor") or tNames[sKey]); dControl:SetBitmap(oBitmap); oBitmap:delete(); end
            end
            for _, dLine in ipairs(tSeparators) do dLine:SetBackgroundColour(oText); end
            oBackground:delete(); oText:delete(); sPalette = sBackground..sText; dPanel:Refresh();
        end};
end

return Toolbar;
