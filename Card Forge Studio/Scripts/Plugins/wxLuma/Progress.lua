local _Bar = require("wxLuma.Widgets.Progress");
local _Globe = require("wxLuma.Widgets.GlobeProgress");
local _Radial = require("wxLuma.Widgets.RadialProgress");
local _Circular = require("wxLuma.Widgets.CircularProgress");
local _Shape = require("wxLuma.Core.ControlShapeProgress");
local Progress = {};

Progress.Shape = {RECTANGLE = 0, CIRCLE = 1, POLYGON = 2};
Progress.Fill = {LINEAR = 0, RADIAL = 1, ANGULAR = 2};
Progress.Direction = {FORWARD = 0, REVERSE = 1};

--[[!
@fqxn wxLuma.Progress.direction
@desc Validates a numeric direction constant; zero is a real option, never an omitted default.
!]]
local function direction(nValue)
    assert(nValue == Progress.Direction.FORWARD or nValue == Progress.Direction.REVERSE, "Progress direction must be FORWARD (0) or REVERSE (1).");
    return nValue;
end

--[[!
@fqxn wxLuma.Progress.create
@desc <p>Creates a determinate progress/resource meter through one configurable
    entry point. Select a silhouette, a fill mode and independent fill/reserve
    directions. Rectangle, circle and simple polygon silhouettes support linear,
    radial and angular fill. Iris remains a separate animated-blade object.</p>

    <p>This interface selects its painter at construction; it does not replace
    every existing renderer with one implementation. Existing factories and their
    skin materials remain usable. Shape and FillMode cannot change on a live
    object. Polygon vertices, applicable geometry, direction, reserved capacity
    and value can change through their public setters.</p>

    <h3>Named numeric constants</h3>
    <p>Use <code>local P = oLuma.Progress</code> from a loaded framework instance.
    <code>P.create(parent, options)</code> uses the same configured factory as
    <code>oLuma.Controls.progress(parent, options)</code>. Zero is an explicit
    option value; it never means omitted, disabled or automatic.</p>
    <table>
      <thead><tr><th>Group</th><th>Constants</th></tr></thead>
      <tbody>
        <tr><td>Shape</td><td>RECTANGLE = 0; CIRCLE = 1; POLYGON = 2</td></tr>
        <tr><td>Fill</td><td>LINEAR = 0; RADIAL = 1; ANGULAR = 2</td></tr>
        <tr><td>Direction</td><td>FORWARD = 0; REVERSE = 1</td></tr>
      </tbody>
    </table>

    <h3>Fill and direction semantics</h3>
    <table>
      <thead><tr><th>FillMode</th><th>FORWARD</th><th>REVERSE</th><th>Progress measures</th></tr></thead>
      <tbody>
        <tr><td>LINEAR</td><td>Left to right horizontally; bottom to top vertically</td>
          <td>Right to left horizontally; top to bottom vertically</td><td>Distance along the selected axis</td></tr>
        <tr><td>RADIAL</td><td>Center outward</td><td>Outer region inward</td><td>Radial distance</td></tr>
        <tr><td>ANGULAR</td><td>Clockwise from StartAngle</td><td>Counterclockwise from StartAngle</td><td>Angular sweep</td></tr>
      </tbody>
    </table>
    <p>These are distance/sweep percentages, not filled-area percentages. A radial
    meter at half progress reaches half its usable radial distance. For polygon
    and rectangular radial/angular meters, the center is the silhouette's bounding-box
    center and the reference radius reaches its farthest vertex. Concave shapes
    need not contain their bounding-box center.</p>

    <h3>Construction options and defaults</h3>
    <table>
      <thead><tr><th>Option</th><th>Meaning and requirements</th></tr></thead>
      <tbody>
        <tr><td>Min, Max, Value</td><td>Required finite numbers; Min &lt; Max. Value clamps to usable capacity.</td></tr>
        <tr><td>Shape, FillMode</td><td>Named numeric constants. FillMode defaults to LINEAR.
          Without Shape, LINEAR selects RECTANGLE; RADIAL/ANGULAR select CIRCLE.</td></tr>
        <tr><td>Direction</td><td>Optional FORWARD/REVERSE. Omission retains the selected painter's defaults.
          Existing radial/angular direction strings remain accepted where applicable.</td></tr>
        <tr><td>Orientation, Origin</td><td>LINEAR only: horizontal/vertical and left/right/top/bottom.
          An explicit Origin infers its axis. Conflicting explicit options raise an error.
          The circular globe defaults to vertical/bottom; bars and polygons default to horizontal/left.</td></tr>
        <tr><td>Polygon</td><td>Required for POLYGON: a dense array of 3..64 normalized {X,Y} vertices.
          Each coordinate is in 0..1. Convex/concave simple polygons are accepted;
          zero area, zero-length/overlapping edges, sparse arrays and self-intersections are rejected.</td></tr>
        <tr><td>Reserved</td><td>Capacity units in 0..(Max - Min); default 0. Independent of current value.</td></tr>
        <tr><td>ReserveDirection</td><td>Optional numeric FORWARD/REVERSE, independently mapped for the fill mode.
          Existing inward/outward or CW/CCW strings remain available on their corresponding modes.</td></tr>
        <tr><td>ReserveOrigin</td><td>LINEAR only: independently reserve from left/right/top/bottom.
          Use this for perpendicular cuts. Do not combine a conflicting ReserveOrigin with numeric ReserveDirection.</td></tr>
        <tr><td>StartAngle, ReserveStartAngle</td><td>ANGULAR only: finite degrees, normalized modulo 360.
          Zero is twelve o'clock, 90 right, 180 bottom, 270 left. StartAngle defaults to 0.
          A nil ReserveStartAngle follows the current StartAngle; an explicit value is independent.</td></tr>
        <tr><td>InnerRadius, OuterRadius</td><td>RADIAL/ANGULAR percentage bands satisfying
          0 &lt;= inner &lt; outer &lt;= 100. Outer defaults to 100; explicit inner 0 permits a solid pie.</td></tr>
        <tr><td>Thickness</td><td>ANGULAR pixel thickness. Existing circular arcs default to 12 pixels
          when no percentage radii are supplied. New polygon/rectangular angular silhouettes
          default to solid fill unless Thickness or radii are supplied. Explicit radii take precedence.</td></tr>
        <tr><td>Appearance, Colour</td><td>Appearance is skin or colour. Colour uses R/G/B channels in 0..255.
          The original rectangular bar defaults to colour; the other painters default to skin
          unless an explicit Colour selects colour mode.</td></tr>
        <tr><td>Skin, Theme, Artwork</td><td>Use the framework's configured appearance or an explicit provider.
          Artwork overrides the material prefix. Track/Fill and, when reserved, Reserve materials
          remain anchored to the full meter rather than sliding with its fill.</td></tr>
        <tr><td>Text</td><td>Default %v / %m; %v expands current value and %m the total Max.
          Use an empty string to hide text. Text does not substitute effective Max automatically.</td></tr>
        <tr><td>Outline, OutlineColour, OutlineWidth</td><td>Outer silhouette outline; enabled by default,
          width 2 pixels, supported width 1..8. OutlineColour is optional R/G/B.
          Outline and the native Border are independent.</td></tr>
        <tr><td>Supersampling</td><td>2 or 4 for globe/radial discs and polygon/rectangular radial/angular painters.
          Disc default is 4; new shape-painter default is 2. Existing circular arcs retain their fixed 4x painter.
          Higher sampling increases work and buffer size; it is not an animation-speed setting.</td></tr>
        <tr><td>ReserveRenderer</td><td>Globe/radial discs accept auto, native or strips.
          Polygon/rectangular radial/angular painters accept auto or strips; disc-only native reservation
          is rejected explicitly for these silhouettes. Existing bars and arcs retain their own reserve paths.</td></tr>
        <tr><td>Enabled, OnChange, containment options</td><td>Retain the normal visual-surface contract.
          The meter does not advance itself or bind user input to its value.</td></tr>
      </tbody>
    </table>

    <h3>Reserved capacity and overlapping paths</h3>
    <p><code>getMax()</code> returns total Max. <code>getEffectiveMax()</code> returns
    <code>Max - Reserved</code>. Increasing Reserved clamps current immediately;
    decreasing it does not resurrect discarded current. A fully reserved range
    holds Value at Min and reports <code>isFull()</code> because no usable capacity remains.</p>
    <p>Current and reserve are disjoint even when their independently selected paths
    overlap. Current advances through the usable part of its path. Automatic reserve
    placement uses the opposite edge/direction; an automatic angular reserve start
    follows StartAngle. Perpendicular linear cuts use the remaining silhouette's
    projected extent. Reserving capacity is not simply drawing a translucent region
    on top of current.</p>

    <h3>Runtime methods, notifications and state</h3>
    <ul>
      <li>getShape() / getFillMode() return construction selections; there are no live shape/mode setters.</li>
      <li>getValue() / setValue(value, notify), getReserved() / setReserved(amount, notify),
        getMax(), getEffectiveMax() and isFull() share the capacity contract above.</li>
      <li>getFillDirection() / setFillDirection(number, notify) use the numeric constants.</li>
      <li>getReserveFillDirection() / setReserveFillDirection(numberOrNil, notify) use the same constants.
        Nil restores automatic placement. A perpendicular linear reserve getter returns nil followed
        by its explicit edge as a second result; getReserveOrigin() retains the full edge value.</li>
      <li>Mode-specific APIs remain available: get/setOrigin and get/setOrientation for linear fill;
        get/setDirection with inward/outward or CW/CCW for radial/angular fill;
        get/setRadii for radial/angular bands; get/setStartAngle and get/setReserveStartAngle for arcs.</li>
      <li>Polygon meters provide detached getPolygon() and validated setPolygon(vertices, notify).
        Applicable appearance, supersampling and reserve-renderer getters/setters remain available.</li>
      <li>Setters are silent unless notify is true. Effective value changes invoke
        OnChange(value, component) and valueChanged. Reserve trimming notifies the value change
        before reservedChanged. Geometry/appearance events retain their existing string payloads;
        the numeric adapter does not rename those payloads.</li>
      <li>Relevant events include reservedChanged, reserveOriginChanged, reserveDirectionChanged,
        reserveStartAngleChanged, radiiChanged, originChanged, orientationChanged, directionChanged,
        startAngleChanged, appearanceChanged, supersamplingChanged, reserveRendererChanged and
        polygonChanged, where the selected painter exposes that setting.</li>
      <li>getObjectState() / setObjectState(snapshot) restore existing matching objects silently,
        including applicable polygon vertices, value, reserve and mutable geometry. They do not
        create controls, change shape/mode or serialize callbacks. Native ownership stays with the parent;
        destroy() releases meter-owned rasters and other resources.</li>
    </ul>

    <h3>Examples</h3>
    <p>All examples below share this setup. Supply an existing native window as oParent.
    They create real controls; the application still owns layout and the wx event loop.</p>
    <pre><code class="language-lua">
    local oLuma = require("wxLuma")();
    local P = oLuma.Progress;
    local Controls = oLuma.Controls;
    </code></pre>

    <h4>1. Bar with nonzero minimum and reserved capacity</h4>
    <pre><code class="language-lua">
    local oBar = Controls.progress(oParent, {
        Shape = P.Shape.RECTANGLE, FillMode = P.Fill.LINEAR,
        Direction = P.Direction.FORWARD,
        Min = 10, Max = 110, Value = 80, Reserved = 25,
        Text = "%v / %m",
    });
    oBar.layout(16, 16, 260, 36);
    oBar.setValue(110, true);             -- Accepted value is 85, not 110.
    assert(oBar.getEffectiveMax() == 85);
    assert(oBar.getValue() == 85);
    </code></pre>

    <h4>2. Top-down globe with a perpendicular reserve</h4>
    <pre><code class="language-lua">
    local oGlobe = Controls.progress(oParent, {
        Shape = P.Shape.CIRCLE, FillMode = P.Fill.LINEAR,
        Orientation = "vertical", Direction = P.Direction.REVERSE,
        ReserveOrigin = "left", Reserved = 30,
        Min = 0, Max = 100, Value = 50,
    });
    oGlobe.layout(300, 16, 140, 140);
    local nReserveDirection, sReserveEdge = oGlobe.getReserveFillDirection();
    assert(nReserveDirection == nil and sReserveEdge == "left");
    oGlobe.setFillDirection(P.Direction.FORWARD, true); -- Now bottom-up.
    oGlobe.setReserveFillDirection(nil, true);         -- Automatic opposite edge.
    </code></pre>

    <h4>3. Inward radial fill with outward reserve and a percentage band</h4>
    <pre><code class="language-lua">
    local oRadial = Controls.progress(oParent, {
        Shape = P.Shape.CIRCLE, FillMode = P.Fill.RADIAL,
        Direction = P.Direction.REVERSE,
        ReserveDirection = P.Direction.FORWARD,
        InnerRadius = 25, OuterRadius = 90,
        Min = 0, Max = 100, Value = 65, Reserved = 20,
        Supersampling = 2, ReserveRenderer = "auto",
    });
    oRadial.layout(460, 16, 140, 140);
    oRadial.setRadii(15, 95, true);
    </code></pre>

    <h4>4. Arc with independent reserve angle, then switch its band to a pie</h4>
    <pre><code class="language-lua">
    local oArc = Controls.progress(oParent, {
        Shape = P.Shape.CIRCLE, FillMode = P.Fill.ANGULAR,
        Direction = P.Direction.FORWARD, StartAngle = 270,
        ReserveDirection = P.Direction.REVERSE, ReserveStartAngle = 90,
        Thickness = 12, Min = 0, Max = 100, Value = 55, Reserved = 25,
    });
    oArc.layout(620, 16, 140, 140);
    oArc.setReserveStartAngle(45, true);  -- Reserve begins at 45 degrees.
    oArc.setRadii(0, 100, true);          -- Solid pie, same angular policies.
    oArc.setRadii(nil, nil, true);        -- Restore pixel Thickness geometry.
    oArc.setReserveStartAngle(nil, true); -- Follow the current StartAngle again.
    </code></pre>

    <h4>5. Concave polygon with inward fill and outward reserve</h4>
    <pre><code class="language-lua">
    local oPolygon = Controls.progress(oParent, {
        Shape = P.Shape.POLYGON, FillMode = P.Fill.RADIAL,
        Polygon = {
            {X = 0, Y = 0}, {X = 1, Y = 0}, {X = 0.6, Y = 0.5},
            {X = 1, Y = 1}, {X = 0, Y = 1}, {X = 0.3, Y = 0.5},
        },
        Direction = P.Direction.REVERSE, ReserveDirection = P.Direction.FORWARD,
        Min = 0, Max = 100, Value = 60, Reserved = 20,
        Appearance = "colour", Colour = {R = 65, G = 140, B = 210},
        Outline = true, OutlineWidth = 2, Supersampling = 2,
        ReserveRenderer = "strips",
    });
    oPolygon.layout(16, 180, 220, 160);
    </code></pre>

    <h4>6. Angular sweep clipped to a rectangle</h4>
    <pre><code class="language-lua">
    local oRectangleSweep = P.create(oParent, {
        Shape = P.Shape.RECTANGLE, FillMode = P.Fill.ANGULAR,
        Direction = P.Direction.REVERSE, StartAngle = 45,
        ReserveDirection = P.Direction.FORWARD, ReserveStartAngle = 180,
        InnerRadius = 0, OuterRadius = 100,
        Min = 0, Max = 100, Value = 45, Reserved = 10,
    });
    oRectangleSweep.layout(260, 180, 220, 160);
    </code></pre>

    <h4>7. Observe changes and restore an existing polygon's state</h4>
    <pre><code class="language-lua">
    oPolygon.on("valueChanged", function(oSource, tEvent)
        assert(oSource.getValue() == tEvent.Value);
        -- Update application state here; tEvent.OldValue is the previous value.
    end);
    local tSaved = oPolygon.getObjectState();
    oPolygon.setReserved(100, true);      -- No usable capacity remains.
    assert(oPolygon.getValue() == 0);
    oPolygon.setReserved(0, true);        -- Removing reserve keeps current at 0.
    assert(oPolygon.getValue() == 0);
    oPolygon.setObjectState(tSaved);      -- Restores saved current/reserve/vertices.
    assert(oPolygon.getValue() == 60 and oPolygon.getReserved() == 20);
    </code></pre>

    <h3>Rendering cost and test location</h3>
    <p>Unchanged output reuses the final raster. Polygon/rectangular mask painters
    also cache polygon scanlines, the fixed track/reserve layer and work buffers;
    value-only updates paint current only within cached usable spans. Changing size,
    silhouette, reserve geometry/amount, sampling, theme or relevant appearance
    rebuilds the corresponding caches. Sampling 2 is the lower-cost antialiased
    setting; sampling 4 increases resolution and work. Neither changes fill semantics.</p>
    <p>Restart Win/test.exe and open Resources. Unified progress compares the numeric
    interface with original controls; Polygon progress adds convex/concave silhouettes,
    independent reserve directions, bands and fill/reserve angle selectors. Dox examples
    describe supported finite options; they do not claim every real-valued coordinate
    or angle has been enumerated. Image-alpha silhouettes and arbitrary linear fill
    angles are not implemented by this interface.</p>
@param wxWindow oParent Native parent.
@param table tOptions Existing progress options plus Shape (RECTANGLE/CIRCLE/POLYGON),
    Polygon (3..64 normalized {X,Y} vertices for POLYGON),
    FillMode (LINEAR/RADIAL/ANGULAR), optional numeric Direction and ReserveDirection.
    Linear FORWARD starts left for horizontal or bottom for vertical; radial
    FORWARD is outward, angular FORWARD is clockwise. REVERSE selects the opposite.
@ret table oComponent Existing painter with getShape/getFillMode and numeric
    get/setFillDirection, get/setReserveFillDirection. Legacy geometry APIs remain available.
!]]
function Progress.create(oParent, tOptions)
    tOptions = tOptions or {};
    local bUnified = tOptions.Shape ~= nil or tOptions.FillMode ~= nil or type(tOptions.Direction) == "number"
        or type(tOptions.ReserveDirection) == "number";
    if (not bUnified) then return _Bar.create(oParent, tOptions); end

    local nMode = tOptions.FillMode == nil and Progress.Fill.LINEAR or tOptions.FillMode;
    assert(nMode == Progress.Fill.LINEAR or nMode == Progress.Fill.RADIAL or nMode == Progress.Fill.ANGULAR, "Invalid progress FillMode.");
    local nShape = tOptions.Shape;
    if (nShape == nil) then nShape = nMode == Progress.Fill.LINEAR and Progress.Shape.RECTANGLE or Progress.Shape.CIRCLE; end
    assert(nShape == Progress.Shape.RECTANGLE or nShape == Progress.Shape.CIRCLE or nShape == Progress.Shape.POLYGON, "Invalid progress Shape.");
    local tNext = {};
    for sKey, vValue in pairs(tOptions) do tNext[sKey] = vValue; end
    tNext.Shape, tNext.FillMode = nil, nil;

    -- Linear direction follows the selected axis; Origin still describes an edge.
    local bVertical = tOptions.Orientation == "vertical" or (tOptions.Orientation == nil
        and (tOptions.Origin == "top" or tOptions.Origin == "bottom" or nShape == Progress.Shape.CIRCLE and tOptions.Origin == nil));
    local sForward, sReverse;
    if (nMode == Progress.Fill.LINEAR) then
        sForward, sReverse = bVertical and "bottom" or "left", bVertical and "top" or "right";
        if (tOptions.Direction ~= nil) then
            local sOrigin = direction(tOptions.Direction) == 0 and sForward or sReverse;
            assert(tOptions.Origin == nil or tOptions.Origin == sOrigin, "Direction conflicts with Origin.");
            tNext.Origin = sOrigin;
        end
        tNext.Direction = nil;
        if (tOptions.ReserveDirection ~= nil) then
            local sOrigin = direction(tOptions.ReserveDirection) == 0 and sForward or sReverse;
            assert(tOptions.ReserveOrigin == nil or tOptions.ReserveOrigin == sOrigin, "ReserveDirection conflicts with ReserveOrigin.");
            tNext.ReserveOrigin, tNext.ReserveDirection = sOrigin, nil;
        end
    else
        sForward, sReverse = nMode == Progress.Fill.RADIAL and "outward" or "CW", nMode == Progress.Fill.RADIAL and "inward" or "CCW";
        assert(tOptions.Direction == nil or type(tOptions.Direction) == "number"
            or tOptions.Direction == sForward or tOptions.Direction == sReverse, "Invalid progress Direction for FillMode.");
        if (type(tOptions.Direction) == "number") then tNext.Direction = direction(tOptions.Direction) == 0 and sForward or sReverse; end
        if (type(tOptions.ReserveDirection) == "number") then tNext.ReserveDirection = direction(tOptions.ReserveDirection) == 0 and sForward or sReverse; end
    end
    local fCreate = nMode == Progress.Fill.ANGULAR and _Circular.create or nMode == Progress.Fill.RADIAL and _Radial.create
        or nShape == Progress.Shape.CIRCLE and _Globe.create or _Bar.create;
    local oComponent;
    if (nShape == Progress.Shape.POLYGON or nShape == Progress.Shape.RECTANGLE and nMode ~= Progress.Fill.LINEAR) then
        oComponent = _Shape.create(oParent, tNext, nShape, nMode);
    else oComponent = fCreate(oParent, tNext); end

    --[[!
    @fqxn wxLuma.Progress.getShape
    @desc Returns the numeric silhouette selected at construction.
    !]]
    function oComponent.getShape() return nShape; end

    --[[!
    @fqxn wxLuma.Progress.getFillMode
    @desc Returns the numeric fill mode selected at construction.
    !]]
    function oComponent.getFillMode() return nMode; end

    --[[!
    @fqxn wxLuma.Progress.setFillDirection
    @desc Maps the shared numeric direction to the active painter. Existing
        origin/orientation/direction events retain their original payload contracts.
    !]]
    function oComponent.setFillDirection(nDirection, bNotify)
        direction(nDirection);
        if (nMode == Progress.Fill.LINEAR) then
            local bUp = oComponent.getOrientation() == "vertical";
            oComponent.setOrigin(nDirection == 0 and (bUp and "bottom" or "left") or (bUp and "top" or "right"), bNotify);
        else oComponent.setDirection(nDirection == 0 and sForward or sReverse, bNotify); end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.Progress.getFillDirection
    @desc Returns FORWARD/REVERSE from current geometry, including legacy setter changes.
    !]]
    function oComponent.getFillDirection()
        local sValue = nMode == Progress.Fill.LINEAR and oComponent.getOrigin() or oComponent.getDirection();
        return (sValue == "left" or sValue == "bottom" or sValue == "outward" or sValue == "CW") and 0 or 1;
    end

    --[[!
    @fqxn wxLuma.Progress.setReserveFillDirection
    @desc Maps independent reserve direction; nil restores the painter's automatic policy.
    !]]
    function oComponent.setReserveFillDirection(nDirection, bNotify)
        if (nDirection ~= nil) then direction(nDirection); end
        local sValue;
        if (nMode == Progress.Fill.LINEAR) then
            local bUp = oComponent.getOrientation() == "vertical";
            if (nDirection ~= nil) then sValue = nDirection == 0 and (bUp and "bottom" or "left") or (bUp and "top" or "right"); end
            oComponent.setReserveOrigin(sValue, bNotify);
        else
            if (nDirection ~= nil) then sValue = nDirection == 0 and sForward or sReverse; end
            oComponent.setReserveDirection(sValue, bNotify);
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.Progress.getReserveFillDirection
    @desc Returns configured numeric reserve direction, or nil for automatic placement.
        A perpendicular linear reserve returns nil followed by its explicit edge;
        getReserveOrigin always retains the full legacy geometry.
    !]]
    function oComponent.getReserveFillDirection()
        local sValue;
        if (nMode == Progress.Fill.LINEAR) then sValue = oComponent.getReserveOrigin();
        else sValue = oComponent.getReserveDirection(); end
        if (sValue == nil) then return nil; end
        if (nMode == Progress.Fill.LINEAR) then
            local bUp = oComponent.getOrientation() == "vertical";
            if (bUp and (sValue == "left" or sValue == "right") or not bUp and (sValue == "top" or sValue == "bottom")) then return nil, sValue; end
        end
        return (sValue == "left" or sValue == "bottom" or sValue == "outward" or sValue == "CW") and 0 or 1;
    end
    return oComponent;
end

return Progress;
