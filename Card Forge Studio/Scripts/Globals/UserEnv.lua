local wx = require("wx");
local Color = {RGBA = wx.wxColour, RGB = wx.wxColour};
--[[!
@fqxn CFS.UserEnv.Private.Functions.p
@desc Formats supplied values into a logged user-environment message.
@param any ... Additional drawing arguments.
@vis private
!]]
local function p(...)
    local tValues = {};
    for nIndex = 1, select("#", ...) do
        local vValue = select(nIndex, ...);
        tValues[nIndex] = rawtype(vValue) == "table" and serialize(vValue) or tostring(vValue);
    end
    Log.Debug(table.concat(tValues, "\t"));
end
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
@desc
<section aria-label="User Environment overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">User Environment</h2><p style="font-size:1.15rem;margin:0">UserEnv is the shared workspace where game scripts find configuration, helper values, and the APIs Studio exposes.</p></div>
<h3>How it fits into your work</h3><p>ProcSys prepares the environment while loading Config and Environment scripts, then evaluates card-set scripts using those shared values.</p>
<h3>Follow the handoffs</h3><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,260px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">The workspace behind game scripts</h3><p style="margin:0">The environment brings configuration, game helpers, the selected card data, and Studio drawing commands into one place. CFG and ENV scripts establish game settings and helper definitions. Card-set processing and drawing scripts then work with that shared workspace rather than rebuilding every connection themselves.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">How it changes with your selection</h3><p style="margin:0">ProcSys prepares and resets the environment as projects and card sets are loaded. Card processing supplies the selected row values, and Forge uses the drawing callbacks loaded for that set. UserEnv connects these pieces; it does not choose the project folder, write the CSV, or export an image by itself. Treat game scripts as executable code, not as harmless data.</p></article>
</div>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.ProcSys">Processing System</a></h3><p style="margin:0">ProcSys keeps project files, card values, and the preview working together as you edit.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.GameEditor">GameEditor</a></h3><p style="margin:0">Game Editor organizes the shared scripts used throughout a game.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Globals.ImportSystem">ImportSystem</a></h3><p style="margin:0">Imports let a game divide reusable helpers into separate source files.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Forge">Forge</a></h3><p style="margin:0">Forge is the visual workbench that turns selected card data and drawing instructions into artwork.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Game scripts use the commands exposed here. Private implementation entries are reference material and are not available inside the script environment.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual functions, inputs, and results.</p>
</section>
!]]
local tEnv = { --TODO QUESTION do i need to protect this?
    --[[!
    @fqxn CFS.UserEnv.Functions.assert
    @pulsarlua function assert
    @desc Returns all supplied arguments when the first value is true or truthy; otherwise raises an error with the supplied message. Zero and empty strings are truthy in Lua.
    @param any vValue Value to check.
    @param any vMessage Optional error message.
    @ret any ... Original arguments on success.
    @example
    local nCost = assert(tonumber("3"), "Cost must be a number.");
    !]]
    assert           = assert,
    --[[!
    @fqxn CFS.UserEnv.Functions.error
    @pulsarlua function error
    @desc Raises the supplied error value and stops the current call unless a protected caller catches it. An optional level controls which caller location is reported; zero omits the location prefix.
    @param any vMessage Error value.
    @param number nLevel Optional stack level; defaults to one.
    @example
    error("The card needs a name.");
    !]]
    error            = error,
    --[[!
    @fqxn CFS.UserEnv.Functions.ipairs
    @pulsarlua function ipairs
    @desc Returns an iterator that traverses a table by increasing integer keys, starting at index 1 and continuing until a nil value is encountered. Intended for array-like tables.
    @example
    local t = { "a", "b", "c" }
    for i, v in ipairs(t) do
        print(i, v)
    end
    !]]
    ipairs           = ipairs,
    --[[!
    @fqxn CFS.UserEnv.Functions.pairs
    @pulsarlua function pairs
    @desc Returns an iterator that visits all key–value pairs in a table. The traversal order is unspecified and should not be relied upon.
    @example
    local t = { x = 10, y = 20 }
    for k, v in pairs(t) do
        print(k, v)
    end
    !]]
    pairs            = pairs,
    --[[!
    @fqxn CFS.UserEnv.Functions.tonumber
    @pulsarlua function tonumber
    @desc Attempts to convert its argument to a number. If the conversion is not possible, it returns nil. An optional base may be supplied for string conversion.
    @example
    local n = tonumber("10")
    local h = tonumber("FF", 16)
    !]]
    tonumber         = tonumber,
    --[[!
    @fqxn CFS.UserEnv.Functions.tostring
    @pulsarlua function tostring
    @desc Converts a value to its human-readable string form. This function never fails and always returns a string.
    @example
    local s = tostring(123)
    print(s)
    !]]
    tostring         = tostring,
    --[[!
    @fqxn CFS.UserEnv.Functions.type
    @pulsarlua function type
    @desc Returns a string describing the type of its argument, such as "number", "string", or "table".
    @example
    print(type(42))        -- "number"
    print(type({}))        -- "table"
    !]]
    type             = rawtype,
    --[[!
    @fqxn CFS.UserEnv.Functions.p
    @pulsarlua function p
    @desc An alias of <a href="#CFS.UserEnv.Functions.print">print</a>
    @inheritdoc CFS.UserEnv.Functions.print
    !]]
    p                = p,
    --[[!
    @fqxn CFS.UserEnv.Functions.pcall
    @pulsarlua function pcall
    @desc Calls a function with the supplied arguments under error protection. Returns true followed by its results on success, or false followed by the error value on failure. Catching an error does not automatically log it.
    @param function fAction Function to call.
    @param varargs ... Arguments for the function.
    @ret boolean bOK Whether the call succeeded.
    @ret any ... Function results or the error value.
    @example
    local bOK, vResult = pcall(function() return tonumber("3"); end);
    !]]
    pcall            = pcall,
    --[[!
    @fqxn CFS.UserEnv.Functions.print
    @pulsarlua function print
    @desc Outputs a textual representation of its arguments, separated by tabs and followed by a newline.
    @example
    print("hello", 123, true)
    !]]
    print            = p,
    --[[!
    @fqxn CFS.UserEnv.Functions.serialize
    @pulsarlua function serialize
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
    @fqxn CFS.UserEnv.Functions.deserialize
    @pulsarlua function deserialize
    @desc Reconstructs a Lua value from a serialized Lua-expression string produced by serialize. The input string is executed in a controlled manner to recreate the original value, including complex tables and registered object types.
    @param string sRawData Serialized Lua expression.
    @ret any vResult Deserialized Lua value.
    @example
    local sSerializedConfig = "{ [\"Width\"] = 1920, [\"Height\"] = 1080 }"
    local tConfigData = deserialize(sSerializedConfig)
    !]]
    deserialize      = deserialize,
    --[[!
    @fqxn CFS.UserEnv.Functions.select
    @pulsarlua function select
    @desc Provides access to variable argument lists. Can be used to count arguments or extract values by position.
    @example
    local a, b = select(1, "x", "y", "z");
    local n    = select("#", "x", "y", "z");
    !]]
    select           = select,
    --Forge            = tForgeDecoy,
    --ProcSys          = tProcSysDecoy,
    --[[!
    @fqxn CFS.UserEnv.Functions.Exists
    @pulsarlua function Exists
    @desc Checks whether a file exists at a virtual resource-relative path, using the import system's path sanitizer and FS.GetResourceRoot. The root is the active game's folder or the bundled source resources of an imported standalone card set. Returns false for missing files and directories. Invalid paths and an absent resource root raise errors. This performs the same lexical path validation as Import; it does not read or execute the file.
    @param string sPath Relative file path, such as "Images/Example.png". Absolute paths, dot segments, and invalid filename forms are rejected by the shared sanitizer.
    @ret boolean bExists Whether the resolved file exists.
    @example
    if Exists("Images/Example.png") then
        print("Example artwork is available.");
    end
    @vis public
    !]]
    Exists           = function(sPath)
        local sRelative = require("Globals.ImportSystem").SanitizePath(sPath);
        local pRoot     = FS.GetResourceRoot();
        assert(rawtype(pRoot) == "string" and pRoot ~= "", "Exists requires an active resource root.");
        return wx.wxFileExists(io.normalizepath(pRoot.."/"..sRelative));
    end,
    LogClear         = Log.ClearWindow, --TODO NOTE THESE
    Log              = Log.Note,
    --[[!
    @fqxn CFS.UserEnv.Functions.Import
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
    @fqxn CFS.UserEnv.Functions.Uptime
    @pulsarlua function Uptime
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
    --[[!
    @fqxn CFS.UserEnv.Functions.xpcall
    @pulsarlua function xpcall
    @desc Calls a function under error protection using a supplied error handler. Returns true followed by the function results on success, or false followed by the handler result on failure. The handler receives the error value; this does not expose the host debug library or automatically log errors.
    @param function fAction Function to call.
    @param function fHandler Error handler.
    @param varargs ... Arguments for the function.
    @ret boolean bOK Whether the call succeeded.
    @ret any ... Function results or the handled error.
    @example
    local bOK, sResult = xpcall(function() error("Example failure"); end,
        function(vError) return "Handled: "..tostring(vError); end);
    !]]
    xpcall           = xpcall,
    --TODO UPDATE THESE DOX
    --[[!
    @fqxn CFS.UserEnv.Constants.STYLE
    @pulsarlua table STYLE
    @inheritdoc CFS.Classes.FontStyle.Methods.Get
    !]]
    STYLE           = STYLE,
};

-- decoy -> real backing table map (weak keys so nothing is kept alive)
local tEnvBacking = setmetatable({}, { __mode = "k" })

--[[!
@fqxn CFS.UserEnv.Private.Functions.InjectEnv
@desc Validates the environment name and publishes a protected view over the supplied table.
@param any sName Name.
@param any tActual Actual.
@vis private
!]]
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
@fqxn CFS.UserEnv.Namespaces.base64
@pulsarlua table base64
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
    @fqxn CFS.UserEnv.Namespaces.base64.Functions.enc
    @pulsarlua function base64.enc
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
    @fqxn CFS.UserEnv.Namespaces.base64.Functions.dec
    @pulsarlua function base64.dec
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
@fqxn CFS.UserEnv.Namespaces.Color
@pulsarlua table Color
@desc Constructs native colors for game configuration and Forge drawing. RGB supplies red, green, and blue channels; RGBA also supplies opacity. These constructors return native color objects, not packed color numbers.
!]]
InjectEnv("Color", {
    --[[!
    @fqxn CFS.UserEnv.Namespaces.Color.Functions.RGB
    @pulsarlua function Color.RGB
    @desc Creates a native color from red, green, and blue channels.
    @param number nRed Red channel, from 0 to 255.
    @param number nGreen Green channel, from 0 to 255.
    @param number nBlue Blue channel, from 0 to 255.
    @return userdata oColor Native color for configuration or drawing.
    !]]
    RGB     = Color.RGB,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.Color.Functions.RGBA
    @pulsarlua function Color.RGBA
    @desc Creates a native color with opacity. Alpha 0 is transparent and alpha 255 is opaque.
    @param number nRed Red channel, from 0 to 255.
    @param number nGreen Green channel, from 0 to 255.
    @param number nBlue Blue channel, from 0 to 255.
    @param number nAlpha Opacity, from 0 to 255.
    @return userdata oColor Native color for configuration or drawing.
    !]]
    RGBA    = Color.RGBA,
});

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
                                                                                ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
                                                                                ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
                                                                                █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
                                                                                ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
                                                                                ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
                                                                                ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
                                                                                ]]
--[[!@fqxn CFS.UserEnv.Namespaces.Forge
    @inheritdoc CFS.Modules.Forge!]]
local tForge        = {};
local tForgeKeys    = {};
if (Forge ~= nil) then
InjectEnv("Forge", {
    --[[!@fqxn CFS.UserEnv.Namespaces.Forge.Functions.DrawImage
        @inheritdoc CFS.Modules.Forge.Functions.DrawImage!]]
    DrawRectangle   = Forge.DrawRectangle,
    GetOutputInfo   = Forge.GetOutputInfo,
    DrawImage       = Forge.DrawImage,
    --[[!@fqxn CFS.UserEnv.Namespaces.Forge.Functions.DrawText
        @inheritdoc CFS.Modules.Forge.Functions.DrawText!]]
    DrawText        = Forge.DrawText,
    --[[!@fqxn CFS.UserEnv.Namespaces.Forge.Functions.DrawStyledText
        @inheritdoc CFS.Modules.Forge.Functions.DrawStyledText!]]
    DrawStyledText  = Forge.DrawStyledText,
});
end


--[[!
@fqxn CFS.UserEnv.Namespaces.geometry
@pulsarlua table geometry
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
    @fqxn CFS.UserEnv.Namespaces.geometry.Functions.fitrect
    @pulsarlua function geometry.fitrect
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
    @fqxn CFS.UserEnv.Namespaces.geometry.Functions.rectcontains
    @pulsarlua function geometry.rectcontains
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
    @fqxn CFS.UserEnv.Namespaces.geometry.Functions.rectcontainsfully
    @pulsarlua function geometry.rectcontainsfully
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
@fqxn CFS.UserEnv.Namespaces.math
@pulsarlua table math
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
    @fqxn CFS.UserEnv.Namespaces.math.Functions.abs
    @pulsarlua function math.abs
    @desc
        Returns the absolute (non-negative) value of a number.
    @example
    local v = math.abs(-5)   -- 5
    !]]
    abs                 = math.abs,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.acos
    @pulsarlua function math.acos
    @desc
        Computes the arc cosine of a value, expressed in radians.
        The input must be within the range -1 to 1.
    @example
    local a = math.acos(1)   -- 0
    !]]
    acos                = math.acos,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.asin
    @pulsarlua function math.asin
    @desc
        Computes the arc sine of a value, in radians.
        Valid only for values between -1 and 1.
    @example
    local a = math.asin(0)
    !]]
    asin                = math.asin,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.atan
    @pulsarlua function math.atan
    @desc
        Returns the arc tangent of a value, measured in radians.
    @example
    local a = math.atan(1)
    !]]
    atan                = math.atan,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.atan2
    @pulsarlua function math.atan2
    @desc
        Computes the arc tangent using two coordinates,
        preserving the correct quadrant of the result.
    @example
    local angle = math.atan2(y, x)
    !]]
    atan2               = math.atan2,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.ceil
    @pulsarlua function math.ceil
    @desc
        Rounds a number upward to the nearest integer
        that is greater than or equal to the input.
    @example
    local n = math.ceil(2.3)   -- 3
    !]]
    ceil                = math.ceil,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.clamp
    @pulsarlua function math.clamp
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
    @fqxn CFS.UserEnv.Namespaces.math.Functions.convertbase
    @pulsarlua function math.convertbase
    @desc Converts a numeric string from one base to another.
    The input is first interpreted using the source base, then re-encoded
    using the target base.
    @example
    local v = math.convertbase("FF", 16, 10) -- "255"
    !]]
    convertbase         = math.convertbase,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.cos
    @pulsarlua function math.cos
    @desc Calculates the cosine of an angle given in radians.
    @example
    local c = math.cos(math.pi)
    !]]
    cos                 = math.cos,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.counting
    @pulsarlua function math.counting
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
    @fqxn CFS.UserEnv.Namespaces.math.Functions.deg
    @pulsarlua function math.deg
    @desc Converts an angle from radians into degrees.
    @example
    local d = math.deg(math.pi) -- 180
    !]]
    deg                 = math.deg,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.drift
    @pulsarlua function math.drift
    @desc Applies a random additive offset within a symmetric range.
    The result varies by up to the drift amount in either direction.
    @example
    local v = math.drift(10, 2)
    !]]
    drift               = math.drift,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.driftf
    @pulsarlua function math.driftf
    @desc Applies a proportional random variation to a value.
    The drift is applied as a ratio of the original value.
    @example
    local v = math.driftf(100, 0.1)
    !]]
    driftf              = math.driftf,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Constants.e
    @pulsarlua number math.e
    @desc Mathematical constant representing Euler’s number.
    Used as the base of natural logarithms.
    @example
    local v = math.e
    !]]
    e                   = math.e,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.exp
    @pulsarlua function math.exp
    @desc
        Computes the exponential value e raised to the given power.
    @example
    local v = math.exp(1)
    !]]
    exp                 = math.exp,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.factorial
    @pulsarlua function math.factorial
    @desc Computes the factorial of a positive integer using iterative multiplication.
    The factorial is the product of all integers from 1 to the given value.
    @param number nVal Integer value.
    @ret number nResult Factorial of the input.
    @ex
    math.factorial(5)   -- 120
    !]]
    factorial           = math.factorial,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.floor
    @pulsarlua function math.floor
    @desc
        Rounds a number downward to the nearest integer
        that is less than or equal to the input.
    @example
    local n = math.floor(2.9)   -- 2
    !]]
    floor               = math.floor,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.fmod
    @pulsarlua function math.fmod
    @desc
        Returns the remainder of dividing two numbers,
        keeping the sign of the first operand.
    @example
    local r = math.fmod(7, 3)   -- 1
    !]]
    fmod                = math.fmod,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.gcf
    @pulsarlua function math.gcf
    @desc Calculates the greatest common factor of two numbers using the Euclidean algorithm.
    The result is always non-negative.
    @param number nNum First value.
    @param number nDen Second value.
    @ret number nResult Greatest common factor.
    @ex
    math.gcf(24, 18)    -- 6
    !]]
    gcf                 = math.gcf,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Constants.huge
    @pulsarlua number math.huge
    @desc Represents a value larger than any other numeric value, typically used as positive infinity.
    @example
    local inf = math.huge
    !]]
    huge                = math.huge,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.inttorgb
    @pulsarlua function math.inttorgb
    @desc Converts a packed integer color value into red, green, and blue components.
    @example
    local r, g, b = math.inttorgb(0xFF00FF)
    !]]
    inttorgb            = math.inttorgb,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.iseven
    @pulsarlua function math.iseven
    @desc Tests whether a numeric value is evenly divisible by two.
    @param number nValue Input value.
    @ret boolean bIsEven True if the value is even.
    @ex
    math.iseven(4)      -- true
    !]]
    iseven              = math.iseven,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.isinteger
    @pulsarlua function math.isinteger
    @desc Determines whether a numeric value represents an exact integer.
    @example
    local bIsInt = math.isinteger(4.0) -- true
    !]]
    isinteger           = math.isinteger,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.isodd
    @pulsarlua function math.isodd
    @desc Tests whether a numeric value is not evenly divisible by two.
    @param number nValue Input value.
    @ret boolean bIsOdd True if the value is odd.
    @ex
    math.isodd(7)       -- true
    !]]
    isodd               = math.isodd,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.log
    @pulsarlua function math.log
    @desc Computes the natural logarithm of a number, or a logarithm with an optional base.
    @example
    local n = math.log(8, 2)   -- 3
    !]]
    log                 = math.log,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.max
    @pulsarlua function math.max
    @desc Returns the largest value among its arguments.
    @example
    local m = math.max(1, 5, 3)
    !]]
    max                 = math.max,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.min
    @pulsarlua function math.min
    @desc Returns the smallest value among its arguments.
    @example
    local m = math.min(1, 5, 3)
    !]]
    min                 = math.min,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.modf
    @pulsarlua function math.modf
    @desc Splits a number into its integer and fractional components.
    @example
    local i, f = math.modf(3.14)
    !]]
    modf                = math.modf,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Constants.pi
    @pulsarlua number math.pi
    @desc A constant representing the mathematical value π.
    @example
    local c = 2 * math.pi
    !]]
    pi                  = math.pi,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.rad
    @pulsarlua function math.rad
    @desc Converts an angle from degrees to radians.
    @example
    local r = math.rad(180)
    !]]
    rad                 = math.rad,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.random
    @pulsarlua function math.random
    @desc Produces pseudo-random numbers.
        May return a float in [0,1) or an integer within a range.
    @example
    local r1 = math.random()
    local r2 = math.random(1, 10)
    !]]
    random              = math.random,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.randomf
    @pulsarlua function math.randomf
    @desc Generates a random floating-point number within a given range.
    The result has fixed decimal precision.
    @example
    local v = math.randomf(0.5, 0.95)
    !]]
    randomf             = math.randomf,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.randomseed
    @pulsarlua function math.randomseed
    @desc Sets the initial seed for the random number generator.
    @example
    math.randomseed(os.time())
    !]]
    randomseed          = math.randomseed,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.ratio
    @pulsarlua function math.ratio
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
    @fqxn CFS.UserEnv.Namespaces.math.Functions.rgbtohex
    @pulsarlua function math.rgbtohex
    @desc Converts red, green, and blue components into a hexadecimal color value.
    @example
    local nHex = math.rgbtohex(255, 128, 0)
    !]]
    rgbtohex            = math.rgbtohex,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.rgbtoint
    @pulsarlua function math.rgbtoint
    @desc Packs red, green, and blue components into a single integer value.
    @example
    local nINt = math.rgbtoint(255, 0, 255)
    !]]
    rgbtoint            = math.rgbtoint,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.sin
    @pulsarlua function math.sin
    @desc Calculates the sine of an angle given in radians.
    @example
    local s = math.sin(math.pi / 2)
    !]]
    sin                 = math.sin,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.sqrt
    @pulsarlua function math.sqrt
    @desc Returns the square root of a non-negative number.
    @example
    local s = math.sqrt(16)
    !]]
    sqrt                = math.sqrt,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.sum
    @pulsarlua function math.sum
    @desc Returns the total of all numeric arguments provided.
    @example
    local t = math.sum(1, 2, 3, 4)
    !]]
    sum                 = math.sum,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.tan
    @pulsarlua function math.tan
    @desc Calculates the tangent of an angle expressed in radians.
    @example
    local t = math.tan(math.pi / 4)
    !]]
    tan                 = math.tan,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.tointeger
    @pulsarlua function math.tointeger
    @desc Converts a value to an integer if it represents an exact integer numeric value.
    @example
    local i = math.tointeger(3.0)
    !]]
    tointeger           = math.tointeger,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.type
    @pulsarlua function math.type
    @desc Returns whether a number is classified as an integer or a floating-point value.
    @example
    print(math.type(3))     -- "integer"
    print(math.type(3.1))   -- "float"
    !]]
    type                = math.type,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.ult
    @pulsarlua function math.ult
    @desc Compares two integers as unsigned values.
    Returns true if the first value is smaller.
    @example
    local ok = math.ult(0xFFFFFFFF, 1)
    !]]
    ult                 = math.ult,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.whole
    @pulsarlua function math.whole
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
local tAllowedMetaMethods = {   __index = true, __newindex  = true, __len    = true, __tostring = true,
                                __call  = true, __concat    = true, __pairs  = true, __ipairs   = true,
                                __add   = true, __sub       = true, __mul    = true, __div      = true,
                                __mod   = true, __pow       = true, __unm    = true, __eq       = true,
                                __lt    = true, __le        = true};
InjectEnv("table", { --TODO DOX
    concat  = table.concat,
    insert  = table.insert,
    move    = table.move,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.table.Functions.new
    @desc Creates a read-only shadow exposing only keys allowed by the supplied specification.
    @param any tSpec Spec.
    @vis public
    !]]
    new     = function(tSpec)
        local tNew      = {};
        local tNewMeta  = {};

        if (rawtype(tSpec) == "table") then

            for sIndex, bAllowed in pairs(tAllowedMetaMethods) do

                if (bAllowed and rawtype(tSpec[sIndex]) == "function") then
                    tNewMeta[sIndex] = tSpec[sIndex];
                end

            end

        end

        tNewMeta.__metatable = "locked";

        return setmetatable(tNew, tNewMeta);
    end,
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
local tProcSysKeys = {}; --tracks processing-owned entries in the base table.
local tUserKeys    = {}; --tracks user-owned entries in the base table.


-- Preserve the built-in root entries before any game adds or replaces names.
local tBuiltIns = {};

for sKey, vValue in pairs(tEnv) do
    tBuiltIns[sKey] = vValue;
end




                                                                        --[[
                                                                        ███████╗██╗   ██╗███╗   ██╗ ██████╗████████╗██╗ ██████╗ ███╗   ██╗███████╗
                                                                        ██╔════╝██║   ██║████╗  ██║██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
                                                                        █████╗  ██║   ██║██╔██╗ ██║██║        ██║   ██║██║   ██║██╔██╗ ██║███████╗
                                                                        ██╔══╝  ██║   ██║██║╚██╗██║██║        ██║   ██║██║   ██║██║╚██╗██║╚════██║
                                                                        ██║     ╚██████╔╝██║ ╚████║╚██████╗   ██║   ██║╚██████╔╝██║ ╚████║███████║
                                                                        ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝
                                                                        ]]
local tUserEnv = {
    --[[!
    @fqxn CFS.Modules.UserEnv.Functions.Get
    @pulsarlua function UserEnv.Get
    @desc Returns the current script execution environment.
    @vis public
    !]]
    Get = function()
        return tEnv;
    end,
    -- Returns a numerically-indexed, alphabetically-sorted list of callable commands
    -- exposed by tEnv (including decoy tables that expose their real members via __index = table).
    --
    -- Example output entries:
    --   "math.abs"
    --   "Forge.DrawImage"
    --   "Color.RGBA"
    --
    --[[!
    @fqxn CFS.Modules.UserEnv.Functions.GetCommandList
    @pulsarlua function UserEnv.GetCommandList
    @desc Collects callable paths from the user environment while avoiding repeated table traversal.
    @vis public
    !]]
    GetCommandList = function()
        local tRoot = tEnv -- upvalue

        local tVisited = {}
        local tOutSet  = {}
        local tOut     = {}

        --[[!
        @fqxn CFS.UserEnv.Private.Functions.AddCommand
        @desc Adds a nonempty callable command path once.
        @param any sPath Path.
        @vis private
        !]]
        local function AddCommand(sPath)
            if (sPath ~= "" and not tOutSet[sPath]) then
                tOutSet[sPath] = true
                tOut[#tOut + 1] = sPath
            end
        end

        --[[!
        @fqxn CFS.UserEnv.Private.Functions.EnumKeys
        @desc Collects string table keys for environment command traversal.
        @param any t T.
        @vis private
        !]]
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

        --[[!
        @fqxn CFS.UserEnv.Private.Functions.Walk
        @desc Traverses environment tables to discover callable command paths without revisiting tables.
        @param any t T.
        @param any sPrefix Prefix.
        @vis private
        !]]
        local function Walk(t, sPrefix)
            if (tVisited[t]) then return end
            tVisited[t] = true;

            for k in pairs(EnumKeys(t)) do
                local v = t[k];
                local sPath = sPrefix and (sPrefix .. "." .. k) or k;

                if (rawtype(v) == "function") then
                    AddCommand(sPath);
                elseif (rawtype(v) == "table") then
                    Walk(v, sPath);
                end

            end

        end

        Walk(tRoot, nil);
        table.sort(tOut, function(a, b) return a:lower() < b:lower() end);
        return tOut;
    end,
    --[[!
    @fqxn CFS.Modules.UserEnv.Functions.GetCompletionEntries
    @desc Collects current environment names and types without executing user functions or reading card values.
    !]]
    GetCompletionEntries = function()
        local tOut, tStack = {}, {};
        local function Walk(tInput, sPrefix, nDepth)
            if (tStack[tInput] or nDepth > 12) then return; end
            tStack[tInput] = true;
            local tActual = tInput == _tCFGDecoy and _tCFG or tEnvBacking[tInput] or tInput;
            for sKey, vValue in next, tActual do
                if (rawtype(sKey) == "string") then
                    local sName = require("Autocomplete").Path(sPrefix, sKey);
                    if (sName) then
                        local sKind = rawtype(vValue);
                        tOut[#tOut + 1] = {name = sName, kind = sKind};
                        if (sKind == "table" and sName ~= "_tRow") then Walk(vValue, sName, nDepth + 1); end
                    end
                end
            end
            tStack[tInput] = nil;
        end
        Walk(tEnv, "", 0);
        return tOut;
    end,
    --[[!
    @fqxn CFS.Modules.UserEnv.Functions.Refresh
    @pulsarlua function UserEnv.Refresh
    @desc Clears game-added root entries, restores the original built-ins, resets configuration, and clears tracked user and processing keys. Keeps the execution environment table and built-in namespace identities intact. Called when a game loads; ordinary ENV updates do not restore built-ins and may still replace them.
    @vis public
    !]]
    Refresh = function()
        require("Autocomplete").MarkDirty();

        for sKey in pairs(tEnv) do
            tEnv[sKey] = nil;
        end

        for sKey, vValue in pairs(tBuiltIns) do
            tEnv[sKey] = vValue;
        end

        _tCFG = {};
        _tCFGMeta.__index = _tCFG;
        tEnvBacking[_tCFGDecoy] = _tCFG;

        tUserKeys    = {};
        tProcSysKeys = {};

    end,
    --[[!
    @fqxn CFS.Modules.UserEnv.Functions.ProcSysUpdateRoot
    @pulsarlua function UserEnv.ProcSysUpdateRoot
    @desc Updates processing-owned environment root keys, optionally purging existing root content first.
    @param any tInput Input.
    @param any bPurge Purge.
    @vis public
    !]]
    ProcSysUpdateRoot = function(tInput, bPurge) --permits additions/replacement to/of existing keys or a full purge, then new items added
        require("Autocomplete").MarkDirty();

        if (rawtype(tInput) == "table") then

            if (bPurge) then
                --delete the previous user keys from the env
                for sKey in pairs(tProcSysKeys) do
                    tEnv[sKey] = nil;
                end

                tProcSysKeys = {};--reset the keys
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
    --[[!
    @fqxn CFS.Modules.UserEnv.Functions.UserUpdateCFG
    @pulsarlua function UserEnv.UserUpdateCFG
    @desc Replaces the exposed configuration table with supplied game configuration.
    @param any tInput Input.
    @vis public
    !]]
    UserUpdateCFG = function(tInput)
        require("Autocomplete").MarkDirty();
        _tCFG = {};

        if (rawtype(tInput) == "table") then
            _tCFG = tInput--table.shadowreadonly(tInput);
        end

        _tCFGMeta.__index = _tCFG;
        setmetatable(_tCFGDecoy, _tCFGMeta);

    end,
    --[[!
    @fqxn CFS.Modules.UserEnv.Functions.UserUpdateENV
    @pulsarlua function UserEnv.UserUpdateENV
    @desc Replaces user-defined environment entries with the supplied game environment table.
    @param any tInput Input.
    @vis public
    !]]
    UserUpdateENV = function(tInput) --TODO BUG update this to use protected env when able : the user table will get input thourgh forge constructor, then run through the safe env filter, then iterated over and dumped into main env table (error on overwriteing ofc.)
        require("Autocomplete").MarkDirty();
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
