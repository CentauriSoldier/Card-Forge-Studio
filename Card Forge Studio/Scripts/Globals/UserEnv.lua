local wx = require("wx");
local RNG = CoG.RNG;
local Color = {RGBA = wx.wxColour, RGB = wx.wxColour};
--[[!
@fqxn CFS.UserEnv.Private.Functions.p
@desc Formats supplied values into a logged user-environment message.
@param any ... Additional drawing arguments.
@vis private
@ret void none No values returned.

!]]
local function p(...)
    local tValues = {};
    for nIndex = 1, select("#", ...) do
        local vValue = select(nIndex, ...);
        tValues[nIndex] = rawtype(vValue) == "table" and serialize(vValue) or tostring(vValue);
    end
    CFS.Log.Debug(table.concat(tValues, "\t"));
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

-- ProcSys: globals supplied while a card set is loaded; no assignments belong here.
--[[!
@fqxn CFS.UserEnv.Constants._tRow
@pulsarlua table _tRow
@desc Read-only view of the current card row. During row processing it exposes the source row; during drawing it exposes the selected render row, using processed text for ordinary columns and returned Lua values for code columns. Access columns by case-insensitive name, such as _tRow.Name or _tRow["Card Name"], or by one-based column index. Missing columns return nil. The length operator #_tRow returns the column count, and ~_tRow returns the row number. Iterating with pairs(_tRow) yields column index, header, and value in column order. Assigning row entries raises an error; this view does not make nested column values recursively read-only. Studio supplies the view for the active processing or drawing context; it is not a general table of every card.
@example
local sName = _tRow.Name;
local vFirstColumn = _tRow[1];
for nColumn, sHeader, vValue in pairs(_tRow) do
    print(nColumn, sHeader, vValue);
end
!]]

--[[!
@fqxn CFS.UserEnv.Constants._TABLE
@pulsarlua number _TABLE
@desc Processing conversion marker with value 1. Exposed for scripts, but the current row processor final-value getter does not implement table conversion: passing this marker returns the column text unchanged.
!]]

--[[!
@fqxn CFS.UserEnv.Constants._NUMBER
@pulsarlua number _NUMBER
@desc Processing conversion marker with value 2. Pass it as the second argument to the row processor final-value getter to request numeric conversion. If conversion fails, the original column text is returned.
!]]

--[[!
@fqxn CFS.UserEnv.Constants._pCardSet
@pulsarlua string _pCardSet
@desc Virtual path identifying the active card set, formed by joining "/" with its UUID. It is supplied when a set loads, replaced when another set loads, and cleared when the set closes. This string is an identifier path; it does not change the path rules of Import or Exists.
!]]

--[[!
@fqxn CFS.UserEnv.Constants._sCardSetID
@pulsarlua string _sCardSetID
@desc UUID of the active card set. Use this for identity independent of the display name. Renaming the set does not change its UUID. Supplied when a set loads, replaced on a set switch, and cleared when the set closes.
!]]

--[[!
@fqxn CFS.UserEnv.Constants._sCardSetName
@pulsarlua string _sCardSetName
@desc Display name of the active card set, suitable for labels and headings. This name can change independently of the UUID. Studio updates it when card-set metadata reloads and clears it when the set closes.
!]]

--[[!
@fqxn CFS.UserEnv.Constants._nCardWidth
@pulsarlua number _nCardWidth
@desc Logical card width from the active card set metadata. Use it for horizontal drawing positions, spacing, and proportions. Studio updates it when card-set metadata reloads and clears it when the set closes.
!]]

--[[!
@fqxn CFS.UserEnv.Constants._nCardHeight
@pulsarlua number _nCardHeight
@desc Logical card height from the active card set metadata. Use it for vertical drawing positions, spacing, and proportions. Studio updates it when card-set metadata reloads and clears it when the set closes.
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


    @param any vMessage Error value to raise.
    @param number nLevel Optional stack level; defaults to 1. Zero omits the location prefix.
    @ret void none Does not return normally; raises an error.

    @example
    error("The card needs a name.");
    !]]
    error            = error,
    --[[!
    @fqxn CFS.UserEnv.Functions.ipairs
    @pulsarlua function ipairs
    @desc Returns an iterator that traverses a table by increasing integer keys, starting at index 1 and continuing until a nil value is encountered. Intended for array-like tables.
    @param table tInput Sequence to traverse until the first absent integer index.
    @ret function fIterator Iterator returning index and value.
    @ret table tState Original table.
    @ret number nInitial Initial index, zero.

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
    @param table tInput Table to traverse; its __pairs metamethod may supply custom iteration.
    @ret function fIterator Iterator function.
    @ret any vState Iterator state.
    @ret any vInitial Initial control value.

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
    @param any vValue Number or text to convert.
    @param number nBase Optional integer base from 2 through 36; requires string input.
    @ret number|nil nResult Converted number, or nil when the text cannot be converted.

    @example
    local n = tonumber("10")
    local h = tonumber("FF", 16)
    !]]
    tonumber         = tonumber,
    --[[!
    @fqxn CFS.UserEnv.Functions.tostring
    @pulsarlua function tostring
    @desc Converts a value to its string representation. A custom __tostring metamethod may run and may raise an error.
    @param any vValue Value to represent as text.
    @ret string sResult String representation.

    @example
    local s = tostring(123)
    print(s)
    !]]
    tostring         = tostring,
    --[[!
    @fqxn CFS.UserEnv.Functions.type
    @pulsarlua function type
    @desc Returns a string describing the type of its argument, such as "number", "string", or "table".
    @param any vValue Value to inspect.
    @ret string sType Native Lua type name, such as number, string, table, or userdata.

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
    @desc Records a DEBUG log entry containing the supplied arguments separated by tabs. Tables are serialized; other values use tostring. Use p as a shorter alias.
    @param any ... Values to log; tables are serialized and other values use tostring.
    @ret void none No values returned.

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
    @param number|string vIndex One-based index, negative index from the end, or "#" for the argument count.
    @param any ... Values to select from.
    @ret any ... Selected argument and all following arguments, or a single count when vIndex is "#".

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
    --[[!
    @fqxn CFS.UserEnv.Functions.LogClear
    @pulsarlua function LogClear
    @desc Clears the in-memory log entries and refreshes log listeners. Does not truncate the disk log.
    @ret void none No values returned.

    !]]
    LogClear         = CFS.Log.ClearWindow,
    --[[!
    @fqxn CFS.UserEnv.Functions.Log
    @pulsarlua function Log
    @desc Records a NOTE message in the disk and in-memory logs.

    @param string sMessage Message to record.
    @ret void none No values returned.

    !]]
    Log              = CFS.Log.Note,
    --[[!
    @fqxn CFS.UserEnv.Functions.Import
    @pulsarlua function Import
    @desc Loads and runs a Lua text file in the shared user environment. Paths are relative to the active resource root: normally the game folder, or the bundled Dependencies folder of an imported standalone set. Absolute paths and dot-directory segments are rejected. Runtime errors from the imported chunk return nil and an error value; path, file access, and compilation failures raise errors. Imported scripts can use the same environment globals as other game scripts.
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
    @desc Returns elapsed whole seconds as os.time() minus SANDBOX_TIME_START. This is a duration from the configured startup origin, not a calendar date. Because it uses the system clock, clock adjustments can affect the result.

    @ret number nSeconds Elapsed seconds from the startup origin.

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
    --[[!
    @fqxn CFS.UserEnv.Constants.STYLE
    @pulsarlua table STYLE
    @desc Read-only lookup of the loaded FontStyle objects by name. Names are matched case-insensitively; unknown or empty names return nil. Use STYLE["Heading"] to obtain a style. Direct assignment to STYLE entries is rejected.
    !]]
    STYLE           = STYLE,
};

-- decoy -> real backing table map (weak keys so nothing is kept alive)
local tEnvBacking = setmetatable({}, { __mode = "k" })

--[[!
@fqxn CFS.UserEnv.Private.Functions.InjectEnv
@desc Validates the environment name and publishes a protected view over the supplied table.
@param string sName Nonempty name of the namespace to publish.
@param table tActual Backing table exposed through the read-only namespace proxy.
@vis private
@ret table tDecoy Read-only namespace proxy.
@ret table tMeta Proxy metatable.

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
    @fqxn CFS.UserEnv.Namespaces.base64.Functions.dec
    @pulsarlua function base64.dec
    @desc Decodes Base64 text back into its original byte string.
    @param string sInput Base64 text to decode.
    @ret string sResult Decoded byte string.

    !]]
    dec = base64.dec,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.base64.Functions.enc
    @pulsarlua function base64.enc
    @desc Encodes a byte string as Base64 text. Encoding represents data as text; it does not encrypt the data.
    @param string sInput Byte string to encode.
    @ret string sResult Base64 encoded text.

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
--[[!
@fqxn CFS.UserEnv.Namespaces.CFG
@pulsarlua table CFG
@desc Read-only view of the configuration table returned by the active resource root Scripts/CFG.lua. Read entries as CFG.Name. Studio replaces the backing configuration when it reloads CFG; the namespace identity is retained. Nested values are the supplied values, not recursively protected copies.
!]]
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
    --[[!
    @fqxn CFS.UserEnv.Namespaces.Forge.Functions.DrawRectangle
    @pulsarlua function Forge.DrawRectangle
    @desc Draws a rectangle through the current native drawing context. Requires an active render pass.

    @param number nX Left position.
    @param number nY Top position.
    @param number nWidth Rectangle width.
    @param number nHeight Rectangle height.
    @param wxColour|number oFill Native fill color or packed RGBA value.
    @ret void none No values returned.

    !]]
    DrawRectangle   = Forge.DrawRectangle,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.Forge.Functions.GetOutputInfo
    @pulsarlua function Forge.GetOutputInfo
    @desc Returns a table with Width and Height fields containing the native card dimensions.
    @ret table tInfo Card dimensions with numeric Width and Height fields.

    !]]
    GetOutputInfo   = Forge.GetOutputInfo,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.Forge.Functions.DrawImage
    @pulsarlua function Forge.DrawImage
    @desc Draws an image onto the active card render target using the Forge image-loading and path checks.






    @param string sPath Image path relative to the active resource root.
    @param number nX Horizontal card-space position.
    @param number nY Vertical card-space position.
    @param number nWidth Optional draw width; defaults to native image width.
    @param number nHeight Optional draw height; defaults to native image height.
    @ret void none No values returned.

    !]]
    DrawImage       = Forge.DrawImage,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.Forge.Functions.DrawImageCircular
    @pulsarlua function Forge.DrawImageCircular
    @desc Draws a centered circular portrait during an active render pass. Center-crops the image without stretching, preserves source transparency and softens the circular edge. Uses Forge's game-relative path checks, missing-art fallback and source cache. One circular bitmap per source is reused across draw sizes and discarded with source invalidation. X/Y are the circle center, unlike DrawImage's top-left coordinates. Source artwork is unchanged; preview and PNG export share the result.
    @param string sPath Image path relative to the active resource root.
    @param number nX Horizontal center in card-space coordinates.
    @param number nY Vertical center in card-space coordinates.
    @param number nDiameter Optional positive finite diameter; defaults to the smaller source dimension.
    @ret void none No values returned.
    @error Requires an active render pass and valid image path. Supplied diameter must be positive and finite. Image decoding or masking failures raise an error.
    @ex
    Forge.DrawImageCircular("Cards/Portrait.png", 412.5, 350, 500);
    !]]
    DrawImageCircular = Forge.DrawImageCircular,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.Forge.Functions.DrawImageOval
    @pulsarlua function Forge.DrawImageOval
    @desc Draws a centered oval portrait during an active render pass. Center-crops to the requested width-to-height ratio, rounded to source pixels, rather than stretching the portrait. Preserves source transparency and applies a soft ellipse edge. Uses Forge's existing path validation, missing-art fallback and source cache. Masked bitmaps are reused by crop dimensions, with at most 16 crop ratios per source, and invalidated with the source. X/Y are the oval center. Source artwork is unchanged; preview and PNG export share the result.
    @param string sPath Image path relative to the active resource root.
    @param number nX Horizontal center in card-space coordinates.
    @param number nY Vertical center in card-space coordinates.
    @param number nWidth Positive finite oval width in card-space coordinates.
    @param number nHeight Positive finite oval height in card-space coordinates.
    @ret void none No values returned.
    @error Requires an active render pass and valid image path. Dimensions must be positive and finite. Image decoding or masking failures raise an error.
    @ex
    Forge.DrawImageOval("Cards/Portrait.png", 412.5, 350, 320, 400);
    !]]
    DrawImageOval   = Forge.DrawImageOval,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.Forge.Functions.DrawImageCropped
    @pulsarlua function Forge.DrawImageCropped
    @desc Draws an image centered in a rectangular window using a centered cover crop instead of stretching. Width-to-height matching is rounded to source pixels. Retains source transparency but does not add rounded corners or a frame mask. Uses Forge's existing path validation, missing-art fallback and source cache. Crop bitmaps are reused by crop dimensions, with at most 16 ratios per source, and invalidated with their source. X/Y are the window center. Source files and other draw functions are unchanged; preview and PNG export share the result.
    @param string sPath Image path relative to the active resource root.
    @param number nX Horizontal center in card-space coordinates.
    @param number nY Vertical center in card-space coordinates.
    @param number nWidth Positive finite destination width.
    @param number nHeight Positive finite destination height.
    @ret void none No values returned.
    @error Requires an active render pass, a valid image path and positive finite dimensions. Decoding or crop creation failures raise an error.
    @ex
    Forge.DrawImageCropped("Cards/Structure/Base/Land/Ashpoint.png", 485, 330, 460, 300);
    !]]
    DrawImageCropped = Forge.DrawImageCropped,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.Forge.Functions.DrawImageTinted
    @pulsarlua function Forge.DrawImageTinted
    @desc Draws an image with multiplicative RGBA tinting during an active render pass. Optional selective mode replaces the hue/saturation of matching source pixels while retaining HSV brightness, texture and unselected RGB/alpha. Pass true for amber (Hue=40, Range=20, Feather=10, Saturation=0.2), or a table overriding those fields. Hue and Range/Feather are degrees; Saturation is 0..1 with a soft 0.15 transition above the threshold. Tint RGB supplies the replacement hue/saturation; black produces black. Tint alpha affects only the selection. Selection parameters are included in the existing variant cache key. Each source RGB channel is multiplied by the matching tint channel divided by 255; source alpha is multiplied by tint alpha. In whole-image mode, white with full opacity preserves the image. Uses the same relative path checks and missing-art fallback as DrawImage. Source artwork is never modified. Tinted bitmaps are cached separately, with at most 64 variants per cached source; normal source invalidation discards its variants. Preview and PNG export use the same draw function.
    @param string sPath Image path relative to the active resource root.
    @param number nX Horizontal card-space position.
    @param number nY Vertical card-space position.
    @param number nWidth Draw width, or nil for native width.
    @param number nHeight Draw height, or nil for native height.
    @param wxColour oTint Native color, such as Color.RGBA(255, 80, 80, 255).
    @param boolean|table vSelective Optional; nil/false retains whole-image multiplication, true selects amber, or use {Hue=40, Range=20, Feather=10, Saturation=0.2}.
    @ret void none No values returned.
    !]]
    DrawImageTinted = Forge.DrawImageTinted,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.Forge.Functions.DrawText
    @pulsarlua function Forge.DrawText
    @desc Draws plain text onto the active card render target using a single style.

            <p>
              Renders text using the specified FontStyle during the active card draw pass.
              This function is intended for use by CardSet <code>Draw</code> scripts and supports
              optional centering, rotation, and custom wrapping behavior.
            </p>

            <h3>Behavior</h3>
            <ul>
              <li>Uses the specified style from <code>Forge.STYLE</code>.</li>
              <li>Optionally centers text around the provided coordinates.</li>
              <li>Supports rotated text via an angle parameter.</li>
              <li>Supports custom line-wrapping through a user-supplied wrapper function.</li>
            </ul>

            <h3>Notes</h3>
            <ul>
              <li>Must be called from within an active card draw pass.</li>
              <li>Text is drawn into the card image layer, not the utility overlay.</li>
              <li>Returns the final draw position and measured size of the last rendered line.</li>
            </ul>
    @param string  sStyle   Name of the FontStyle to use.
    @param number  nRawX    Base X position in card-space coordinates.
    @param number  nRawY    Base Y position in card-space coordinates.
    @param string  sText    Text to draw.
    @param boolean vCenterX Optional horizontal centering flag.
    @param boolean vCenterY Optional vertical centering flag.
    @param number  vAngle   Optional rotation angle (degrees).
    @param function|nil vWrap Optional wrapping function.
    @param any ... Extra arguments passed to the optional wrapping callback.
    @ret number nX       Final X position of the last line drawn.
    @ret number nY       Final Y position of the last line drawn.
    @ret number nWidth   Width of the rendered text block.
    @ret number nHeight  Height of the rendered text block.
    !]]
    DrawText        = Forge.DrawText,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.Forge.Functions.DrawTextEffect
    @pulsarlua function Forge.DrawTextEffect
    @desc Draws a native UTF-8 font run with a named material effect. Font family, size, weight, italic and letter spacing come from the Style as-is; there is no fitting, shrinking or glyph normalization. Zero letter spacing uses native run shaping; nonzero spacing follows FontStyle's code-point layout. Material replaces Style color, shadow, outline, glow and background. Built-in Stamped adds steel shading, edge bevels and a dark extrusion. Game processors are loaded from FS.Game.Effects in UserEnv and take precedence over built-ins. Changed game source reloads on the next draw. Centering uses the complete run raster including processor padding. Completed runs are cached; effects must be deterministic.
    @param string sStyle Existing Style using any installed font.
    @param number nX Left edge, or horizontal center when bCenterX is true.
    @param number nY Top edge, or vertical center when bCenterY is true.
    @param string sText Single-line valid UTF-8 text, at most 4096 bytes.
    @param string sEffect Case-sensitive effect name, such as Stamped or a name returned by Scripts/Effects.lua.
    @param boolean bCenterX Optional horizontal centering; defaults to false.
    @param boolean bCenterY Optional vertical centering; defaults to false.
    @ret number nLeft Left edge of the rendered raster.
    @ret number nTop Top edge of the rendered raster.
    @ret number nWidth Rendered raster width including effect padding.
    @ret number nHeight Rendered raster height including effect padding.
    @error Requires an active render pass, valid Style/effect, finite coordinates and valid UTF-8 without line breaks. Invalid processors and rasters larger than two million pixels are rejected. No wrapping or rotation is performed.
    @ex Forge.DrawTextEffect("NAME", 412.5, 100, "Example", "Stamped", true, true);
    !]]
    DrawTextEffect  = Forge.DrawTextEffect,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.Forge.Functions.DrawTextCurved
    @pulsarlua function Forge.DrawTextCurved
    @desc Draws one plain UTF-8 line along an arc with its existing Style size and effects. X/Y locate the middle of the text line, not the circle center. The default upper arc has its middle higher than its ends; bBelow true reverses the curve while keeping text upright. Style-measured advances retain letter spacing and native pair spacing. Glyphs are drawn separately, so joined scripts and combining sequences are not shaped as a run. No wrapping, shrinking or stretching occurs. Existing text functions are unchanged.
    @param string sStyle Existing Style name.
    @param number nX Horizontal midpoint of the text arc.
    @param number nY Vertical midpoint of the central text line.
    @param string sText Plain valid UTF-8 single-line text; empty text draws nothing.
    @param number nRadius Positive finite radius; larger values flatten the arc.
    @param boolean bBelow Optional lower-arc direction, default false.
    @ret number nWidth Straight-line text advance, not the curved bounding width.
    @ret number nHeight Font line height, not the curved bounding height.
    @error Requires a render pass, valid Style, single-line UTF-8 text and positive finite radius. Text longer than a semicircle is rejected without resizing.
    @ex
    Forge.DrawTextCurved("NAME", 412.5, 175, "Eternal Warden", 650);
    !]]
    DrawTextCurved   = Forge.DrawTextCurved,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.Forge.Functions.DrawStyledText
    @pulsarlua function Forge.DrawStyledText
    @desc Draws text containing inline style markup onto the active card render target.

            <p>
              Renders text that includes inline style tags (e.g. <code>&lt;BOLD&gt;</code>,
              <code>&lt;ITALIC&gt;</code>) using multiple FontStyles in a single draw call.
              This function is intended for CardSet <code>Draw</code> scripts that require
              rich text composition.
            </p>

            <h3>Behavior</h3>
            <ul>
              <li>Parses inline style tags and resolves them against <code>Forge.STYLE</code>.</li>
              <li>Preserves style runs across wrapped lines.</li>
              <li>Uses ink-box layout to neutralize negative bearings and kerning artifacts.</li>
              <li>Supports centering, rotation, and custom wrapping behavior.</li>
            </ul>

            <h3>Notes</h3>
            <ul>
              <li>Must be called from within an active card draw pass.</li>
              <li>Tags that do not resolve to a known style fall back to the base style.</li>
              <li>Returns the top-left position and total size of the rendered text block.</li>
            </ul>
    @param string  sStyle   Base FontStyle name.
    @param number  nRawX    Base X position in card-space coordinates.
    @param number  nRawY    Base Y position in card-space coordinates.
    @param string  sText    Text with inline style markup.
    @param boolean vCenterX Optional horizontal centering flag.
    @param boolean vCenterY Optional vertical centering flag.
    @param number  vAngle   Optional rotation angle (degrees).
    @param function|nil vWrap Optional wrapping function.
    @param any ... Extra arguments passed to the optional wrapping callback.
    @ret number nX       Top-left X position of the rendered block.
    @ret number nY       Top-left Y position of the rendered block.
    @ret number nWidth   Total width of the rendered block.
    @ret number nHeight  Total height of the rendered block.
    !]]
    DrawStyledText  = Forge.DrawStyledText,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.Forge.Functions.DrawStyledTextFit
    @pulsarlua function Forge.DrawStyledTextFit
    @desc Draws styled text to a pixel width, with one Wrap or Shrink mode per newline-separated entry.
    Wrap retains font sizes and breaks long words at UTF-8 character boundaries. A single character
    wider than the limit remains at its original size. Shrink uniformly scales an entry and its
    effects onto one line when needed; it never enlarges text or changes saved styles. Wrapped
    continuations inherit their entry's mode. Entries stack vertically without a height limit.
    Blank entries reserve a base-style line. Existing inline-style parsing is shared with DrawStyledText.
    @param string sStyle Base FontStyle name.
    @param number nX Left position in card pixels.
    @param number nY Top position in card pixels.
    @param string sText Styled text with newline-separated entries.
    @param number nWidth Positive finite maximum line width in pixels.
    @param table tModes One "Wrap" or "Shrink" string for each entry, including blank entries.
    @ret number nX Left position of the rendered block.
    @ret number nY Top position of the rendered block.
    @ret number nWidth Measured block width.
    @ret number nHeight Measured block height, including wrapped lines.
    !]]
    DrawStyledTextFit = Forge.DrawStyledTextFit,
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
    @desc Fits an inner rectangle's aspect ratio to the largest size inside an outer rectangle, allowing enlargement. Returns a new rectangle at the outer origin or centered when requested; inputs remain unchanged. Inner width/height must be positive or the result is nil; a zero-size outer dimension produces a zero-size result. Coordinates and dimensions must be finite, and dimensions nonnegative.

    @param table tOuter Outer rectangle with x, y, width, and height.
    @param table tInner Inner rectangle with width and height.
    @param boolean|nil bCenter Center the result; defaults to false.
    @ret table|nil tRet The fitted rectangle, or nil for a degenerate inner rectangle.

    @example
    local tFitted = geometry.fitrect(tOuterRect, tImageRect, true)
    !]]
    fitrect             = math.geometry.fitrect,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.geometry.Functions.rectcontains
    @pulsarlua function geometry.rectcontains
    @desc Checks whether two rectangles overlap with positive area. Edge/corner contact and zero-area rectangles return false. This legacy name means overlap, not full containment; use rectcontainsfully for containment.

    @param table tMe First rectangle with x, y, width, and height.
    @param table tOther Second rectangle with x, y, width, and height.
    @ret boolean bRet Whether there is positive-area overlap.

    @example
    local bOverlaps = geometry.rectcontains(tRectA, tRectB)
    !]]
    rectcontains        = math.geometry.rectcontains,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.geometry.Functions.rectcontainsfully
    @pulsarlua function geometry.rectcontainsfully
    @desc Checks whether the first rectangle contains the entire second rectangle, including its boundary. Equal rectangles and contained zero-area rectangles qualify.

    @param table tMe Containing rectangle with x, y, width, and height.
    @param table tOther Candidate rectangle with x, y, width, and height.
    @ret boolean bRet Whether the second rectangle is fully contained.

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
    @param number nValue Input value; trigonometric input angles use radians.
    @ret number nResult Absolute value.

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
    @param number nValue Input value; trigonometric input angles use radians.
    @ret number nResult Arc cosine in radians.

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
    @param number nValue Input value; trigonometric input angles use radians.
    @ret number nResult Arc sine in radians.

    @example
    local a = math.asin(0)
    !]]
    asin                = math.asin,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.atan
    @pulsarlua function math.atan
    @desc
        Returns the arc tangent of a value, measured in radians.
    @param number nY Vertical coordinate or tangent value.
    @param number nX Optional horizontal coordinate; defaults to 1.
    @ret number nAngle Arc tangent in radians, using the signs of both coordinates to determine the quadrant.

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
    @param number nY Vertical coordinate or tangent value.
    @param number nX Optional horizontal coordinate; defaults to 1.
    @ret number nAngle Arc tangent in radians, using the signs of both coordinates to determine the quadrant.

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
    @param number nValue Input value; trigonometric input angles use radians.
    @ret number nResult Smallest integral value greater than or equal to the input.

    @example
    local n = math.ceil(2.3)   -- 3
    !]]
    ceil                = math.ceil,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.clamp
    @pulsarlua function math.clamp
    @desc Clamps a native number to inclusive ordered bounds. Infinity is supported; NaN and reversed bounds are rejected.

    @param number nValue The value.
    @param number nMinValue Minimum bound.
    @param number nMaxValue Maximum bound.
    @ret number nRet The clamped value.

    @ex
    math.clamp(15, 0, 10)   -- 10
    !]]
    clamp               = math.clamp,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.convertbase
    @pulsarlua function math.convertbase
    @desc Converts a signed integer string between bases 2 through 36, using uppercase output digits. Numeric input is accepted only for base 10. Values must lie in the exact integer range -9007199254740991 through 9007199254740991; invalid digits and overflow are rejected.
    @param string|number vInput The input integer.
    @param number nFromBase Input base.
    @param number nToBase Output base.
    @ret string sRet The converted integer.

    @example
    local v = math.convertbase("FF", 16, 10) -- "255"
    !]]
    convertbase         = math.convertbase,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.cos
    @pulsarlua function math.cos
    @desc Calculates the cosine of an angle given in radians.
    @param number nValue Input value; trigonometric input angles use radians.
    @ret number nResult Cosine of the angle in radians.

    @example
    local c = math.cos(math.pi)
    !]]
    cos                 = math.cos,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.counting
    @pulsarlua function math.counting
    @desc Converts a finite number's magnitude to a counting number (at least one). Floors by default, or rounds upward when requested.

    @param number nValue The input.
    @param boolean|nil bRaise Round upward; defaults to false.
    @ret number nRet The counting number.

    @ex
    math.counting(-2.7) -- 2
    !]]
    counting            = math.counting,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.deg
    @pulsarlua function math.deg
    @desc Converts an angle from radians into degrees.
    @param number nValue Input value; trigonometric input angles use radians.
    @ret number nResult Angle in degrees.

    @example
    local d = math.deg(math.pi) -- 180
    !]]
    deg                 = math.deg,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.drift
    @pulsarlua function math.drift
    @desc Adds a uniformly selected integer offset in the inclusive range [-nDrift, nDrift] to a finite value.
    @param number nValue The base value.
    @param number nDrift Nonnegative exact integer offset limit.
    @ret number nRet The shifted value.

    @example
    local v = math.drift(10, 2)
    !]]
    drift               = math.drift,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.driftf
    @pulsarlua function math.driftf
    @desc Applies a random proportional drift using randomf's four-decimal grid. A drift of 0.1 permits offsets up to ten percent of the value in either direction.
    @param number nValue The finite base value.
    @param number nDrift Nonnegative finite proportional limit.
    @ret number nRet The shifted value.

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
    @param number nValue Input value; trigonometric input angles use radians.
    @ret number nResult e raised to the input power.

    @example
    local v = math.exp(1)
    !]]
    exp                 = math.exp,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.factorial
    @pulsarlua function math.factorial
    @desc Calculates the factorial of a nonnegative integer, including 0! = 1. Returns a floating-point number; larger results may be rounded. Values above 170 are rejected to prevent infinity.

    @param number nValue Integer from 0 through 170.
    @ret number nRet The factorial.

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
    @param number nValue Input value; trigonometric input angles use radians.
    @ret number nResult Largest integral value less than or equal to the input.

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
    @param number nDividend Dividend.
    @param number nDivisor Nonzero divisor.
    @ret number nRemainder Remainder with division rounded toward zero.

    @example
    local r = math.fmod(7, 3)   -- 1
    !]]
    fmod                = math.fmod,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.gcf
    @pulsarlua function math.gcf
    @desc Gets the nonnegative greatest common factor of two exact integers. Signs are ignored; gcf(0, n) is abs(n), and gcf(0, 0) is zero.

    @param number nLeft First integer.
    @param number nRight Second integer.
    @ret number nRet The greatest common factor.

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
    @desc Unpacks a 24-bit color matching rgbtoint: red is the low byte, green the middle byte, and blue the high byte.
    @param number nColor Integer from 0 through 16777215.
    @ret number nR The red channel.
    @ret number nG The green channel.
    @ret number nB The blue channel.

    @example
    local r, g, b = math.inttorgb(0xFF00FF)
    !]]
    inttorgb            = math.inttorgb,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.iseven
    @pulsarlua function math.iseven
    @desc Checks whether a value is a finite integer divisible by two. Returns false for fractions and non-numbers.

    @param any vInput The value to check.
    @ret boolean bIsEven Whether the value is even.

    @ex
    math.iseven(4)      -- true
    !]]
    iseven              = math.iseven,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.isinteger
    @pulsarlua function math.isinteger
    @desc Checks whether a value is a native finite number with no fractional part. Returns false for non-numbers, NaN, and infinity.
    @param any vInput The value to check.
    @ret boolean bIsInteger Whether the value is an integer.

    @example
    local bIsInt = math.isinteger(4.0) -- true
    !]]
    isinteger           = math.isinteger,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.isodd
    @pulsarlua function math.isodd
    @desc Checks whether a value is a finite integer not divisible by two. Returns false for fractions and non-numbers.

    @param any vInput The value to check.
    @ret boolean bIsOdd Whether the value is odd.

    @ex
    math.isodd(7)       -- true
    !]]
    isodd               = math.isodd,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.log
    @pulsarlua function math.log
    @desc Computes the natural logarithm of a number, or a logarithm with an optional base.
    @param number nValue Value whose logarithm is required.
    @param number nBase Optional logarithm base; omitted means the natural logarithm.
    @ret number nResult Logarithm in the selected base.

    @example
    local n = math.log(8, 2)   -- 3
    !]]
    log                 = math.log,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.max
    @pulsarlua function math.max
    @desc Returns the largest value among its arguments.
    @param number ... One or more values to compare.
    @ret number nResult Largest supplied value.

    @example
    local m = math.max(1, 5, 3)
    !]]
    max                 = math.max,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.min
    @pulsarlua function math.min
    @desc Returns the smallest value among its arguments.
    @param number ... One or more values to compare.
    @ret number nResult Smallest supplied value.

    @example
    local m = math.min(1, 5, 3)
    !]]
    min                 = math.min,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.modf
    @pulsarlua function math.modf
    @desc Splits a number into its integer and fractional components.
    @param number nValue Value to split.
    @ret number nIntegral Integral part, rounded toward zero.
    @ret number nFraction Fractional part.

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
    @param number nValue Input value; trigonometric input angles use radians.
    @ret number nResult Angle in radians.

    @example
    local r = math.rad(180)
    !]]
    rad                 = math.rad,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.random
    @pulsarlua function math.random
    @desc Produces pseudo-random numbers.
        May return a float in [0,1) or an integer within a range.
    @param number nFirst Optional upper bound for a one-argument call, or lower bound for a two-argument call.
    @param number nLast Optional inclusive upper bound for a two-argument call.
    @ret number nResult With no arguments, a float in [0, 1). With one positive bound, an integer in [1, bound]; with two bounds, an integer in the inclusive interval. A single zero requests an integer across the full integer range.

    @example
    local r1 = math.random()
    local r2 = math.random(1, 10)
    !]]
    random              = math.random,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.randomf
    @pulsarlua function math.randomf
    @desc Generates a uniform random float on a four-decimal grid within inclusive finite bounds. Reversed bounds are accepted. Rejects intervals containing no grid value and scaled bounds outside the exact integer range. Uses the shared math.random stream.
    @param number nMinRaw One interval endpoint.
    @param number nMaxRaw The other endpoint.
    @ret number nResult The result.

    @example
    local v = math.randomf(0.5, 0.95)
    !]]
    randomf             = math.randomf,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.randomseed
    @pulsarlua function math.randomseed
    @desc Sets the initial seed for the random number generator.
    @param number nSeed Optional integer seed; omitted requests a generated seed.
    @param number nExtra Optional second integer seed; defaults to zero when nSeed is supplied.
    @ret number nSeed First seed component actually used.
    @ret number nExtra Second seed component actually used.

    @example
    math.randomseed(os.time())
    !]]
    randomseed          = math.randomseed,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.ratio
    @pulsarlua function math.ratio
    @desc Reduces an integer ratio by its greatest common factor, preserving each input sign. A single zero is supported; the ratio 0:0 is undefined and rejected.

    @param number nLeft Left integer.
    @param number nRight Right integer.
    @ret table tRatio The reduced left and right values.

    @ex
    math.ratio(1920, 1080) -- { left = 16, right = 9 }
    !]]
    ratio               = math.ratio,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.rgbtohex
    @pulsarlua function math.rgbtohex
    @desc Converts RGB channels to an uppercase 0xRRGGBB string. Finite integer channels are clamped to the range 0 through 255.
    @param number nR Red channel.
    @param number nG Green channel.
    @param number nB Blue channel.
    @ret string sHex The hexadecimal color.

    @example
    local nHex = math.rgbtohex(255, 128, 0)
    !]]
    rgbtohex            = math.rgbtohex,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.rgbtoint
    @pulsarlua function math.rgbtoint
    @desc Packs RGB integer channels in the range 0 through 255 into a 24-bit value. Retains the existing byte order: R + G * 256 + B * 65536. This byte order differs from the displayed 0xRRGGBB string.
    @param number nR Red channel.
    @param number nG Green channel.
    @param number nB Blue channel.
    @ret number nColor The packed color.

    @example
    local nINt = math.rgbtoint(255, 0, 255)
    !]]
    rgbtoint            = math.rgbtoint,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.sin
    @pulsarlua function math.sin
    @desc Calculates the sine of an angle given in radians.
    @param number nValue Input value; trigonometric input angles use radians.
    @ret number nResult Sine of the angle in radians.

    @example
    local s = math.sin(math.pi / 2)
    !]]
    sin                 = math.sin,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.sqrt
    @pulsarlua function math.sqrt
    @desc Returns the square root of a non-negative number.
    @param number nValue Input value; trigonometric input angles use radians.
    @ret number nResult Square root.

    @example
    local s = math.sqrt(16)
    !]]
    sqrt                = math.sqrt,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.sum
    @pulsarlua function math.sum
    @desc Adds all supplied finite numbers in argument order. No arguments returns zero; nil holes, non-numbers, and nonfinite results are rejected.
    @param number ... Values to add.
    @ret number nRet The sum.

    @example
    local t = math.sum(1, 2, 3, 4)
    !]]
    sum                 = math.sum,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.tan
    @pulsarlua function math.tan
    @desc Calculates the tangent of an angle expressed in radians.
    @param number nValue Input value; trigonometric input angles use radians.
    @ret number nResult Tangent of the angle in radians.

    @example
    local t = math.tan(math.pi / 4)
    !]]
    tan                 = math.tan,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.tointeger
    @pulsarlua function math.tointeger
    @desc Converts a value to an integer if it represents an exact integer numeric value.
    @param any vValue Value to convert to a Lua integer.
    @ret number|nil nInteger Integer result when representable, otherwise nil.

    @example
    local i = math.tointeger(3.0)
    !]]
    tointeger           = math.tointeger,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.type
    @pulsarlua function math.type
    @desc Returns whether a number is classified as an integer or a floating-point value.
    @param any vValue Value to classify.
    @ret string|nil sKind "integer" or "float" for numbers; nil for other values.

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
    @param number nLeft First integer.
    @param number nRight Second integer.
    @ret boolean bLess True when the first integer is smaller using unsigned comparison.

    @example
    local ok = math.ult(0xFFFFFFFF, 1)
    !]]
    ult                 = math.ult,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.math.Functions.whole
    @pulsarlua function math.whole
    @desc Converts a finite number's magnitude to a whole number, including zero. Floors by default, or rounds upward when requested.

    @param number nValue The input.
    @param boolean|nil bRaise Round upward; defaults to false.
    @ret number nRet The whole number.

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
--[[!
@fqxn CFS.UserEnv.Namespaces.RNG
@pulsarlua table RNG
@desc Random selection, probability checks, and dice utilities using the shared math.random stream. Call methods with a dot. Seed the shared stream through math.randomseed.
!]]
InjectEnv("RNG", {
    --[[!
    @fqxn CFS.UserEnv.Namespaces.RNG.Functions.binary
    @pulsarlua function RNG.binary
    @desc Returns 0 or 1; weight is the probability of 1. Defaults to 0.5.

    @param number vWeight Optional probability of 1 in [0, 1]; defaults to 0.5.
    @ret number nResult Zero or one.

    !]]
    binary          = RNG.binary,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.RNG.Functions.bipolar
    @pulsarlua function RNG.bipolar
    @desc Returns -1 or 1; weight is the probability of 1. Defaults to 0.5.

    @param number vWeight Optional probability of 1 in [0, 1]; defaults to 0.5.
    @ret number nResult Minus one or one.

    !]]
    bipolar         = RNG.bipolar,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.RNG.Functions.boolean
    @pulsarlua function RNG.boolean
    @desc Returns a boolean; weight is the probability of true. Defaults to 0.5.

    @param number vWeight Optional probability of true in [0, 1]; defaults to 0.5.
    @ret boolean bResult Random success value.

    !]]
    boolean         = RNG.boolean,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.RNG.Functions.choice
    @pulsarlua function RNG.choice
    @desc Returns one of two supplied values; weight is the probability of the second.



    @param any vItem1 First non-nil choice; false is allowed.
    @param any vItem2 Second non-nil choice; false is allowed.
    @param number vWeight Optional probability of the second choice in [0, 1]; defaults to 0.5.
    @ret any vResult One of the two supplied choices.

    !]]
    choice          = RNG.choice,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.RNG.Functions.multiChoice
    @pulsarlua function RNG.multiChoice
    @desc Uniformly selects among one or more non-nil arguments. Empty input or any nil position is rejected.

    @param any ... One or more non-nil choices.
    @ret any vResult One uniformly selected argument.

    !]]
    multiChoice     = RNG.multiChoice,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.RNG.Functions.percent
    @pulsarlua function RNG.percent
    @desc Returns an integer from 1 through 100; true returns that value divided by 100.

    @param boolean bFloat Optional flag to divide the result by 100.
    @ret number nResult Integer from 1 through 100, or a hundredth-step value from 0.01 through 1 when bFloat is true.

    !]]
    percent         = RNG.percent,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.RNG.Functions.pick
    @pulsarlua function RNG.pick
    @desc Selects numeric-keyed values without changing the source. Omitted count returns one value; a count returns a list. Repeats default to false.



    @param table tInput Source table; only numeric-keyed values participate.
    @param number nPicks Optional nonnegative integer count. Omit to return a single value.
    @param boolean bAllowRepeats Optional repeat flag; defaults to false.
    @ret any vResult Single selected value, or nil for an empty numeric list when nPicks is omitted. When nPicks is supplied, returns a list of selected values instead.

    !]]
    pick            = RNG.pick,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.RNG.Functions.randomx
    @pulsarlua function RNG.randomx
    @desc Returns an integer from 1 through nMax (1..10), using geometric weights 1,w,w^2. Weight defaults to 0.5 and must lie in [0.01,1].


    @param number nMax Optional integer maximum from 1 through 10; defaults to 1.
    @param number vWeight Optional geometric weight from 0.01 through 1; defaults to 0.5.
    @ret number nResult Integer from 1 through nMax; smaller weights favor lower values.

    !]]
    randomx         = RNG.randomx,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.RNG.Functions.rollCheck
    @pulsarlua function RNG.rollCheck
    @desc Rolls a die and returns success (roll >= threshold), roll, and roll minus threshold. Defaults are 20 sides and threshold 10.


    @param number nSides Optional positive integer die size; defaults to 20.
    @param number nCheck Optional integer success threshold; defaults to 10.
    @ret boolean bSuccess Whether the roll meets or exceeds the threshold.
    @ret number nRoll Die result.
    @ret number nMargin Roll minus threshold.

    !]]
    rollCheck       = RNG.rollCheck,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.RNG.Functions.rollDice
    @pulsarlua function RNG.rollDice
    @desc Returns the best complete dice sum across attempts. Defaults are 6 sides, one die and one attempt; all counts must be positive integers.



    @param number nSides Optional positive integer die size; defaults to 6.
    @param number nDice Optional positive integer dice count; defaults to 1.
    @param number nAttempts Optional positive integer attempt count; defaults to 1.
    @ret number nTotal Highest complete dice total across the attempts.

    !]]
    rollDice        = RNG.rollDice,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.RNG.Functions.rollPercentage
    @pulsarlua function RNG.rollPercentage
    @desc Returns success, lowest roll in (0,100], and chance minus roll. Stops on success. Defaults are 50 percent and one attempt; fractional chances are retained.


    @param number nChance Optional finite success percentage from 0 through 100; defaults to 50.
    @param number nAttempts Optional positive integer attempt count; defaults to 1.
    @ret boolean bSuccess Whether an attempt succeeds.
    @ret number nRoll Lowest roll in (0, 100], stopping on success.
    @ret number nMargin Chance minus the lowest roll.

    !]]
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
--[[!
@fqxn CFS.UserEnv.Namespaces.string
@pulsarlua table string
@desc Byte-string operations, Lua-pattern matching, validation, and LuaEx text helpers. Use the signatures shown for each function; string indices and lengths count bytes.
!]]
InjectEnv("string", {
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.byte
    @pulsarlua function string.byte
    @desc Returns numeric byte codes for the inclusive character range. Indices default to the first byte; negative indices count from the end.
    @param string sInput Input byte string.
    @param number nStart Optional start index.
    @param number nEnd Optional end index.
    @ret number ... Byte codes for the requested range; an empty range returns no values.

    !]]
    byte                = string.byte,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.cap
    @pulsarlua function string.cap
    @desc Uppercases the first byte, optionally lowercasing the remainder. Empty input returns empty. Uses Lua byte/locale casing, not Unicode title casing.


    @param string sInput Text to capitalize.
    @param boolean|nil bLowerRemaining Whether to lowercase remaining text.
    @ret string sRet Capitalized text.

    !]]
    cap                 = string.cap,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.capall
    @pulsarlua function string.capall
    @desc Capitalizes each nonempty literal-delimited item in order, rejoining with the same delimiter. Whitespace-only input returns empty text, zero and an empty table. Empty fields are omitted; the item list retains original text.


    @param string sInput Input text.
    @param string|nil sDelimiter Literal delimiter; defaults to a space.
    @ret string sRet Capitalized text.
    @ret number nItems Number of nonempty items.
    @ret table tItems Original ordered item strings.

    !]]
    capall              = string.capall,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.char
    @pulsarlua function string.char
    @desc Builds a string from the supplied integer byte codes.
    @param number ... Byte values from 0 through 255.
    @ret string sResult Byte string built from the codes.

    !]]
    char                = string.char,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.collapse
    @pulsarlua function string.collapse
    @desc Removes all Lua whitespace runs from text.

    @param string sInput Input text.
    @ret string sRet Text with whitespace removed.
    @ret number nRemoved Number of whitespace runs removed.

    !]]
    collapse            = string.collapse,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.find
    @pulsarlua function string.find
    @desc Finds the first match and returns its start and end indices plus captures, or nil. Uses Lua patterns unless plain search is requested.
    @param string sInput Text to search.
    @param string sPattern Pattern or literal text.
    @param number nStart Optional starting index.
    @param boolean bPlain Optional literal-search flag.
    @ret number|nil nStart First match start, or nil when no match exists.
    @ret number nEnd Match end on success.
    @ret any ... Captured substrings or position captures, when supplied by the pattern.

    !]]
    find                = string.find,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.format
    @pulsarlua function string.format
    @desc Formats arguments using a Lua format string and returns the resulting text.
    @param string sFormat Format string.
    @param any ... Values to format.
    @ret string sResult Formatted text.

    !]]
    format              = string.format,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.gmatch
    @pulsarlua function string.gmatch
    @desc Returns an iterator over successive Lua-pattern matches. Each iteration returns captures, or the whole match when no captures are supplied.
    @param string sInput Text to search.
    @param string sPattern Lua pattern.
    @ret function fIterator Iterator over matches or captures.

    !]]
    gmatch              = string.gmatch,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.gsub
    @pulsarlua function string.gsub
    @desc Replaces Lua-pattern matches and returns the new string and substitution count. Replacement may be a string, table, or function.
    @param string sInput Input text.
    @param string sPattern Lua pattern.
    @param any vReplacement Replacement string, table, or function.
    @param number nLimit Optional maximum substitution count.
    @ret string sResult Text after substitutions.
    @ret number nCount Number of matches processed.

    !]]
    gsub                = string.gsub,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.htmltomd
    @pulsarlua function string.htmltomd
    @desc Converts supported exact lowercase HTML tags to Markdown in a single pass. A preceding backslash keeps a tag literal and removes that escape. Other tags/attributes and HTML entities remain unchanged. This is a formatting helper, not a parser or sanitizer.

    @param string sText Text containing supported tags.
    @ret string sRet Converted text.

    !]]
    htmltomd            = string.htmltomd,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.isempty
    @pulsarlua function string.isempty
    @desc Reports whether a string contains no non-whitespace characters. Non-string values return false.

    @param any sInput Candidate text.
    @ret boolean bEmpty Whether the string is blank.

    !]]
    isempty             = string.isempty,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.isdatevalid
    @pulsarlua function string.isdatevalid
    @desc Checks an exact YYYY-MM-DD date using Gregorian leap-year rules. Returns a boolean for all inputs. Four-digit year zero is accepted; no alternative format is implemented.

    @param any sInput Candidate date.
    @ret boolean bValid Valid calendar date.

    !]]
    isdatevalid         = string.isdatevalid,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.isfilesafe
    @pulsarlua function string.isfilesafe
    @desc Checks a single filename component for the current platform using a conservative 255-byte limit. Rejects empty, dot/dot-dot and control-containing names. Windows also rejects device basenames with extensions and trailing dots/spaces. Does not verify filesystem availability or total path length.

    @param any sName Candidate filename, not a path.
    @ret boolean bSafe Whether the component meets these naming rules.

    !]]
    isfilesafe          = string.isfilesafe,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.iskeyword
    @pulsarlua function string.iskeyword
    @desc Checks exact case-sensitive membership in the initialized LuaEx keyword list.

    @param any sInput Candidate keyword.
    @ret boolean bKeyword Whether the value matches a keyword.

    !]]
    iskeyword           = string.iskeyword,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.isnumeric
    @pulsarlua function string.isnumeric
    @desc Uses tonumber to recognize Lua numeric syntax, including signed, exponent and hexadecimal forms. Rejects blank input and repeated decimal points. This checks syntax, not finiteness of the parsed number.

    @param any sInput Candidate numeric string.
    @ret boolean bNumeric Whether Lua can parse the string as a number.

    !]]
    isnumeric           = string.isnumeric,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.isuuid
    @pulsarlua function string.isuuid
    @desc Checks hexadecimal 8-4-4-4-12 UUID shape, in either case. Does not enforce version/variant bits. Non-string input returns false.

    @param any sInput Candidate identifier.
    @ret boolean bUUID Whether the UUID shape matches.

    !]]
    isuuid              = string.isuuid,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.isvariablecompliant
    @pulsarlua function string.isvariablecompliant
    @desc Checks a Lua-style identifier and, by default, excludes LuaEx keywords. Character classes use the Lua locale rather than Unicode identifier rules.


    @param any sInput Candidate identifier.
    @param boolean|nil bSkipKeywordCheck Whether to bypass keyword rejection.
    @ret boolean bCompliant Whether the identifier satisfies the requested policy.

    !]]
    isvariablecompliant = string.isvariablecompliant,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.len
    @pulsarlua function string.len
    @desc Returns the number of bytes in a string, including embedded zero bytes. This is not a Unicode character count.
    @param string sInput Input text.
    @ret number nLength Number of bytes.

    !]]
    len                 = string.len,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.lower
    @pulsarlua function string.lower
    @desc Returns a copy with uppercase letters converted to lowercase according to the current locale.
    @param string sInput Input text.
    @ret string sResult Lowercase copy.

    !]]
    lower               = string.lower,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.makefilesafe
    @pulsarlua function string.makefilesafe
    @desc Normalizes text into a portable filename component using underscores, a conservative 255-byte limit and Windows device-name protection. Empty results become underscore. May produce collisions; does not create files or guarantee name availability. Valid UTF-8 is not cut mid-character when truncating.


    @param string sInput Text to normalize.
    @param boolean|nil bLower Whether to lowercase the result.
    @ret string sRet Normalized filename component.

    !]]
    makefilesafe        = string.makefilesafe,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.match
    @pulsarlua function string.match
    @desc Returns captures from the first Lua-pattern match, or the whole match if there are no captures. Returns nil when no match exists.
    @param string sInput Text to search.
    @param string sPattern Lua pattern.
    @param number nStart Optional starting index.
    @ret any ... Captures, whole matched text when there are no captures, or nil when no match exists.

    !]]
    match               = string.match,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.rep
    @pulsarlua function string.rep
    @desc Repeats a string the requested number of times, optionally placing a separator between copies.
    @param string sInput Text to repeat.
    @param number nCount Repetition count.
    @param string sSeparator Optional separator.
    @ret string sResult Repeated text with optional separators.

    !]]
    rep                 = string.rep,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.reverse
    @pulsarlua function string.reverse
    @desc Returns the bytes in reverse order. Does not preserve multibyte Unicode characters.
    @param string sInput Input text.
    @ret string sResult Bytes in reverse order.

    !]]
    reverse             = string.reverse,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.sub
    @pulsarlua function string.sub
    @desc Returns the substring between inclusive byte indices. Negative indices count from the end; the ending index defaults to -1.
    @param string sInput Input text.
    @param number nStart Starting byte index.
    @param number nEnd Optional ending byte index.
    @ret string sResult Requested substring, or an empty string for an empty range.

    !]]
    sub                 = string.sub,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.tosid
    @pulsarlua function string.tosid
    @desc Converts tostring(input) to lowercase, collapses/trims whitespace and encodes normalized bytes as uppercase hex. Stable for the same normalized text; not a hash or a unique object identity.

    @param any sInput Value converted to text.
    @ret string sID Normalized byte-encoded identifier.

    !]]
    tosid               = string.tosid,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.totable
    @pulsarlua function string.totable
    @desc Splits on a literal delimiter, supporting multiple bytes and pattern punctuation. Defaults to comma. Optional callback transforms retained items; returning nil omits an item. Callback exceptions propagate. Empty input yields one empty item only when bAllowBlank is truthy.




    @param string sInput Text to split.
    @param string|nil sDelimiter Nonempty literal delimiter, default comma.
    @param boolean|nil bAllowBlank Whether to retain leading/repeated/trailing empty fields.
    @param function|nil fCallback Optional item transformer.
    @ret table tRet Dense ordered result list.

    !]]
    totable             = string.totable,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.trim
    @pulsarlua function string.trim
    @desc Removes leading and trailing Lua whitespace. Empty/whitespace-only input returns empty.

    @param string sInput Text to trim.
    @ret string sRet Trimmed text.

    !]]
    trim                = string.trim,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.trimleft
    @pulsarlua function string.trimleft
    @desc Removes leading Lua whitespace, preserving trailing content.

    @param string sInput Text to trim.
    @ret string sRet Left-trimmed text.

    !]]
    trimleft            = string.trimleft,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.trimright
    @pulsarlua function string.trimright
    @desc Removes trailing Lua whitespace, preserving leading content. All-whitespace input returns empty rather than nil.

    @param string sInput Text to trim.
    @ret string sRet Right-trimmed text.

    !]]
    trimright           = string.trimright,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.upper
    @pulsarlua function string.upper
    @desc Returns a copy with lowercase letters converted to uppercase according to the current locale.
    @param string sInput Input text.
    @ret string sResult Uppercase copy.

    !]]
    upper               = string.upper,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.string.Functions.uuid
    @pulsarlua function string.uuid
    @desc Generates a random hexadecimal 8-4-4-4-12 identifier using math.random. Does not enforce UUID version/variant bits and is not a cryptographic generator. Host controls RNG seeding.

    @param boolean|nil bUppercase Whether hexadecimal letters are uppercase.
    @ret string sUUID Generated identifier.

    !]]
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
--[[!
@fqxn CFS.UserEnv.Namespaces.table
@pulsarlua table table
@desc Sequence operations and a constructor for tables with selected metamethods. These functions can modify supplied tables; the read-only namespace prevents replacing the helper functions.
!]]
InjectEnv("table", {
    --[[!
    @fqxn CFS.UserEnv.Namespaces.table.Functions.concat
    @pulsarlua function table.concat
    @desc Joins sequence entries into a string. Entries must be strings or numbers. Separator defaults to an empty string; the range defaults to 1 through the sequence length.
    @param table tInput Sequence to join.
    @param string sSeparator Optional separator.
    @param number nStart Optional first index.
    @param number nEnd Optional last index.
    @ret string sResult Joined sequence text.

    !]]
    concat  = table.concat,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.table.Functions.insert
    @pulsarlua function table.insert
    @desc Inserts a value into a sequence, shifting following entries upward. With two arguments, appends the value to the end.
    @param table tInput Sequence to modify.
    @param any ... Value, or insertion position followed by value.
    @ret void none No values returned.

    !]]
    insert  = table.insert,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.table.Functions.move
    @pulsarlua function table.move
    @desc Copies an inclusive range of integer-indexed entries to a destination start index. Destination defaults to the source table. Handles overlapping ranges and returns the destination.
    @param table tSource Source table.
    @param number nFirst First source index.
    @param number nLast Last source index.
    @param number nTarget Destination start index.
    @param table tTarget Optional destination table.
    @ret table tResult Destination table.

    !]]
    move    = table.move,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.table.Functions.new
    @pulsarlua function table.new
    @desc Creates an empty writable table with supported function-valued metamethods copied from the supplied specification. Ordinary fields are not copied. The metatable is locked after construction; this does not make the table itself read-only.
    @param table tSpec Optional specification containing supported metamethod functions.
    @ret table tResult Empty writable table with selected metamethods and a locked metatable.
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
    --[[!
    @fqxn CFS.UserEnv.Namespaces.table.Functions.pack
    @pulsarlua function table.pack
    @desc Returns a table containing all supplied arguments at integer indices, with field n holding the total argument count, including nil arguments.
    @param any ... Values to pack.
    @ret table tResult Packed values with field n storing the full argument count.

    !]]
    pack    = table.pack,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.table.Functions.remove
    @pulsarlua function table.remove
    @desc Removes and returns a sequence entry, shifting following entries downward. Position defaults to the sequence length.
    @param table tInput Sequence to modify.
    @param number nPosition Optional removal index.
    @ret any vRemoved Removed value, or nil if no value was present at the accepted position.

    !]]
    remove  = table.remove,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.table.Functions.sort
    @pulsarlua function table.sort
    @desc Sorts a sequence in place. The optional comparison function must return true when its first argument should precede its second. Sorting is not stable.
    @param table tInput Sequence to sort.
    @param function fCompare Optional ordering function.
    @ret void none No values returned.

    !]]
    sort    = table.sort,
    --[[!
    @fqxn CFS.UserEnv.Namespaces.table.Functions.unpack
    @pulsarlua function table.unpack
    @desc Returns the entries in an inclusive integer-index range as separate results. Defaults to indices 1 through the sequence length. Use an explicit ending index to preserve packed trailing nil arguments.
    @param table tInput Table to unpack.
    @param number nStart Optional starting index.
    @param number nEnd Optional ending index.
    @ret any ... Entries in the requested range, including nil entries.

    !]]
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
    @ret table tEnv Current shared execution environment.

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
    @ret table tCommands Alphabetically sorted callable paths.

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
        @param string sPath Nonempty callable path to add to the command set.
        @vis private
        @ret void none No values returned.

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
        @param table t Table whose string keys are collected, including its registered backing table.
        @vis private
        @ret table tKeys Set of discovered string keys.

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
        @param table t Table whose string keys are collected, including its registered backing table.
        @param string sPrefix Optional parent path for nested command names.
        @vis private
        @ret void none No values returned.

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
    @ret table tEntries Completion entries containing name and kind fields.

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
    @ret void none No values returned.

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
    @desc Adds or replaces the supplied processing-owned root entries. When bPurge is true, first removes only previously tracked processing-owned entries; unrelated built-ins and user entries are not globally purged. Omitted keys remain unchanged when bPurge is false or omitted. Marks autocomplete entries for refresh.
    @param table tInput String-keyed entries to inject.
    @param boolean bPurge Optional flag to clear previously tracked processing-owned entries first.
    @ret void none No values returned.

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

    @param table tInput Replacement configuration table; non-table input resets configuration to an empty table.
    @ret void none No values returned.

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

    @param table tInput Replacement string-keyed user entries; non-table input makes no changes.
    @ret void none No values returned.

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
