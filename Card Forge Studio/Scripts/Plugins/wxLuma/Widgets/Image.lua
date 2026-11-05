local _wx             = require("wx");
local _ControlSurface = require("wxLuma.Core.ControlSurface");
local _ControlEvents  = require("wxLuma.Core.ControlEvents");
local Image           = {};

--[[!
@fqxn wxLuma.UI.Image.create
@desc Displays an image with alpha transparency and contain, cover, stretch or
    native scaling. Owns its decoded image and one cached display bitmap; the
    parent owns the native window. Failed loads preserve the current image.
@param wxWindow oParent The native parent.
@param table tOptions Skin, Value (path or nil), ScaleMode (contain), Enabled,
    OnChange. File formats depend on image handlers supplied by the wxLua build.
@ret table oComponent An independent public proxy with standard surface/events API.
!]]
function Image.create(oParent, tOptions)
    local sMode = tOptions.ScaleMode or "contain";
    assert(sMode == "contain" or sMode == "cover" or sMode == "stretch" or sMode == "native",
        "Invalid image ScaleMode.");
    assert(tOptions.Value == nil or type(tOptions.Value) == "string", "Image Value must be a path or nil.");

    local oComponent = _ControlSurface.create(oParent, tOptions, "Image");
    local tEvents    = _ControlEvents.attach(oComponent);
    local oBrush     = _wx.wxBrush(_wx.wxColour(24, 29, 36));
    local oImage, oBitmap;
    local nCachedWidth, nCachedHeight;

    -- Drop the display bitmap whenever the source or scaling policy changes.
    local function fClearBitmap()
        if (oBitmap) then
            oBitmap:delete();
            oBitmap = nil;
        end

        nCachedWidth, nCachedHeight = nil, nil;
    end

    --[[!
    @fqxn wxLuma.UI.Image.setValue
    @desc Loads a replacement atomically, or clears the image with nil. Reusing
        the current path is a no-op. Invalid paths raise an error before mutation.
    @param string|nil pImage The image path or nil.
    @param boolean|nil bNotify Whether to emit OnChange/valueChanged/imageLoaded.
    @ret table oComponent This component.
    !]]
    function oComponent.setValue(pImage, bNotify)
        assert(pImage == nil or type(pImage) == "string", "Image value must be a path or nil.");

        if (oComponent.Disposed or pImage == oComponent.Value) then
            return oComponent;
        end

        local oReplacement;

        if (pImage) then
            local hFile = io.open(pImage, "rb");
            assert(hFile, "Image file cannot be opened: "..pImage);
            hFile:close();
            oReplacement = _wx.wxImage(pImage, _wx.wxBITMAP_TYPE_ANY);

            if (not oReplacement:IsOk()) then
                oReplacement:delete();
                error("Image could not be decoded: "..pImage);
            end
        end

        local pOldValue = oComponent.Value;
        fClearBitmap();

        if (oImage) then
            oImage:delete();
        end

        oImage = oReplacement;
        oComponent.Value = pImage;
        oComponent.refresh();

        if (bNotify) then
            if (oComponent.OnChange) then
                oComponent.OnChange(pImage, oComponent);
            end

            tEvents.emit("valueChanged", {Value = pImage, OldValue = pOldValue});

            if (oImage) then
                tEvents.emit("imageLoaded", {
                    Path = pImage, Width = oImage:GetWidth(), Height = oImage:GetHeight()
                });
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Image.setScaleMode
    @desc Changes scaling policy and invalidates only this image's bitmap cache.
    @param string sValue contain, cover, stretch or native.
    @ret table oComponent This component.
    !]]
    function oComponent.setScaleMode(sValue)
        assert(sValue == "contain" or sValue == "cover" or sValue == "stretch" or sValue == "native",
            "Invalid image scale mode.");

        if (sMode ~= sValue and not oComponent.Disposed) then
            sMode = sValue;
            fClearBitmap();
            oComponent.refresh();
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Image.getScaleMode
    @desc Returns the current scaling policy.
    @ret string sMode The policy name.
    !]]
    function oComponent.getScaleMode()
        return sMode;
    end

    --[[!
    @fqxn wxLuma.UI.Image.getImageSize
    @desc Returns decoded source dimensions, or zeroes when empty/disposed.
    @ret number nWidth The source width, followed by height.
    !]]
    function oComponent.getImageSize()
        if (oImage) then
            return oImage:GetWidth(), oImage:GetHeight();
        end

        return 0, 0;
    end

    -- Cache only the most recently requested size. Cover/native images remain
    -- centered and clipped; contain preserves the full source aspect ratio.
    --[[!
    @fqxn wxLuma.UI.Image.draw
    @desc Draws the current value into a borrowed DC without owning that DC.
    @param wxDC oDC The destination drawing context.
    @param number nWidth The available width in pixels.
    @param number nHeight The available height in pixels.
    !]]
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then
            return;
        end

        oDC:SetBackground(oBrush);
        oDC:Clear();

        if (not oImage or nWidth < 1 or nHeight < 1) then
            return;
        end

        local nSourceWidth, nSourceHeight = oImage:GetWidth(), oImage:GetHeight();
        local nDrawWidth, nDrawHeight = nSourceWidth, nSourceHeight;

        if (sMode == "stretch") then
            nDrawWidth, nDrawHeight = nWidth, nHeight;
        elseif (sMode ~= "native") then
            local nScale;

            if (sMode == "cover") then
                nScale = math.max(nWidth / nSourceWidth, nHeight / nSourceHeight);
            else
                nScale = math.min(nWidth / nSourceWidth, nHeight / nSourceHeight);
            end

            nDrawWidth  = math.max(1, math.floor(nSourceWidth * nScale + 0.5));
            nDrawHeight = math.max(1, math.floor(nSourceHeight * nScale + 0.5));
        end

        if (not oBitmap or nCachedWidth ~= nDrawWidth or nCachedHeight ~= nDrawHeight) then
            fClearBitmap();
            local oScaled = oImage:Scale(nDrawWidth, nDrawHeight, _wx.wxIMAGE_QUALITY_HIGH);
            oBitmap = _wx.wxBitmap(oScaled);
            oScaled:delete();
            nCachedWidth, nCachedHeight = nDrawWidth, nDrawHeight;
        end

        oDC:SetClippingRegion(0, 0, nWidth, nHeight);
        oDC:DrawBitmap(oBitmap, math.floor((nWidth - nDrawWidth) / 2),
            math.floor((nHeight - nDrawHeight) / 2), true);
        oDC:DestroyClippingRegion();
    end;
    oComponent.onDestroy = function()
        fClearBitmap();

        if (oImage) then
            oImage:delete();
            oImage = nil;
        end

        oBrush:delete();
    end;
    oComponent.setValue(tOptions.Value);
    return oComponent;
end

return Image;