                                                                                    --[[
                                                                                    ██╗   ██╗███████╗███████╗██████╗ ███████╗███╗   ██╗██╗   ██╗
                                                                                    ██║   ██║██╔════╝██╔════╝██╔══██╗██╔════╝████╗  ██║██║   ██║
                                                                                    ██║   ██║███████╗█████╗  ██████╔╝█████╗  ██╔██╗ ██║██║   ██║
                                                                                    ██║   ██║╚════██║██╔══╝  ██╔══██╗██╔══╝  ██║╚██╗██║╚██╗ ██╔╝
                                                                                    ╚██████╔╝███████║███████╗██║  ██║███████╗██║ ╚████║ ╚████╔╝
                                                                                     ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝  ╚═══╝
                                                                                    ]]
--[[!
@fqxn CFS.UserEnv
@todo Add Style class to UserEnv
@desc
<div class="mb-4">

  <div class="d-flex align-items-center mb-3">
    <div style="width:6px;height:36px;background:#4dd0e1;border-radius:3px;" class="me-3"></div>
    <h2 class="mb-0 fw-bold">UserEnv</h2>
  </div>

  <p>
    <strong>UserEnv</strong> defines the controlled execution environment for CardSet
    <code>Draw</code> scripts and other user-authored code. It exposes a curated,
    read-only API surface composed of drawing utilities, math helpers, randomness,
    geometry functions, and engine-provided services, while preventing direct mutation
    of engine state.
  </p>

  <hr class="border-secondary">

  <h3 class="fw-semibold">Design</h3>
  <ul>
    <li>UserEnv is a <em>decoy environment</em> backed by internal engine tables.</li>
    <li>All exposed tables are read-only via metatables.</li>
    <li>Write attempts to injected namespaces raise errors.</li>
    <li>Actual backing tables are tracked separately for introspection.</li>
  </ul>

  <h3 class="fw-semibold">Exposed Namespaces</h3>
  <ul>
    <li>Rendering and drawing facilities used during card and asset composition.</li>
    <li>Color construction, conversion, and blending utilities for visual output.</li>
    <li>Mathematical helpers extending the standard language primitives.</li>
    <li>String and table helpers for validation, transformation, and structural work.</li>
    <li>Geometric utilities for layout, bounds checking, and spatial reasoning.</li>
    <li>Randomization helpers intended for deterministic or controlled variation.</li>
    <li>Read-only configuration data scoped to the active game.</li>
    <li>Session-scoped storage managed by the IDE for transient state.</li>
    <li>Encoding utilities for safely representing binary data as text.</li>
  </ul>

  <h3 class="fw-semibold">Dynamic Injection</h3>
  <ul>
    <li>Additional namespaces may be injected or replaced at runtime by the IDE.</li>
    <li><code>ProcSysUpdateRoot</code> updates ProcSys-provided bindings.</li>
    <li><code>UserUpdateRoot</code> updates user/session bindings.</li>
    <li>Injected keys are tracked and safely replaced on refresh.</li>
  </ul>

  <h3 class="fw-semibold">Introspection</h3>
  <ul>
    <li><code>UserEnv.Get()</code> returns the active execution environment table.</li>
    <li>
      <code>UserEnv.GetCommandList()</code> returns a sorted list of callable API paths
      (e.g. <code>Forge.DrawImage</code>, <code>math.abs</code>).
    </li>
  </ul>

  <h3 class="fw-semibold">Safety Guarantees</h3>
  <ul>
    <li>No direct access to engine internals or mutable state.</li>
    <li>All exposed namespaces are read-only.</li>
    <li>Only explicitly injected APIs are visible.</li>
    <li>Backing tables are weakly referenced to avoid lifetime leaks.</li>
  </ul>

  <h3 class="fw-semibold">Notes</h3>
  <ul>
    <li>UserEnv is constructed and maintained by the IDE, not by user scripts.</li>
    <li>User scripts should treat all exposed tables as immutable.</li>
  </ul>

</div>
!]]
local tEnv = { --TODO QUESTION do i need to protect this?
    --[[!
    @fqxn CFS.UserEnv.ipairs
    @desc Returns an iterator that traverses a table by increasing integer keys, starting at index 1 and continuing until a nil value is encountered. Intended for array-like tables.
    @example
    local t = { "a", "b", "c" }
    for i, v in ipairs(t) do
        print(i, v)
    end
    !]]
    ipairs           = ipairs,
    --[[!
    @fqxn CFS.UserEnv.pairs
    @desc Returns an iterator that visits all key–value pairs in a table. The traversal order is unspecified and should not be relied upon.
    @example
    local t = { x = 10, y = 20 }
    for k, v in pairs(t) do
        print(k, v)
    end
    !]]
    pairs            = pairs,
    --[[!
    @fqxn CFS.UserEnv.tonumber
    @desc Attempts to convert its argument to a number. If the conversion is not possible, it returns nil. An optional base may be supplied for string conversion.
    @example
    local n = tonumber("10")
    local h = tonumber("FF", 16)
    !]]
    tonumber         = tonumber,
    --[[!
    @fqxn CFS.UserEnv.tostring
    @desc Converts a value to its human-readable string form. This function never fails and always returns a string.
    @example
    local s = tostring(123)
    print(s)
    !]]
    tostring         = tostring,
    --[[!
    @fqxn CFS.UserEnv.type
    @desc Returns a string describing the type of its argument, such as "number", "string", or "table".
    @example
    print(type(42))        -- "number"
    print(type({}))        -- "table"
    !]]
    type             = rawtype,
    --[[!
    @fqxn CFS.UserEnv.p
    @desc An alias of <a href="#CFS.UserEnv.print">print</a>
    @inheritdoc CFS.UserEnv.print
    !]]
    p                = p,
    --[[!
    @fqxn CFS.UserEnv.print
    @desc Outputs a textual representation of its arguments, separated by tabs and followed by a newline.
    @example
    print("hello", 123, true)
    !]]
    print            = p,
    --[[!
    @fqxn CFS.UserEnv.serialize
    @desc Serializes a Lua value into a Lua-expression string that can later be reconstructed using the deserializer. Supported primitive types are emitted directly, while registered or metatable-enabled objects are encoded in a packed form. Tables are walked recursively, preserving structure and detecting circular references.
    @param any vInput The value to serialize.
    @ret string sSerialized Lua expression representing the serialized value.
    @example
    local tConfigData = {
        Width  = 1920;
        Height = 1080;
        Title  = "Example";
    };
    local sSerializedConfig = serialize(tConfigData)
    !]]
    serialize        = serialize,
    --[[!
    @fqxn CFS.UserEnv.deserialize
    @desc Reconstructs a Lua value from a serialized Lua-expression string produced by serialize. The input string is executed in a controlled manner to recreate the original value, including complex tables and registered object types.
    @param string sRawData Serialized Lua expression.
    @ret any vResult Deserialized Lua value.
    @example
    local sSerializedConfig = "{ [\"Width\"] = 1920, [\"Height\"] = 1080 }"
    local tConfigData = deserialize(sSerializedConfig)
    !]]
    deserialize      = deserialize,
    --[[!
    @fqxn CFS.UserEnv.select
    @desc Provides access to variable argument lists. Can be used to count arguments or extract values by position.
    @example
    local a, b = select(1, "x", "y", "z");
    local n    = select("#", "x", "y", "z");
    !]]
    select           = select,
    --Forge            = tForgeDecoy,
    --ProcSys          = tProcSysDecoy,
    --TODO FINISH this function and add Dox Note (update it with Game load)
    Exists           = function(sPath)
        --TextFile.DoesExist
    end,
    Log              = Log.Note,
    --[[!
    @fqxn CFS.UserEnv.Import
    @desc
    Loads and executes a Lua file from within the active game's directory, then returns the chunk results.

    The import path is treated as a relative path rooted at the user's currently active game (the game’s root folder). Absolute paths and traversal are rejected. The file is read as text, compiled with the UserEnv execution environment, and run protected so errors can be returned instead of crashing the caller.

    All code inside the imported file is executed sandboxed within the UserEnv. The file has access only to the APIs explicitly exposed by the user environment, ensuring imported code cannot escape or access unsafe globals.
    @param string sPathRaw Relative path to a Lua file inside the active game (for example: "Scripts/MyModule.lua").
    @param any vMessage Optional extra text appended to error output.
    @ret any ... On success, returns whatever values the imported file returns.
    @ret nil On failure, returns nil as the first result.
    @ret string sError On failure, returns an error message as the second result.
    @example
    local vModule = Import("Scripts/MyModule.lua");
    !]]
    Import           = Import,
    ---
    --User             = {}, --from Init
    --[[!
    @fqxn CFS.UserEnv.Uptime
    @desc
    <p>Returns the number of seconds elapsed since the UserEnv (sandbox) was created.
    <br><br>
    This value is relative, not wall-clock time. It does not expose system time,
    timezone, or date information, and is safe for use inside restricted or sandboxed
    environments. The uptime origin cannot be reset or modified by sandboxed code.
    Although the various random functions in the environment have already been seeded with
    pseudo-random values, this value can be used for additional random seeding if desired.
    </p>
    @ret number nSeconds Elapsed time in seconds since the UserEnv was initialized.
    @example
    local nUptime = Uptime();
!]]
    Uptime           = function()
        return os.time() - SANDBOX_TIME_START;
    end,
};

-- decoy -> real backing table map (weak keys so nothing is kept alive)
local tEnvBacking = setmetatable({}, { __mode = "k" })

local function InjectEnv(sName, tActual)

    if not (rawtype(sName) == "string" and not sName:isempty()) then
        error("InjectEnv: sName must be non-empty string. Got " .. rawtype(sName) .. ".", 2);
    end

    if (rawtype(tActual) ~= "table") then
        error("InjectEnv: tActual must be table. Got " .. rawtype(tActual) .. ".", 2);
    end

    local tDecoy = {};

    -- map decoy -> actual (for command listing)
    tEnvBacking[tDecoy] = tActual;

    -- create meta
    local tMeta = {
        __index = tActual,
        __newindex = function()
            error("Attempt to write to read-only '" .. sName .. "'.", 2);
        end,
        --__metatable = false,
    }

    -- apply read-only decoy metatable
    setmetatable(tDecoy, tMeta);

    -- 3) Inject into env
    tEnv[sName] = tDecoy;
    return tDecoy, tMeta;
end


                                                                            --[[
                                                                            ██████╗  █████╗ ███████╗███████╗ ██████╗ ██╗  ██╗
                                                                            ██╔══██╗██╔══██╗██╔════╝██╔════╝██╔════╝ ██║  ██║
                                                                            ██████╔╝███████║███████╗█████╗  ███████╗ ███████║
                                                                            ██╔══██╗██╔══██║╚════██║██╔══╝  ██╔═══██╗╚════██║
                                                                            ██████╔╝██║  ██║███████║███████╗╚██████╔╝     ██║
                                                                            ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝ ╚═════╝      ╚═╝
                                                                            ]]
--[[!
@fqxn CFS.UserEnv.base64
@desc
<div class="mb-4">

  <div class="d-flex align-items-center mb-3">
    <div style="width:6px;height:36px;background:#e57373;border-radius:3px;" class="me-3"></div>
    <h2 class="mb-0 fw-bold">base64</h2>
  </div>

  <p>
    Provides Base64 encoding and decoding utilities for working with binary data
    in a text-safe form.
  </p>

  <p>
    This namespace is primarily used for serialization, persistence, and transport
    of data such as bytecode, packed structures, or other binary blobs that must be
    represented as strings. Encoded values can be decoded back to their original
    binary form without loss.
  </p>

</div>
!]]
InjectEnv("base64", {
    --[[!
    @fqxn CFS.UserEnv.base64.enc
    @desc Encodes a string to Base64.
    @param string sInput The sting to encode.
    @ret string sEncoded The encoded Base64 string.
    @ex
    local sText     = "I really like apples but only the glowing, purple ones.";
    local sEncoded  = base64.enc(sText);
    print(sEncoded) --> SSByZWFsbHkgbGlrZSBhcHBsZXMgYnV0IG9ubHkgdGhlIGdsb3dpbmcsIHB1cnBsZSBvbmVzLg==
    !]]
    dec = base64.dec,
    --[[!
    @fqxn CFS.UserEnv.base64.dec
    @desc Encodes a string to Base64.
    @param string sInput The sting to encode.
    @ret string sEncoded The encoded Base64 string.
    @ex
    local sText     = "I really like apples but only the glowing, purple ones.";
    local sEncoded  = base64.enc(sText);
    print(sEncoded) --> SSByZWFsbHkgbGlrZSBhcHBsZXMgYnV0IG9ubHkgdGhlIGdsb3dpbmcsIHB1cnBsZSBvbmVzLg==
    local sDecoded  = base64.dec(sEncoded);
    print(sDecoded) --> I really like apples but only the glowing, purple ones.
    print (sText == sDecoded) --> true
    !]]
    enc = base64.enc,
});

                                                                            --[[
                                                                            ██████╗ ██████╗ ██╗      ██████╗ ██████╗
                                                                            ██╔════╝██╔═══██╗██║     ██╔═══██╗██╔══██╗
                                                                            ██║     ██║   ██║██║     ██║   ██║██████╔╝
                                                                            ██║     ██║   ██║██║     ██║   ██║██╔══██╗
                                                                            ╚██████╗╚██████╔╝███████╗╚██████╔╝██║  ██║
                                                                            ╚═════╝ ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═╝
                                                                            ]]
--[[!
@fqxn CFS.UserEnv.Color
@desc
<div class="mb-4">

  <div class="d-flex align-items-center mb-3">
    <div style="width:6px;height:36px;background:#81c784;border-radius:3px;" class="me-3"></div>
    <h2 class="mb-0 fw-bold">Color</h2>
  </div>

  <p>
    Provides color construction, conversion, and manipulation utilities for drawing
    and UI workflows.
  </p>

  <p>
    This module supports 24-bit RGB and 32-bit RGBA color values, channel extraction
    and mutation, alpha blending and mixing, gradient calculation, and hexadecimal
    conversions. All functions return numeric color values compatible with drawing
    operations exposed by the environment.
  </p>

  <hr class="border-secondary">

  <dl class="row mb-0">
    <dt class="col-sm-3 text-muted">Author</dt>
    <dd class="col-sm-9">Imagine Programming &lt;Bas Groothedde&gt;</dd>

    <dt class="col-sm-3 text-muted">Web</dt>
    <dd class="col-sm-9">
      <a href="http://www.imagine-programming.com" class="link-info">
        http://www.imagine-programming.com
      </a>
    </dd>

    <dt class="col-sm-3 text-muted">Contact</dt>
    <dd class="col-sm-9">contact\@imagine-programming.com</dd>

    <dt class="col-sm-3 text-muted">Copyright</dt>
    <dd class="col-sm-9">© Imagine Programming, 2024.</dd>
  </dl>

</div>
!]]
InjectEnv("Color", {
    --[[!
    @fqxn CFS.UserEnv.Color.AlphaBlend
    @desc
    Blends two 32-bit RGBA color values together while preserving their alpha channels. The second color is composited over the first color, producing a new combined color.
    @param number Color1 A base color value, typically created with Color.RGBA.
    @param number Color2 A second color value, also created with Color.RGBA, which is blended on top of Color1.
    @ret number Returns a new 32-bit color value representing the blended result.
    @example
    local nBlendedColor = Color.AlphaBlend(nBaseColor, nOverlayColor)
    !]]
    AlphaBlend         = Color.AlphaBlend,
    --[[!
    @fqxn CFS.UserEnv.Color.AlphaMix
    @desc
    Mixes two 32-bit RGBA color values together while preserving alpha information. The resulting color is blended using an explicit alpha value, allowing control over how transparency is applied in the mix.
    @param number Color1 A base color value, typically created with Color.RGBA.
    @param number Color2 A second color value, also created with Color.RGBA, mixed on top of Color1.
    @param number Alpha The alpha value to apply during mixing, usually sourced from an existing color.
    @ret number Returns a new 32-bit color value representing the mixed result.
    @example
    local nMixedColor = Color.AlphaMix(nPrimaryColor, nSecondaryColor, Color.GetAlpha(nReferenceColor))
    !]]
    AlphaMix           = Color.AlphaMix,
    --[[!
    @fqxn CFS.UserEnv.Color.GetAlpha
    @desc
    Extracts the alpha channel from a 32-bit RGBA color value, allowing inspection of the transparency component.
    @param number Color A numeric color value created with Color.RGBA.
    @ret number Returns the alpha channel value, ranging from 0 to 255.
    @example
    local nAlphaValue = Color.GetAlpha(nColor)
    !]]
    GetAlpha           = Color.GetAlpha,
    --[[!
    @fqxn CFS.UserEnv.Color.GetBlue
    @desc
    Extracts the blue channel from a 24-bit or 32-bit color value, allowing inspection of the original color components.
    @param number Color A numeric color value created with Color.RGB or Color.RGBA.
    @ret number Returns the blue channel value, ranging from 0 to 255.
    @example
    local nBlueValue = Color.GetBlue(nColor)
    !]]
    GetBlue            = Color.GetBlue,
    --[[!
    @fqxn CFS.UserEnv.Color.GetGreen
    @desc
    Extracts the green channel from a 24-bit or 32-bit color value.
    This allows inspection of the exact green component used in a color.
    @param number Color A numeric color value produced by Color.RGB or Color.RGBA.
    @ret number Returns the green channel value, ranging from 0 to 255.
    @example
    local nGreenValue = Color.GetGreen(nSomeColor)
    !]]
    GetGreen           = Color.GetGreen,
    --[[!
    @fqxn CFS.UserEnv.Color.GetRed
    @desc
    Extracts the red channel from a 24-bit or 32-bit color value.
    This is useful for inspecting or decomposing colors created with Color.RGB or Color.RGBA.
    @param number Color A numeric color value produced by Color.RGB or Color.RGBA.
    @ret number Returns the red component as an integer in the range 0–255.
    @example
    local nRedComponent = Color.GetRed(nColorValue)
    !]]
    GetRed             = Color.GetRed,
    --[[!
    @fqxn CFS.UserEnv.Color.HexToRGB
    @desc
    Converts a hexadecimal RGB color string into a 24-bit numeric color value usable in drawing operations. The expected format is #RRGGBB, where each pair represents red, green, and blue components.
    @param string HexadecimalColor A hexadecimal color string, such as one produced by Color.RGBToHex or a standard HTML color code.
    @ret number Returns a 24-bit numeric RGB color value.
    @example
    local nDarkerGreen = Color.HexToRGB("#00be00")
    !]]
    HexToRGB           = Color.HexToRGB,
    --[[!
    @fqxn CFS.UserEnv.Color.HexToRGBA
    @desc
    Converts a hexadecimal RGBA color string into a 32-bit numeric color value usable in drawing operations. The expected format is #RRGGBBAA, where each pair represents red, green, blue, and alpha components.
    @param string HexadecimalColor A hexadecimal color string, such as one produced by Color.RGBAToHex.
    @ret number Returns a 32-bit numeric RGBA color value.
    @example
    local nDarkerTransparentGreen = Color.HexToRGBA("#00be007c")
    !]]
    HexToRGBA          = Color.HexToRGBA,
    --[[!
    @fqxn CFS.UserEnv.Color.RGBA
    @desc
    Calculates a 32-bit RGBA color value composed of red, green, blue, and alpha components.
    The alpha channel controls opacity, allowing the color to be fully opaque or fully transparent.
    Colors created this way can be blended or mixed during drawing operations.
    @param number Red The red component (0–255).
    @param number Green The green component (0–255).
    @param number Blue The blue component (0–255).
    @param number Alpha The alpha (opacity) component (0–255).
    @ret number Returns the computed color as a single 32-bit numeric value suitable for drawing operations that accept color inputs.
    @example
    local nSemiTransparentRed = Color.RGBA(200, 0, 0, 190)
    !]]
    RGBA               = Color.RGBA,
    --[[!
    @fqxn CFS.UserEnv.Color.RGBAAtOffset
    @desc
    Computes an interpolated RGBA color between two 32-bit colors at a given percentage offset. The offset represents the distance from the first color toward the second, expressed as a value from 0 to 100. This variant preserves and interpolates the alpha channel as part of the gradient.
    @param number Color1 The starting 32-bit RGBA color value.
    @param number Color2 The ending 32-bit RGBA color value.
    @param number Distance Percentage distance from Color1 toward Color2 (0–100).
    @ret number Returns a 32-bit RGBA color value at the specified offset.
    @example
    local nStepColor = Color.RGBAAtOffset(nStartColor,nEndColor,20)
    !]]
    RGBAAtOffset       = Color.RGBAAtOffset,
    --[[!
    @fqxn CFS.UserEnv.Color.RGBAGradientColors
    @desc
    Calculates a sequence of RGBA color values that form a smooth gradient from a starting color to an ending color. The gradient is divided into a specified number of points, representing evenly spaced positions along the transition. This variant also interpolates the alpha channel, allowing transparency to flow across the gradient.
    @param number Color1 The starting 32-bit RGBA color value.
    @param number Color2 The ending 32-bit RGBA color value.
    @param number Points The number of gradient points to generate.
    @ret table Returns a table containing RGBA color values for each gradient step, or nil on failure.
    @example
    -- Make a test project with one page named Page1,
    -- the size should be: Small (with menu bar) in
    -- project settings -> Appearance.
    -- Put this code in the On Show event of Page1.
    Application.SetPageProperties("Page1", {
      UseCustomSettings = true;
      BackgroundType = BG_SOLID;
      BackgroundColor = Color.RGB(0,0,0);
    });

    local nPoints = 26;
    local tColors = Color.RGBAGradientColors(
      Color.RGBA(255,0,0,255),
      Color.RGBA(0,255,0,80),
      nPoints
    );
    -- One extra point is added internally to represent the 100% color.

    local nY = 0;
    for nPoint,nColor in pairs(tColors) do
      Page.CreateObject(OBJECT_LABEL,"label"..nPoint,{
        FontName = "Courier New";
        FontSize = 10;
        ColorNormal = nColor;
        ColorHighlight = nColor;
        ColorDown = nColor;
        X = 5;
        Y = nY;
      });

      Label.SetText("label"..nPoint,"The color at point "..nPoint.." in the list.");
      nY = nY + 10;
    end
    !]]
    RGBAGradientColors = Color.RGBAGradientColors,
    --[[!
    @fqxn CFS.UserEnv.Color.RGB
    @desc
    Calculates a 24-bit RGB color value composed of red, green, and blue components with no alpha channel.
    Use this when opacity is not required; for colors with transparency, use Color.RGBA instead.
    @param number Red The red component (0–255).
    @param number Green The green component (0–255).
    @param number Blue The blue component (0–255).
    @ret number Returns the computed color as a single 24-bit numeric value suitable for drawing operations that accept color inputs.
    @example
    local nGreenColor = Color.RGB(0, 255, 0)
    local nPurpleColor = Color.RGB(255, 0, 255)
    !]]
    RGB                = Color.RGB,
    --[[!
    @fqxn CFS.UserEnv.Color.RGBAtOffset
    @desc
    Computes an interpolated RGB color between two 24-bit colors at a given percentage offset. The offset represents the distance from the first color toward the second, expressed as a value from 0 to 100.
    @param number Color1 The starting 24-bit RGB color value.
    @param number Color2 The ending 24-bit RGB color value.
    @param number Distance Percentage distance from Color1 toward Color2 (0–100).
    @ret number Returns a 24-bit RGB color value at the specified offset.
    @example
    local nStepColor = Color.RGBAtOffset(nStartColor,nEndColor,20)
    !]]
    RGBAtOffset        = Color.RGBAtOffset,
    --[[!
    @fqxn CFS.UserEnv.Color.RGBGradientColors
    @desc
    Calculates a sequence of RGB color values that form a smooth gradient from a starting color to an ending color. The number of generated colors is determined by the points argument, representing evenly spaced positions along the gradient.
    @param number Color1 The starting 24-bit RGB color value.
    @param number Color2 The ending 24-bit RGB color value.
    @param number Points The number of gradient points to generate.
    @ret table Returns a table containing RGB color values for each gradient step, or nil on failure.
    @example
    -- Make a test project with one page named Page1,
    -- the size should be: Small (with menu bar) in
    -- project settings -> Appearance.
    -- Put this code in the On Show event of Page1.
    Application.SetPageProperties("Page1", {
      UseCustomSettings = true;
      BackgroundType = BG_SOLID;
      BackgroundColor = Color.RGB(0,0,0);
    });

    local nPoints = 26;
    local tColors = Color.RGBGradientColors(Color.RGB(255,0,0),Color.RGB(0,255,0),nPoints);
    -- One extra point is added internally to represent the 100% color.

    local nY = 0;
    for nPoint,nColor in pairs(tColors) do
      Page.CreateObject(OBJECT_LABEL,"label"..nPoint,{
        FontName = "Courier New";
        FontSize = 10;
        ColorNormal = nColor;
        ColorHighlight = nColor;
        ColorDown = nColor;
        X = 5;
        Y = nY;
      });

      Label.SetText("label"..nPoint,"The color at point "..nPoint.." in the list.");
      nY = nY + 10;
    end
    !]]
    RGBGradientColors  = Color.RGBGradientColors,
    --[[!
    @fqxn CFS.UserEnv.Color.RGBAToHex
    @desc
    Converts a 32-bit RGBA color value into a hexadecimal color string. This format is useful for configuration, serialization, or user-defined color input where alpha transparency must be preserved.
    @param number Color A 32-bit color value, typically created with Color.RGBA.
    @ret string Returns a hexadecimal color code representing the RGBA color.
    @example
    local sHexRedTransparent = Color.RGBAToHex(Color.RGBA(255,0,0,180))
    !]]
    RGBAToHex          = Color.RGBAToHex,
    --[[!
    @fqxn CFS.UserEnv.Color.RGBToHex
    @desc
    Converts a 24-bit RGB color value into a hexadecimal color string. The resulting value is suitable for use in formats such as HTML or CSS, or for storage and user-facing configuration.
    @param number Color A 24-bit color value, typically created with Color.RGB.
    @ret string Returns a hexadecimal color code representing the input color.
    @example
    local sHexRed = Color.RGBToHex(Color.RGB(255,0,0))
    !]]
    RGBToHex           = Color.RGBToHex,
    --[[!
    @fqxn CFS.UserEnv.Color.SetAlpha
    @desc
    Replaces the alpha channel of a 32-bit RGBA color with a new value, producing a modified color with updated transparency.
    @param number Color A numeric color value created with Color.RGBA.
    @param number NewValue The new alpha value, ranging from 0 to 255.
    @ret number Returns a new 32-bit color value with the alpha channel overwritten.
    @example
    local nNewColor = Color.SetAlpha(nOldColor, 80)
    !]]
    SetAlpha           = Color.SetAlpha,
    --[[!
    @fqxn CFS.UserEnv.Color.SetBlue
    @desc
    Replaces the blue channel of a 24-bit or 32-bit color and returns a new color value with the updated component.
    @param number Color A numeric color value created with Color.RGB or Color.RGBA.
    @param number NewValue The new blue channel value, in the range 0 to 255.
    @ret number Returns the recalculated color value with the blue component overwritten.
    @example
    local nUpdatedColor = Color.SetBlue(nOriginalColor,255)
    !]]
    SetBlue            = Color.SetBlue,
    --[[!
    @fqxn CFS.UserEnv.Color.SetGreen
    @desc
    Replaces the green channel of a 24-bit or 32-bit color and returns a new color value with the updated component.
    @param number Color A numeric color value created with Color.RGB or Color.RGBA.
    @param number NewValue The new green channel value, in the range 0 to 255.
    @ret number Returns the recalculated color value with the green component overwritten.
    @example
    local nUpdatedColor = Color.SetGreen(nOriginalColor, 120)
    !]]
    SetGreen           = Color.SetGreen,
    --[[!
    @fqxn CFS.UserEnv.Color.SetRed
    @desc
    Updates the red channel of an existing 24-bit or 32-bit color value and returns a new color with the modified component.
    All other color channels remain unchanged.
    @param number Color A numeric color value produced by Color.RGB or Color.RGBA.
    @param number NewValue The new red channel value, in the range 0–255.
    @ret number Returns a newly calculated color value with the red component replaced.
    @example
    local nNewColor = Color.SetRed(nOldColor, 0) -- removes the red component
    !]]
    SetRed             = Color.SetRed,
});


--[[
 ██████╗ █████╗ ██████╗ ██████╗
██╔════╝██╔══██╗██╔══██╗██╔══██╗
██║     ███████║██████╔╝██║  ██║
██║     ██╔══██║██╔══██╗██║  ██║
╚██████╗██║  ██║██║  ██║██████╔╝
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝
]]
local tCard = {};
InjectEnv("Card", tCard); ---QUESTION DID PROCSYS REPLACE THIS?


                                                                                --[[
                                                                                ██████╗███████╗ ██████╗
                                                                                ██╔════╝██╔════╝██╔════╝
                                                                                ██║     █████╗  ██║  ███╗
                                                                                ██║     ██╔══╝  ██║   ██║
                                                                                ╚██████╗██║     ╚██████╔╝
                                                                                ╚═════╝╚═╝      ╚═════╝
                                                                                ]]
--user CFG table. It gets swapped on game load
local _tCFG = {};
local _tCFGDecoy, _tCFGMeta = InjectEnv("CFG", _tCFG);


                                                                                --[[
                                                                                ██████╗ ██████╗  █████╗ ██╗    ██╗██╗███╗   ██╗ ██████╗
                                                                                ██╔══██╗██╔══██╗██╔══██╗██║    ██║██║████╗  ██║██╔════╝
                                                                                ██║  ██║██████╔╝███████║██║ █╗ ██║██║██╔██╗ ██║██║  ███╗
                                                                                ██║  ██║██╔══██╗██╔══██║██║███╗██║██║██║╚██╗██║██║   ██║
                                                                                ██████╔╝██║  ██║██║  ██║╚███╔███╔╝██║██║ ╚████║╚██████╔╝
                                                                                ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝
                                                                                ]]
--[[!
@fqxn CFS.UserEnv.Drawing
@desc <section class="mb-5">
<h1>Imagine Draw</h1>
<p>A plugin which will allow you to decode, encode and draw onto images. Draw has many supported formats, such as (Decoders): PNG, JPEG, JPEG2000, BMP, ICO, TIFF, TGA and (Encoders): PNG, JPEG, JPEG2000, BMP.
Using Draw, you can generate any image you want. Included are tons of functions for rotation, mirroring, flipping, drawing lines, boxes, circles, ellipses, gradients, images onto images, arcs, polygons, bold lines, pies.
All this can be done using blending modes, currently there are over 50 blending modes available in Draw. Aside from blending modes, a few filters have been added as well. These filters allow you to draw diagonal, horizontal and vertical lines in specific areas, to negate the colors in a specific area, darken and lighten colors and more!
Draw also comes with functions to Load fonts, these allow you to preload an installed font and use them in your drawing code. You can draw text, angled text and determine the width and height calculated for a string of text you wish to draw.
Draw supports many pixel formats, from 8 bits RGB to 32 bits RGBA. If you create a new image, you have to choose between 24 bits RGB, 32 bits RGB, and 32 bits RGBA.
The submodule Color inside Draw allows you to work with colors, color calculation, conversion to hexadecimal strings, conversion from hexadecimal strings, gradient calculation, alpha blending or mixing two colors.
The, previously developed by RizlaUK, Canvas plugin will also be a part of Draw. The completely redesigned Canvas object is ported with this version. The Canvas allows you to draw directly onto an Object in AMS. The Canvas object also allows events, grabbing mouse and keyboard input and more!</p>

<hr class="border-secondary my-4">

<dl class="row mb-0">
  <dt class="col-sm-3">Version</dt>
  <dd class="col-sm-9">2.0.0.0</dd>

  <dt class="col-sm-3">Author</dt>
  <dd class="col-sm-9">Imagine Programming &lt;Bas Groothedde&gt;</dd>

  <dt class="col-sm-3">Web</dt>
  <dd class="col-sm-9"><a href="http://www.imagine-programming.com" class="link-info">http://www.imagine-programming.com</a></dd>

  <dt class="col-sm-3">Email</dt>
  <dd class="col-sm-9">contact\@imagine-programming.com</dd>

  <dt class="col-sm-3">Copyright</dt>
  <dd class="col-sm-9">© Imagine Programming, 2024.</dd>
</dl>

<hr class="border-secondary my-4">

<p class="mb-0"><strong>Note:</strong> While the official manual occasionally lists the <strong>Drawing.DrawSquare</strong> method in some examples, that method has been deprecated. Use <strong>Drawing.DrawRectangle</strong> instead.</p>
</section>!]]
InjectEnv("Drawing",{--TODO add real description to these
    --[[!@fqxn CFS.UserEnv.Drawing.ClearGradientColors @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    ClearGradientColors          = Drawing.ClearGradientColors,
    --[[!@fqxn CFS.UserEnv.Drawing.DrawAlphaImage @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DrawAlphaImage               = Drawing.DrawAlphaImage,
    --[[!@fqxn CFS.UserEnv.Drawing.DrawAngledText @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DrawAngledText               = Drawing.DrawAngledText,
    --[[!@fqxn CFS.UserEnv.Drawing.DrawArc @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DrawArc                      = Drawing.DrawArc,
    --[[!@fqxn CFS.UserEnv.Drawing.DrawBoldLine @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DrawBoldLine                 = Drawing.DrawBoldLine,
    --[[!@fqxn CFS.UserEnv.Drawing.DrawCircle @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DrawCircle                   = Drawing.DrawCircle,
    --[[!@fqxn CFS.UserEnv.Drawing.DrawEllipse @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DrawEllipse                  = Drawing.DrawEllipse,
    --[[!@fqxn CFS.UserEnv.Drawing.DrawImage @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DrawImage                    = Drawing.DrawImage,
    --[[!@fqxn CFS.UserEnv.Drawing.DrawLine @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DrawLine                     = Drawing.DrawLine,
    --[[!@fqxn CFS.UserEnv.Drawing.DrawLineEx @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DrawLineEx                   = Drawing.DrawLineEx,
    --[[!@fqxn CFS.UserEnv.Drawing.DrawPie @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DrawPie                      = Drawing.DrawPie,
    --[[!@fqxn CFS.UserEnv.Drawing.DrawPixel @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DrawPixel                    = Drawing.DrawPixel,
    --[[!@fqxn CFS.UserEnv.Drawing.DrawPolygon @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DrawPolygon                  = Drawing.DrawPolygon,
    --[[!@fqxn CFS.UserEnv.Drawing.DrawRectangle @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DrawRectangle                = Drawing.DrawRectangle,
    --[[!@fqxn CFS.UserEnv.Drawing.DrawRoundedRectangle @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DrawRoundedRectangle         = Drawing.DrawRoundedRectangle,
    --[[!@fqxn CFS.UserEnv.Drawing.DrawText @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DrawText                     = Drawing.DrawText,
    --[[!@fqxn CFS.UserEnv.Drawing.FillOutlinedRegion @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    FillOutlinedRegion           = Drawing.FillOutlinedRegion,
    --[[!@fqxn CFS.UserEnv.Drawing.GetAvailableCollibFilters @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    GetAvailableCollibFilters    = Drawing.GetAvailableCollibFilters,
    --[[!@fqxn CFS.UserEnv.Drawing.GetPixel @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    GetPixel                     = Drawing.GetPixel,
    --[[!@fqxn CFS.UserEnv.Drawing.GetTextHeight @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    GetTextHeight                = Drawing.GetTextHeight,
    --[[!@fqxn CFS.UserEnv.Drawing.GetTextWidth @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    GetTextWidth                 = Drawing.GetTextWidth,
    --[[!@fqxn CFS.UserEnv.Drawing.PrepareCircularGradient @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    PrepareCircularGradient      = Drawing.PrepareCircularGradient,
    --[[!@fqxn CFS.UserEnv.Drawing.PrepareConicalGradient @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    PrepareConicalGradient       = Drawing.PrepareConicalGradient,
    --[[!@fqxn CFS.UserEnv.Drawing.PrepareEllipticalGradient @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    PrepareEllipticalGradient    = Drawing.PrepareEllipticalGradient,
    --[[!@fqxn CFS.UserEnv.Drawing.PrepareLinearGradient @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    PrepareLinearGradient        = Drawing.PrepareLinearGradient,
    --[[!@fqxn CFS.UserEnv.Drawing.PrepareRectangularGradient @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    PrepareRectangularGradient   = Drawing.PrepareRectangularGradient,
    --[[!@fqxn CFS.UserEnv.Drawing.SetBackColor @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    SetBackColor                 = Drawing.SetBackColor,
    --[[!@fqxn CFS.UserEnv.Drawing.SetCollibFilter @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    SetCollibFilter              = Drawing.SetCollibFilter,
    --[[!@fqxn CFS.UserEnv.Drawing.SetDrawingFont @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    SetDrawingFont               = Drawing.SetDrawingFont,
    --[[!@fqxn CFS.UserEnv.Drawing.SetFilteringMode @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    SetFilteringMode             = Drawing.SetFilteringMode,
    --[[!@fqxn CFS.UserEnv.Drawing.SetFrontColor @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    SetFrontColor                = Drawing.SetFrontColor,
    --[[!@fqxn CFS.UserEnv.Drawing.SetGradientColors @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    SetGradientColors            = Drawing.SetGradientColors,
    --[[!@fqxn CFS.UserEnv.Drawing.SetSingleGradientColor @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    SetSingleGradientColor       = Drawing.SetSingleGradientColor,
    --[[!@fqxn CFS.UserEnv.Drawing.Constants.DRAW_FORMAT_JPEG @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_FORMAT_JPEG             = DRAW_FORMAT_JPEG,
    --[[!@fqxn CFS.UserEnv.Drawing.DRAW_FORMAT_JPEG2000 @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_FORMAT_JPEG2000         = DRAW_FORMAT_JPEG2000,
    --[[!@fqxn CFS.UserEnv.Drawing.DRAW_FORMAT_BMP @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_FORMAT_BMP              = DRAW_FORMAT_BMP,
    --[[!@fqxn CFS.UserEnv.Drawing.DRAW_FORMAT_ICON @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_FORMAT_ICON             = DRAW_FORMAT_ICON,
    --[[!@fqxn CFS.UserEnv.Drawing.Constants.DRAW_FORMAT_PNG @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_FORMAT_PNG              = DRAW_FORMAT_PNG,
    --[[!@fqxn CFS.UserEnv.Drawing.Constants.DRAW_FORMAT_TGA @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_FORMAT_TGA              = DRAW_FORMAT_TGA,
    --[[!@fqxn CFS.UserEnv.Drawing.Constants.DRAW_FORMAT_TIFF @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_FORMAT_TIFF             = DRAW_FORMAT_TIFF,
    --[[!@fqxn CFS.UserEnv.Drawing.Constants.DRAW_MIRROR_HORIZONTAL @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_MIRROR_HORIZONTAL       = DRAW_MIRROR_HORIZONTAL,
    --[[!@fqxn CFS.UserEnv.Drawing.Constants.DRAW_MIRROR_VERTICAL @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_MIRROR_VERTICAL         = DRAW_MIRROR_VERTICAL,
    --[[!@fqxn CFS.UserEnv.Drawing.Constants.DRAW_BLEND_DEFAULT @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_BLEND_DEFAULT           = DRAW_BLEND_DEFAULT,
    --[[!@fqxn CFS.UserEnv.Drawing.Constants.DRAW_BLEND_TEXT_TRANSPARENT @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_BLEND_TEXT_TRANSPARENT  = DRAW_BLEND_TEXT_TRANSPARENT,
    --[[!@fqxn CFS.UserEnv.Drawing.Constants.DRAW_BLEND_XOR @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_BLEND_XOR               = DRAW_BLEND_XOR,
    --[[!@fqxn CFS.UserEnv.Drawing.Constants.DRAW_BLEND_OUTLINE @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_BLEND_OUTLINE           = DRAW_BLEND_OUTLINE,
    --[[!@fqxn CFS.UserEnv.Drawing.Constants.DRAW_BLEND_ALPHABLEND @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_BLEND_ALPHABLEND        = DRAW_BLEND_ALPHABLEND,
    --[[!@fqxn CFS.UserEnv.Drawing.Constants.DRAW_BLEND_ALPHACLIP @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_BLEND_ALPHACLIP         = DRAW_BLEND_ALPHACLIP,
    --[[!@fqxn CFS.UserEnv.Drawing.Constants.DRAW_BLEND_ALPHACHANNEL @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_BLEND_ALPHACHANNEL      = DRAW_BLEND_ALPHACHANNEL,
    --[[!@fqxn CFS.UserEnv.Drawing.Constants.DRAW_BLEND_ALLCHANNELS @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_BLEND_ALLCHANNELS       = DRAW_BLEND_ALLCHANNELS,
    --[[!@fqxn CFS.UserEnv.Drawing.Constants.DRAW_FILTER_GRADIENT @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_FILTER_GRADIENT         = DRAW_FILTER_GRADIENT,
    --[[!@fqxn CFS.UserEnv.Drawing.Constants.DRAW_FILTER_COLLIB @see <strong>Help->Drawing</strong> in the application's main menu. !]]
    DRAW_FILTER_COLLIB           = DRAW_FILTER_COLLIB,
});


                                                                                --[[
                                                                                ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
                                                                                ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
                                                                                █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
                                                                                ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
                                                                                ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
                                                                                ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
                                                                                ]]
--[[!@fqxn CFS.UserEnv.Forge
    @inheritdoc CFS.Classes.Forge!]]
local tForge        = {};
local tForgeKeys    = {};
InjectEnv("Forge", {
    --[[!@fqxn CFS.UserEnv.Forge.DrawImage
        @inheritdoc CFS.Classes.Forge.Methods.DrawImage!]]
    DrawImage       = Forge.DrawImage,
    --[[!@fqxn CFS.UserEnv.Forge.DrawText
        @inheritdoc CFS.Classes.Forge.Methods.DrawText!]]
    DrawText        = Forge.DrawText,
    --[[!@fqxn CFS.UserEnv.Forge.DrawStyledText
        @inheritdoc CFS.Classes.Forge.Methods.DrawStyledText!]]
    DrawStyledText  = Forge.DrawStyledText,
});


--[[!
@fqxn CFS.UserEnv.geometry
@desc
<div class="card border-0 shadow-sm bg-dark text-light mb-3">
  <div class="card-body">
    <div class="d-flex align-items-center mb-2">
      <div class="me-2" style="width:6px;height:32px;background:#ff8f00;border-radius:3px;"></div>
      <h5 class="mb-0 fw-bold text-uppercase letter-spacing-1">
        Geometry
      </h5>
    </div>

    <p class="mb-2">
      Provides geometric helpers for working with rectangles, bounds, and spatial layout.
      These utilities are designed for hit testing, containment checks, and aspect-ratio–
      preserving fitting commonly used in drawing, UI composition, and card layout logic.
    </p>

    <p class="mb-0 text-muted small">
      Focused on clarity and determinism — no scene state, no transforms, just math.
    </p>
  </div>
</div>
!]]
InjectEnv("geometry", {
    --[[!
    @fqxn CFS.UserEnv.geometry.fitrect
    @desc Calculates the largest rectangle that fits inside an outer rectangle
    while preserving the aspect ratio of an inner rectangle.
    Optionally centers the result within the outer rectangle.
    @param table tOuter Rectangle defining the available area (x, y, width, height).
    @param table tInner Rectangle defining the original size (width, height).
    @param boolean bCenter If true, centers the fitted rectangle within the outer rectangle.
    @ret table tResult Rectangle containing width, height, x, and y.
    @example
    local tFitted = geometry.fitrect(tOuterRect, tImageRect, true)
    !]]
    fitrect             = math.geometry.fitrect,
    --[[!
    @fqxn CFS.UserEnv.geometry.rectcontains
    @desc Tests whether two rectangles overlap with a positive intersection area.
    Returns true only when the rectangles share a non-zero overlapping region.
    @param table tMe First rectangle (x, y, width, height).
    @param table tOther Second rectangle (x, y, width, height).
    @ret boolean bOverlaps True if the rectangles intersect with positive area.
    @example
    local bOverlaps = geometry.rectcontains(tRectA, tRectB)
    !]]
    rectcontains        = math.geometry.rectcontains,
    --[[!
    @fqxn CFS.UserEnv.geometry.rectcontainsfully
    @desc Tests whether one rectangle intersects or encloses another.
    Unlike rectcontains, edge contact is considered a valid intersection.
    @param table tMe First rectangle (x, y, width, height).
    @param table tOther Second rectangle (x, y, width, height).
    @ret boolean bIntersects True if the rectangles intersect in any way.
    @example
    local bIntersects = geometry.rectcontainsfully(tContainer, tChild)
    !]]
    rectcontainsfully   = math.geometry.rectcontainsfully,
});


                                                                                --[[
                                                                                ███╗   ███╗ █████╗ ████████╗██╗  ██╗
                                                                                ████╗ ████║██╔══██╗╚══██╔══╝██║  ██║
                                                                                ██╔████╔██║███████║   ██║   ███████║
                                                                                ██║╚██╔╝██║██╔══██║   ██║   ██╔══██║
                                                                                ██║ ╚═╝ ██║██║  ██║   ██║   ██║  ██║
                                                                                ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝
                                                                                ]]
--[[!
@fqxn CFS.UserEnv.math
@desc <pre class="fw-bold lh-1 mb-2">
<span style="color:#4d70f1">

</span>
</pre>
<div class="mt-2">
Provides mathematical utilities exposed to the user environment. This module includes
standard Lua math functionality alongside extended helpers and custom numeric utilities
implemented by the engine. In addition to core arithmetic and trigonometry, it offers
higher-level helpers for ratios, ranges, randomness, geometry, color math, and numeric
classification.
</div>
!]]
InjectEnv("math", {
    --[[!
    @fqxn CFS.UserEnv.math.abs
    @desc
        Returns the absolute (non-negative) value of a number.
    @example
    local v = math.abs(-5)   -- 5
    !]]
    abs                 = math.abs,
    --[[!
    @fqxn CFS.UserEnv.math.acos
    @desc
        Computes the arc cosine of a value, expressed in radians.
        The input must be within the range -1 to 1.
    @example
    local a = math.acos(1)   -- 0
    !]]
    acos                = math.acos,
    --[[!
    @fqxn CFS.UserEnv.math.asin
    @desc
        Computes the arc sine of a value, in radians.
        Valid only for values between -1 and 1.
    @example
    local a = math.asin(0)
    !]]
    asin                = math.asin,
    --[[!
    @fqxn CFS.UserEnv.math.atan
    @desc
        Returns the arc tangent of a value, measured in radians.
    @example
    local a = math.atan(1)
    !]]
    atan                = math.atan,
    --[[!
    @fqxn CFS.UserEnv.math.atan2
    @desc
        Computes the arc tangent using two coordinates,
        preserving the correct quadrant of the result.
    @example
    local angle = math.atan2(y, x)
    !]]
    atan2               = math.atan2,
    --[[!
    @fqxn CFS.UserEnv.math.ceil
    @desc
        Rounds a number upward to the nearest integer
        that is greater than or equal to the input.
    @example
    local n = math.ceil(2.3)   -- 3
    !]]
    ceil                = math.ceil,
    --[[!
    @fqxn CFS.UserEnv.math.clamp
    @desc Constrains a numeric value to lie within a minimum and maximum bound.
    If the value is smaller than the minimum, the minimum is returned.
    If the value is larger than the maximum, the maximum is returned.
    @param number nValue Value to clamp.
    @param number nMinValue Lower bound.
    @param number nMaxValue Upper bound.
    @ret number nResult Clamped value.
    @ex
    math.clamp(15, 0, 10)   -- 10
    !]]
    clamp               = math.clamp,
    --[[!
    @fqxn CFS.UserEnv.math.convertbase
    @desc Converts a numeric string from one base to another.
    The input is first interpreted using the source base, then re-encoded
    using the target base.
    @example
    local v = math.convertbase("FF", 16, 10) -- "255"
    !]]
    convertbase         = math.convertbase,
    --[[!
    @fqxn CFS.UserEnv.math.cos
    @desc Calculates the cosine of an angle given in radians.
    @example
    local c = math.cos(math.pi)
    !]]
    cos                 = math.cos,
    --[[!
    @fqxn CFS.UserEnv.math.counting
    @desc Converts a number into a positive counting value.
    The result is always greater than zero and rounded using floor or ceiling.
    @param number nValue Input value.
    @param boolean bRaise If true, rounds upward instead of downward.
    @ret number nResult Counting number.
    @ex
    math.counting(-2.7) -- 2
    !]]
    counting            = math.counting,
    --[[!
    @fqxn CFS.UserEnv.math.deg
    @desc Converts an angle from radians into degrees.
    @example
    local d = math.deg(math.pi) -- 180
    !]]
    deg                 = math.deg,
    --[[!
    @fqxn CFS.UserEnv.math.drift
    @desc Applies a random additive offset within a symmetric range.
    The result varies by up to the drift amount in either direction.
    @example
    local v = math.drift(10, 2)
    !]]
    drift               = math.drift,
    --[[!
    @fqxn CFS.UserEnv.math.driftf
    @desc Applies a proportional random variation to a value.
    The drift is applied as a ratio of the original value.
    @example
    local v = math.driftf(100, 0.1)
    !]]
    driftf              = math.driftf,
    --[[!
    @fqxn CFS.UserEnv.math.e
    @desc Mathematical constant representing Euler’s number.
    Used as the base of natural logarithms.
    @example
    local v = math.e
    !]]
    e                   = math.e,
    --[[!
    @fqxn CFS.UserEnv.math.exp
    @desc
        Computes the exponential value e raised to the given power.
    @example
    local v = math.exp(1)
    !]]
    exp                 = math.exp,
    --[[!
    @fqxn CFS.UserEnv.math.factorial
    @desc Computes the factorial of a positive integer using iterative multiplication.
    The factorial is the product of all integers from 1 to the given value.
    @param number nVal Integer value.
    @ret number nResult Factorial of the input.
    @ex
    math.factorial(5)   -- 120
    !]]
    factorial           = math.factorial,
    --[[!
    @fqxn CFS.UserEnv.math.floor
    @desc
        Rounds a number downward to the nearest integer
        that is less than or equal to the input.
    @example
    local n = math.floor(2.9)   -- 2
    !]]
    floor               = math.floor,
    --[[!
    @fqxn CFS.UserEnv.math.fmod
    @desc
        Returns the remainder of dividing two numbers,
        keeping the sign of the first operand.
    @example
    local r = math.fmod(7, 3)   -- 1
    !]]
    fmod                = math.fmod,
    --[[!
    @fqxn CFS.UserEnv.math.gcf
    @desc Calculates the greatest common factor of two numbers using the Euclidean algorithm.
    The result is always non-negative.
    @param number nNum First value.
    @param number nDen Second value.
    @ret number nResult Greatest common factor.
    @ex
    math.gcf(24, 18)    -- 6
    !]]
    gcf                 = math.gcf,
    geometry            = tGeometry,
    --[[!
    @fqxn CFS.UserEnv.math.huge
    @desc Represents a value larger than any other numeric value, typically used as positive infinity.
    @example
    local inf = math.huge
    !]]
    huge                = math.huge,
    --[[!
    @fqxn CFS.UserEnv.math.inttorgb
    @desc Converts a packed integer color value into red, green, and blue components.
    @example
    local r, g, b = math.inttorgb(0xFF00FF)
    !]]
    inttorgb            = math.inttorgb,
    --[[!
    @fqxn CFS.UserEnv.math.iseven
    @desc Tests whether a numeric value is evenly divisible by two.
    @param number nValue Input value.
    @ret boolean bIsEven True if the value is even.
    @ex
    math.iseven(4)      -- true
    !]]
    iseven              = math.iseven,
    --[[!
    @fqxn CFS.UserEnv.math.isinteger
    @desc Determines whether a numeric value represents an exact integer.
    @example
    local bIsInt = math.isinteger(4.0) -- true
    !]]
    isinteger           = math.isinteger,
    --[[!
    @fqxn CFS.UserEnv.math.isodd
    @desc Tests whether a numeric value is not evenly divisible by two.
    @param number nValue Input value.
    @ret boolean bIsOdd True if the value is odd.
    @ex
    math.isodd(7)       -- true
    !]]
    isodd               = math.isodd,
    --[[!
    @fqxn CFS.UserEnv.math.log
    @desc Computes the natural logarithm of a number, or a logarithm with an optional base.
    @example
    local n = math.log(8, 2)   -- 3
    !]]
    log                 = math.log,
    --[[!
    @fqxn CFS.UserEnv.math.max
    @desc Returns the largest value among its arguments.
    @example
    local m = math.max(1, 5, 3)
    !]]
    max                 = math.max,
    --[[!
    @fqxn CFS.UserEnv.math.min
    @desc Returns the smallest value among its arguments.
    @example
    local m = math.min(1, 5, 3)
    !]]
    min                 = math.min,
    --[[!
    @fqxn CFS.UserEnv.math.modf
    @desc Splits a number into its integer and fractional components.
    @example
    local i, f = math.modf(3.14)
    !]]
    modf                = math.modf,
    --[[!
    @fqxn CFS.UserEnv.math.pi
    @desc A constant representing the mathematical value π.
    @example
    local c = 2 * math.pi
    !]]
    pi                  = math.pi,
    --[[!
    @fqxn CFS.UserEnv.math.rad
    @desc Converts an angle from degrees to radians.
    @example
    local r = math.rad(180)
    !]]
    rad                 = math.rad,
    --[[!
    @fqxn CFS.UserEnv.math.random
    @desc Produces pseudo-random numbers.
        May return a float in [0,1) or an integer within a range.
    @example
    local r1 = math.random()
    local r2 = math.random(1, 10)
    !]]
    random              = math.random,
    --[[!
    @fqxn CFS.UserEnv.math.randomf
    @desc Generates a random floating-point number within a given range.
    The result has fixed decimal precision.
    @example
    local v = math.randomf(0.5, 0.95)
    !]]
    randomf             = math.randomf,
    --[[!
    @fqxn CFS.UserEnv.math.randomseed
    @desc Sets the initial seed for the random number generator.
    @example
    math.randomseed(os.time())
    !]]
    randomseed          = math.randomseed,
    --[[!
    @fqxn CFS.UserEnv.math.ratio
    @desc Reduces two numbers into their simplest integer ratio form.
    The result is returned as a table with left and right components.
    @param number nLeft Left value.
    @param number nRight Right value.
    @ret table tRatio Simplified ratio.
    @ex
    math.ratio(1920, 1080) -- { left = 16, right = 9 }
    !]]
    ratio               = math.ratio,
    --[[!
    @fqxn CFS.UserEnv.math.rgbtohex
    @desc Converts red, green, and blue components into a hexadecimal color value.
    @example
    local nHex = math.rgbtohex(255, 128, 0)
    !]]
    rgbtohex            = math.rgbtohex,
    --[[!
    @fqxn CFS.UserEnv.math.rgbtoint
    @desc Packs red, green, and blue components into a single integer value.
    @example
    local nINt = math.rgbtoint(255, 0, 255)
    !]]
    rgbtoint            = math.rgbtoint,
    --[[!
    @fqxn CFS.UserEnv.math.sin
    @desc Calculates the sine of an angle given in radians.
    @example
    local s = math.sin(math.pi / 2)
    !]]
    sin                 = math.sin,
    --[[!
    @fqxn CFS.UserEnv.math.sqrt
    @desc Returns the square root of a non-negative number.
    @example
    local s = math.sqrt(16)
    !]]
    sqrt                = math.sqrt,
    --[[!
    @fqxn CFS.UserEnv.math.sum
    @desc Returns the total of all numeric arguments provided.
    @example
    local t = math.sum(1, 2, 3, 4)
    !]]
    sum                 = math.sum,
    --[[!
    @fqxn CFS.UserEnv.math.tan
    @desc Calculates the tangent of an angle expressed in radians.
    @example
    local t = math.tan(math.pi / 4)
    !]]
    tan                 = math.tan,
    --[[!
    @fqxn CFS.UserEnv.math.tointeger
    @desc Converts a value to an integer if it represents an exact integer numeric value.
    @example
    local i = math.tointeger(3.0)
    !]]
    tointeger           = math.tointeger,
    --[[!
    @fqxn CFS.UserEnv.math.type
    @desc Returns whether a number is classified as an integer or a floating-point value.
    @example
    print(math.type(3))     -- "integer"
    print(math.type(3.1))   -- "float"
    !]]
    type                = math.type,
    --[[!
    @fqxn CFS.UserEnv.math.ult
    @desc Compares two integers as unsigned values.
    Returns true if the first value is smaller.
    @example
    local ok = math.ult(0xFFFFFFFF, 1)
    !]]
    ult                 = math.ult,
    --[[!
    @fqxn CFS.UserEnv.math.whole
    @desc Converts a number into a whole (non-negative) value.
    Unlike counting numbers, zero is allowed.
    @param number nValue Input value.
    @param boolean bRaise If true, rounds upward instead of downward.
    @ret number nResult Whole number.
    @ex
    math.whole(-3.2)    -- 3
    !]]
    whole               = math.whole,
});


                                                                                --[[
                                                                                ██████╗ ██████╗  ██████╗  ██████╗███████╗██╗   ██╗███████╗
                                                                                ██╔══██╗██╔══██╗██╔═══██╗██╔════╝██╔════╝╚██╗ ██╔╝██╔════╝
                                                                                ██████╔╝██████╔╝██║   ██║██║     ███████╗ ╚████╔╝ ███████╗
                                                                                ██╔═══╝ ██╔══██╗██║   ██║██║     ╚════██║  ╚██╔╝  ╚════██║
                                                                                ██║     ██║  ██║╚██████╔╝╚██████╗███████║   ██║   ███████║
                                                                                ╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚══════╝   ╚═╝   ╚══════╝
                                                                                ]]
local tProcSys      = {};
local tProcSysKeys  = {};
InjectEnv("ProcSys", tProcSys); --TODO QUESTION, why is this being injected still?


                                                                                --[[
                                                                                ██████╗ ███╗   ██╗ ██████╗
                                                                                ██╔══██╗████╗  ██║██╔════╝
                                                                                ██████╔╝██╔██╗ ██║██║  ███╗
                                                                                ██╔══██╗██║╚██╗██║██║   ██║
                                                                                ██║  ██║██║ ╚████║╚██████╔╝
                                                                                ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝
                                                                                ]]
InjectEnv("RNG", {
    binary          = RNG.binary,
    bipolar         = RNG.bipolar,
    boolean         = RNG.boolean,
    choice          = RNG.choice,
    multiChoice     = RNG.multiChoice,
    percent         = RNG.percent,
    pick            = RNG.pick,
    randomx         = RNG.randomx,
    rollCheck       = RNG.rollCheck,
    rollDice        = RNG.rollDice,
    rollPercentage  = RNG.rollPercentage,
});


                                                                                --[[
                                                                                ███████╗████████╗██████╗ ██╗███╗   ██╗ ██████╗
                                                                                ██╔════╝╚══██╔══╝██╔══██╗██║████╗  ██║██╔════╝
                                                                                ███████╗   ██║   ██████╔╝██║██╔██╗ ██║██║  ███╗
                                                                                ╚════██║   ██║   ██╔══██╗██║██║╚██╗██║██║   ██║
                                                                                ███████║   ██║   ██║  ██║██║██║ ╚████║╚██████╔╝
                                                                                ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝
                                                                                ]]
InjectEnv("string", {
    byte                = string.byte,
    cap                 = string.cap,
    capall              = string.capall,
    char                = string.char,
    collapse            = string.collapse,
    find                = string.find,
    format              = string.format,
    gmatch              = string.gmatch,
    gsub                = string.gsub,
    htmltomd            = string.htmltomd,
    isempty             = string.isempty,
    isdatevalid         = string.isdatevalid,
    isfilesafe          = string.isfilesafe,
    iskeyword           = string.iskeyword,
    isnumeric           = string.isnumeric,
    isuuid              = string.isuuid,
    isvariablecompliant = string.isvariablecompliant,
    len                 = string.len,
    lower               = string.lower,
    makefilesafe        = string.makefilesafe,
    match               = string.match,
    rep                 = string.rep,
    reverse             = string.reverse,
    sub                 = string.sub,
    tosid               = string.tosid,
    totable             = string.totable,
    trim                = string.trim,
    trimleft            = string.trimleft,
    trimright           = string.trimright,
    upper               = string.upper,
    uuid                = string.uuid,
});

                                                                                --[[
                                                                                ████████╗ █████╗ ██████╗ ██╗     ███████╗
                                                                                ╚══██╔══╝██╔══██╗██╔══██╗██║     ██╔════╝
                                                                                   ██║   ███████║██████╔╝██║     █████╗
                                                                                   ██║   ██╔══██║██╔══██╗██║     ██╔══╝
                                                                                   ██║   ██║  ██║██████╔╝███████╗███████╗
                                                                                   ╚═╝   ╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝
                                                                                ]]
InjectEnv("table", {
    concat  = table.concat,
    insert  = table.insert,
    move    = table.move,
    pack    = table.pack,
    remove  = table.remove,
    sort    = table.sort,
    unpack  = table.unpack,
});


                                                                                    --[[
                                                                                    ██╗   ██╗███████╗███████╗██████╗
                                                                                    ██║   ██║██╔════╝██╔════╝██╔══██╗
                                                                                    ██║   ██║███████╗█████╗  ██████╔╝
                                                                                    ██║   ██║╚════██║██╔══╝  ██╔══██╗
                                                                                    ╚██████╔╝███████║███████╗██║  ██║
                                                                                     ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝
                                                                                    ]]
local tUser     = {};
local tUserKeys = {}; --tracks keys since user can inject into the base table.
InjectEnv("Session", tUser);

                                                        --[[
                                                        ██╗   ██╗███████╗ ██████╗████████╗ ██████╗ ██████╗ ██████╗ ██████╗  █████╗ ██╗    ██╗██╗███╗   ██╗ ██████╗
                                                        ██║   ██║██╔════╝██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗██║    ██║██║████╗  ██║██╔════╝
                                                        ██║   ██║█████╗  ██║        ██║   ██║   ██║██████╔╝██║  ██║██████╔╝███████║██║ █╗ ██║██║██╔██╗ ██║██║  ███╗
                                                        ╚██╗ ██╔╝██╔══╝  ██║        ██║   ██║   ██║██╔══██╗██║  ██║██╔══██╗██╔══██║██║███╗██║██║██║╚██╗██║██║   ██║
                                                         ╚████╔╝ ███████╗╚██████╗   ██║   ╚██████╔╝██║  ██║██████╔╝██║  ██║██║  ██║╚███╔███╔╝██║██║ ╚████║╚██████╔╝
                                                          ╚═══╝  ╚══════╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝
                                                        ]]
InjectEnv("VectorDrawing", {
    Arc         = VectorDrawing.Arc,
    FillPath   = VectorDrawing.FillPath,
    LineTo     = VectorDrawing.LineTo,
    MoveTo     = VectorDrawing.MoveTo,
    SetColor   = VectorDrawing.SetColor,
    StrokePath = VectorDrawing.StrokePath,
});


                                                                        --[[
                                                                        ███████╗██╗   ██╗███╗   ██╗ ██████╗████████╗██╗ ██████╗ ███╗   ██╗███████╗
                                                                        ██╔════╝██║   ██║████╗  ██║██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
                                                                        █████╗  ██║   ██║██╔██╗ ██║██║        ██║   ██║██║   ██║██╔██╗ ██║███████╗
                                                                        ██╔══╝  ██║   ██║██║╚██╗██║██║        ██║   ██║██║   ██║██║╚██╗██║╚════██║
                                                                        ██║     ╚██████╔╝██║ ╚████║╚██████╗   ██║   ██║╚██████╔╝██║ ╚████║███████║
                                                                        ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝
                                                                        ]]
local tUserEnv = {
    Get = function()
        return tEnv;
    end,
    -- Returns a numerically-indexed, alphabetically-sorted list of callable commands
    -- exposed by tEnv (including decoy tables that expose their real members via __index = table).
    --
    -- Example output entries:
    --   "math.abs"
    --   "Drawing.DrawLine"
    --   "Color.RGBA"
    --
    GetCommandList = function()
        local tRoot = tEnv -- upvalue

        local tVisited = {}
        local tOutSet  = {}
        local tOut     = {}

        local function AddCommand(sPath)
            if (sPath ~= "" and not tOutSet[sPath]) then
                tOutSet[sPath] = true
                tOut[#tOut + 1] = sPath
            end
        end

        local function EnumKeys(t)
            local tKeys = {}

            for k in pairs(t) do
                if (rawtype(k) == "string") then
                    tKeys[k] = true
                end
            end

            local tBack = tEnvBacking[t]
            if (rawtype(tBack) == "table") then
                for k in pairs(tBack) do
                    if (rawtype(k) == "string") then
                        tKeys[k] = true
                    end
                end
            end

            return tKeys
        end

        local function Walk(t, sPrefix)
            if (tVisited[t]) then return end
            tVisited[t] = true

            for k in pairs(EnumKeys(t)) do
                local v = t[k]
                local sPath = sPrefix and (sPrefix .. "." .. k) or k

                if (rawtype(v) == "function") then
                    AddCommand(sPath)
                elseif (rawtype(v) == "table") then
                    Walk(v, sPath)
                end
            end
        end

        Walk(tRoot, nil)
        table.sort(tOut, function(a, b) return a:lower() < b:lower() end)
        return tOut
    end,
    Refresh = function()
        --TODO FINISH CLEAN THIS OUT!!! On game  load, it should be clean
    end,
    ProcSysUpdateRoot = function(tInput, bPurge) --permits additions/replacement to/of existing keys or a full purge, then new items added

        if (rawtype(tInput) == "table") then

            if (bPurge) then
                --delete the previous user keys from the env
                for sKey in pairs(tProcSysKeys) do
                    tEnv[sKey] = nil;
                end

                tProcSysKeys = {}; --clear the keys
            end

            --import (and record) the new keys
            for sIndex, vItem in pairs(tInput) do

                if (rawtype(sIndex) == "string") then
                    tProcSysKeys[sIndex]    = true;
                    tEnv[sIndex]            = vItem;
                end

            end

        end
    end,
    --expects new CFG to have brought in through the user env
    UserUpdateCFG = function(tInput)
        _tCFG = {};

        if (rawtype(tInput) == "table") then
            _tCFG = tInput--table.shadowreadonly(tInput);
        end

        _tCFGMeta.__index = _tCFG;
        setmetatable(_tCFGDecoy, _tCFGMeta);

    end,
    UserUpdateENV = function(tInput) --TODO BUG update this to use protected env when able : the user table will get input thourgh forge constructor, then run through the safe env filter, then iterated over and dumped into main env table (error on overwriteing ofc.)
        --local tInput = --GetUserEnv();
        --TODO ALSO DO NOT LEt user indices overwrite exiting onces...keep track of list afte rinjhection and allow new injectio to overwrite only user indices

        if (rawtype(tInput) == "table") then

            --delete the previous user keys from the env
            for sKey in pairs(tUserKeys) do
                tEnv[sKey] = nil;
            end

            tUserKeys = {}; --clear the user keys

            --import (and record) the new keys
            for sIndex, vItem in pairs(tInput) do

                if (rawtype(sIndex) == "string") then
                    tUserKeys[sIndex]   = true;
                    tEnv[sIndex]        = vItem;
                end

            end

        end
    end,
};
local tUserEnvDecoy = {};
local tUserEnvMeta  = {
    __index = function(t, k)
        return tUserEnv[k];
    end,
    __newindex = function(t, k, v)
        error("Attempt to write to read-only 'UserEnv'.", 2);
    end,
    __metatable = false,
};

setmetatable(tUserEnvDecoy, tUserEnvMeta);

return tUserEnvDecoy;
