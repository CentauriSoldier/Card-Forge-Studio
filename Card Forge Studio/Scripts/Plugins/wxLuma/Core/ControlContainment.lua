local _wx               = require("wx");
local _tPolicies        = setmetatable({}, {__mode = "v"});
local _tObservedWindows = setmetatable({}, {__mode = "v"});
local _sDefaultOverflow = "hide";
local ControlContainment = {};

local function validateOverflow(sPolicy)
    assert(sPolicy == nil or sPolicy == "hide" or sPolicy == "allow", "ContainmentOverflow must be hide, allow or nil.");
    return sPolicy;
end

local function notifyPolicies()
    for _, tPolicy in pairs(_tPolicies) do
        if (not tPolicy.Dead and tPolicy.Observer) then
            tPolicy.Observer("policy");
        end
    end
end

--[[!
@fqxn wxLuma.UI.ControlContainment.setDefaultOverflow
@desc Sets framework behavior for an oversized popup: hide (POLA default), or
    allow overflow while preserving size. Fitting popups always remain contained.
@param string sPolicy hide or allow.
!]]
function ControlContainment.setDefaultOverflow(sPolicy)
    assert(sPolicy ~= nil, "A default overflow policy is required.");
    validateOverflow(sPolicy);

    if (_sDefaultOverflow ~= sPolicy) then
        _sDefaultOverflow = sPolicy;
        notifyPolicies();
    end
end

--[[!
@fqxn wxLuma.UI.ControlContainment.getDefaultOverflow
@desc Returns the framework default for popups that cannot fit by movement alone.
@ret string sPolicy hide or allow.
!]]
function ControlContainment.getDefaultOverflow()
    return _sDefaultOverflow;
end
--[[!
@fqxn wxLuma.UI.ControlContainment.native
@desc Accepts a native window or a visual wxLuma object exposing Control.
@param any vWindow The native window or public component.
@ret wxWindow oWindow The validated native window.
!]]
function ControlContainment.native(vWindow)
    if (type(vWindow) == "table") then
        assert(not vWindow.Disposed, "Containment component is disposed.");
        vWindow = vWindow.Control;
    end

    assert(type(vWindow) == "userdata" and type(vWindow.GetClientSizeWH) == "function",
        "Containment requires a native window or visual component.");
    assert(not vWindow:IsBeingDeleted(), "Containment window is being destroyed.");
    return vWindow;
end

-- Return a plain screen-space client rectangle. Bounds never include native
-- title bars, window decorations or application-owned margins outside a client.
local function clientBounds(oWindow)
    local nWidth, nHeight = oWindow:GetClientSizeWH();
    local oPoint = oWindow:ClientToScreen(_wx.wxPoint(0, 0));
    return {X = oPoint:GetX(), Y = oPoint:GetY(), Width = nWidth, Height = nHeight};
end

local function intersect(tLeft, tRight)
    local nX = math.max(tLeft.X, tRight.X);
    local nY = math.max(tLeft.Y, tRight.Y);
    local nRight = math.min(tLeft.X + tLeft.Width, tRight.X + tRight.Width);
    local nBottom = math.min(tLeft.Y + tLeft.Height, tRight.Y + tRight.Height);
    return {X = nX, Y = nY, Width = math.max(0, nRight - nX), Height = math.max(0, nBottom - nY)};
end

--[[!
@fqxn wxLuma.UI.ControlContainment.attach
@desc Adds common containment policy without changing native parenting, layout
    or ordinary child clipping. A nil setting inherits the nearest explicit
    ancestor policy, otherwise the native top-level parent's client area.
@param table oComponent The visual component with Control and destroy.
@param wxWindow oAnchor The control or target whose parent chain defines policy.
@param table tOptions Optional Containment (ancestor window/component) and
    ContainmentOverflow (hide/allow). Both inherit when omitted.
@ret table tPolicy Private bounds, popup placement and lifecycle observation helpers.
!]]
function ControlContainment.attach(oComponent, oAnchor, tOptions)
    local tPolicy = {Dead = false};
    local tObservations = {};
    local oExplicit;
    local nControlID = oComponent.Control:GetId();
    _tPolicies[nControlID] = tPolicy;

    local function fValidate(vWindow)
        if (vWindow == nil) then
            return nil;
        end

        local oBoundary = ControlContainment.native(vWindow);
        local nBoundaryID = oBoundary:GetId();
        local oCurrent = oAnchor;

        while (oCurrent) do
            if (oCurrent:GetId() == nBoundaryID) then
                return oBoundary;
            end

            if (oCurrent:IsTopLevel()) then
                break;
            end

            oCurrent = oCurrent:GetParent();
        end

        error("Containment must be the target or one of its ancestor windows.");
    end

    --[[!
    @fqxn wxLuma.UI.ControlContainment.getContainment
    @desc Resolves the effective native boundary, including inherited policy.
    @ret wxWindow oWindow The boundary window.
    !]]
    function oComponent.getContainment()
        assert(not tPolicy.Dead, "Component is disposed.");

        if (oExplicit) then
            return oExplicit;
        end

        local oCurrent = oAnchor;

        while (oCurrent) do
            local tOther = _tPolicies[oCurrent:GetId()];

            if (tOther and not tOther.Dead and tOther.Explicit) then
                return tOther.Explicit;
            end

            if (oCurrent:IsTopLevel()) then
                return oCurrent;
            end

            local oParent = oCurrent:GetParent();

            if (not oParent) then
                return oCurrent;
            end

            oCurrent = oParent;
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlContainment.setContainment
    @desc Sets an explicit ancestor boundary; nil restores inherited/top-level
        policy. Repositions visible floating content through registered observers.
    @param wxWindow|table|nil vWindow Native window, visual component or nil.
    @ret table oComponent This component.
    !]]
    function oComponent.setContainment(vWindow)
        assert(not tPolicy.Dead, "Component is disposed.");
        local oNext = fValidate(vWindow);

        if ((oNext and oExplicit and oNext:GetId() == oExplicit:GetId()) or (not oNext and not oExplicit)) then
            return oComponent;
        end

        oExplicit = oNext;
        tPolicy.Explicit = oNext;

        -- Policy changes are rare. Notify existing popup observers immediately,
        -- including descendants inheriting a container's changed boundary.
        notifyPolicies();


        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ControlContainment.getContainmentOverflow
    @desc Resolves the object's oversized-popup policy through ancestors/default.
    @ret string sPolicy hide or allow.
    !]]
    function oComponent.getContainmentOverflow()
        assert(not tPolicy.Dead, "Component is disposed.");

        if (tPolicy.Overflow) then
            return tPolicy.Overflow;
        end

        local oCurrent = oAnchor;

        while (oCurrent) do
            local tOther = _tPolicies[oCurrent:GetId()];

            if (tOther and not tOther.Dead and tOther.Overflow) then
                return tOther.Overflow;
            end

            if (oCurrent:IsTopLevel()) then
                break;
            end

            oCurrent = oCurrent:GetParent();
        end

        return _sDefaultOverflow;
    end

    --[[!
    @fqxn wxLuma.UI.ControlContainment.setContainmentOverflow
    @desc Overrides oversized-popup behavior. Nil restores ancestor/default policy.
        This setting never changes a control's position or size on its own.
    @param string|nil sPolicy hide, allow or nil.
    @ret table oComponent This component.
    !]]
    function oComponent.setContainmentOverflow(sPolicy)
        assert(not tPolicy.Dead, "Component is disposed.");
        validateOverflow(sPolicy);

        if (tPolicy.Overflow ~= sPolicy) then
            tPolicy.Overflow = sPolicy;
            notifyPolicies();
        end

        return oComponent;
    end
    --[[!
    @fqxn wxLuma.UI.ControlContainment.getContainmentBounds
    @desc Returns visible screen-space client bounds, intersected with the chosen
        ancestor's native clipping ancestors and the target display work area.
    @ret table|nil tBounds X/Y/Width/Height, or nil if hidden/destroying/empty.
    !]]
    function oComponent.getContainmentBounds()
        if (tPolicy.Dead) then
            return nil;
        end

        local oBoundary = oComponent.getContainment();

        if (not oBoundary or oBoundary:IsBeingDeleted() or not oBoundary:IsShownOnScreen()) then
            return nil;
        end

        local tBounds = clientBounds(oBoundary);
        local oCurrent = oBoundary;

        while (not oCurrent:IsTopLevel()) do
            oCurrent = oCurrent:GetParent();

            if (not oCurrent or oCurrent:IsBeingDeleted() or not oCurrent:IsShown()) then
                return nil;
            end

            tBounds = intersect(tBounds, clientBounds(oCurrent));
        end

        local nDisplay = _wx.wxDisplay.GetFromWindow(oAnchor);
        local oDisplay = _wx.wxDisplay(nDisplay < 0 and 0 or nDisplay);
        local oArea = oDisplay:GetClientArea();
        tBounds = intersect(tBounds, {
            X = oArea:GetX(), Y = oArea:GetY(), Width = oArea:GetWidth(), Height = oArea:GetHeight()
        });
        oDisplay:delete();

        if (tBounds.Width < 1 or tBounds.Height < 1) then
            return nil;
        end

        return tBounds;
    end

    -- A shown native child can still be completely outside a scrolled viewport.
    -- Check actual clipped visibility before displaying content anchored to it.
    local function fAnchorVisible()
        if (oAnchor:IsBeingDeleted() or not oAnchor:IsShownOnScreen()) then
            return false;
        end

        local tVisible = clientBounds(oAnchor);
        local oCurrent = oAnchor;

        while (not oCurrent:IsTopLevel()) do
            oCurrent = oCurrent:GetParent();

            if (not oCurrent or oCurrent:IsBeingDeleted() or not oCurrent:IsShown()) then
                return false;
            end

            tVisible = intersect(tVisible, clientBounds(oCurrent));
        end

        return tVisible.Width > 0 and tVisible.Height > 0;
    end
    --[[!
    @fqxn wxLuma.UI.ControlContainment.place
    @desc Changes only popup position. Clamps each overflowing axis by the minimum
        distance needed. An oversized popup returns false under hide policy; allow
        aligns its oversized axis with the leading boundary and preserves size.
    @param wxWindow oPopup The already-sized floating native window.
    @param table|nil tPosition Desired screen X/Y; nil retains below-anchor placement.
    @ret boolean bPlaced Whether the popup can be displayed under current policy.
    !]]
    function tPolicy.place(oPopup, tPosition)
        if (not fAnchorVisible()) then
            return false;
        end

        local tBounds = oComponent.getContainmentBounds();

        if (not tBounds) then
            return false;
        end

        local nWidth, nHeight = oPopup:GetSizeWH();

        if ((nWidth > tBounds.Width or nHeight > tBounds.Height)
            and oComponent.getContainmentOverflow() == "hide") then
            return false;
        end

        local nDesiredX, nDesiredY;

        if (tPosition) then
            nDesiredX, nDesiredY = tPosition.X, tPosition.Y;
            assert(type(nDesiredX) == "number" and nDesiredX == nDesiredX and math.abs(nDesiredX) < math.huge
                and type(nDesiredY) == "number" and nDesiredY == nDesiredY and math.abs(nDesiredY) < math.huge,
                "Popup position must contain finite X/Y.");
        else
            local oPoint = oAnchor:ClientToScreen(_wx.wxPoint(0, 0));
            local _, nAnchorHeight = oAnchor:GetClientSizeWH();
            nDesiredX, nDesiredY = oPoint:GetX(), oPoint:GetY() + nAnchorHeight;
        end

        local nX = math.max(tBounds.X, math.min(nDesiredX, tBounds.X + math.max(0, tBounds.Width - nWidth)));
        local nY = math.max(tBounds.Y, math.min(nDesiredY, tBounds.Y + math.max(0, tBounds.Height - nHeight)));
        oPopup:SetPosition(_wx.wxPoint(nX, nY));
        return true;
    end
    --[[!
    @fqxn wxLuma.UI.ControlContainment.watch
    @desc Observes anchor/ancestor moves, resizes, visibility and destruction.
        Floating widgets reposition or dismiss themselves in the callback.
    @param function fCallback Receives move/size/show/destroy/policy.
    !]]
    function tPolicy.watch(fCallback)
        assert(not tPolicy.Observer, "Containment observer already registered.");
        tPolicy.Observer = fCallback;
        local oCurrent = oAnchor;

        while (oCurrent) do
            local nID = oCurrent:GetId();
            local tObserved = _tObservedWindows[nID];

            if (not tObserved) then
                tObserved = {Subscribers = setmetatable({}, {__mode = "k"})};
                _tObservedWindows[nID] = tObserved;

                -- wxLua Disconnect cannot identify an individual Lua callback.
                -- Share one handler per window/event and hold subscribers weakly
                -- so disposal never accumulates handlers retaining old popups.
                for _, tBinding in ipairs({
                    {_wx.wxEVT_MOVE, "move"}, {_wx.wxEVT_SIZE, "size"},
                    {_wx.wxEVT_SHOW, "show"}, {_wx.wxEVT_DESTROY, "destroy"}
                }) do
                    local sReason = tBinding[2];
                    oCurrent:Connect(tBinding[1], function(jEvent)
                        if (jEvent:GetId() == nID) then
                            for tSubscriber in pairs(tObserved.Subscribers) do
                                if (not tSubscriber.Dead and tSubscriber.Observer) then
                                    tSubscriber.Observer(sReason);
                                end
                            end

                            if (sReason == "destroy" and _tObservedWindows[nID] == tObserved) then
                                _tObservedWindows[nID] = nil;
                            end
                        end

                        jEvent:Skip();
                    end);
                end
            end

            tObserved.Subscribers[tPolicy] = true;
            tObservations[#tObservations + 1] = tObserved;

            if (oCurrent:IsTopLevel()) then
                break;
            end

            oCurrent = oCurrent:GetParent();
        end
    end
    local fDestroy = oComponent.destroy;
    oComponent.destroy = function()
        if (not tPolicy.Dead) then
            fDestroy();
            tPolicy.Dead = true;
            tPolicy.Observer = nil;

            for _, tObserved in ipairs(tObservations) do
                tObserved.Subscribers[tPolicy] = nil;
            end

            tObservations = {};

            if (_tPolicies[nControlID] == tPolicy) then
                _tPolicies[nControlID] = nil;
            end
        end
    end;
    oComponent.Control:Connect(_wx.wxEVT_DESTROY, function(jEvent)
        if (jEvent:GetId() == nControlID) then
            oComponent.destroy();
        end

        jEvent:Skip();
    end);
    oExplicit = fValidate(tOptions and tOptions.Containment);
    tPolicy.Explicit = oExplicit;
    tPolicy.Overflow = validateOverflow(tOptions and tOptions.ContainmentOverflow);
    return tPolicy;
end

--[[!
@fqxn wxLuma.UI.ControlContainment.getPolicy
@desc Retrieves internal placement/observation helpers for an attached component.
@param table oComponent The visual component.
@ret table tPolicy The private containment policy.
!]]
function ControlContainment.getPolicy(oComponent)
    return assert(_tPolicies[oComponent.Control:GetId()], "Component has no containment policy.");
end
return ControlContainment;