--[[!
@fqxn CFS.Classes.Tutorial
@desc Retained tutorial HTML generation class; some legacy initialization and validation remain incomplete.
!]]

local wx = require("wx");
local _sDefaultSection = "Basics";
local _pTutorials      = FS.Tutorials;

--[[!
@fqxn CFS.Classes.Tutorial.Private.FixPath
@desc Converts a local path to a file URL with normalized separators and encoded spaces.
@param any sPath Path.
@vis private
!]]
local function FixPath(sPath)
    return "file:///"..sPath:gsub("\\", '/'):gsub('//', '/'):gsub(' ', "%%20");
end

local _sTop = [[
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>Card Forge Studio — Tutorials</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <link rel="stylesheet" href="${CSS_Path}/bootstrap.min.css">
	<link rel="stylesheet" href="${CSS_Path}/prism.css">
	<link rel="stylesheet" href="${CSS_Path}/tutorials.css">
</head>

<body class="bg-light" data-nav-active="home">

    <!-- BANNER / HEADER -->
    <header class="bg-dark text-light py-4 mb-4">
        <div class="container-fluid">
            <h1 class="mb-1">Card Forge Studio</h1>
            <p class="mb-0 text-muted">Official Tutorials</p>
        </div>
    </header>

    <!-- MAIN CONTENT -->
    <main class="container-fluid">
    	<div class="row">

        <!-- NAV SIDEBAR -->
        <aside class="col-md-2 col-lg-2 mb-4">
            <div id="tutorialNav"></div>
        </aside>

        <!-- CONTENT -->
        <section class="col-md-10 col-lg-10">
            <div id="tutorialContent"></div>
        </section>
]];

local _sBottom = [[

        <div class="d-flex gap-2 mt-4 justify-content-between">
            <button id="btnPrev" class="btn btn-outline-secondary" disabled>← Previous</button>
            <button id="btnNext" class="btn btn-primary" disabled>Next →</button>
        </div>

        </div>
    </main>

    <!-- FOOTER -->
    <footer class="text-center text-muted py-3 mt-5">
        <small>Card Forge Studio — Tutorials</small>
    </footer>

    <script src="${JS_Path}/bootstrap.min.js"></script>
	<script src="${JS_Path}/prism.js"></script>
    <script src="${JS_Path}/tutorials.js"></script>
</body>
</html>
]];

--[[!
@fqxn CFS.Classes.Tutorial.Private.GetFileInfo
@desc Reads a tutorial HTML file and derives section, order, and title from its tilde-separated filename.
@param any pFile File.
@vis private
!]]
local function GetFileInfo(pFile)

    if not (type(pFile) == "string" and wx.wxFileExists(pFile)) then
        --TODO ERROR
    end

    local sFilename = assert(pFile:match("([^/\\]+)%.html$"));
    local tParts    = sFilename:totable('~');

    if not (type(tParts) == "table" and #tParts == 3) then
        --TODO ERROR
    end

    local sSection  = tParts[1];
    sSection        = (not sSection:isempty())  and sSection    or _sDefaultSection;
    local nOrder    = tonumber(tParts[2]) or 0;
    local sTitle    = tParts[3];
    sTitle          = (not sTitle:isempty())    and sTitle      or "UNKNOWN";
    local hFile     = assert(io.open(pFile, "rb"));
    local sHTML     = assert(hFile:read("a"));
    assert(hFile:close());

    return sSection, nOrder, sTitle, sHTML;
end


local Tutorial;

return class("Tutorial",
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --Tutorial = function(cClass, sAuthCode)
        --[[!
        @fqxn CFS.Classes.Tutorial.Methods.Tutorial
                @desc Retained class initialization hook for tutorial generation.
        @param any cTutorial C tutorial.
        @ret Tutorial Created instance.
        !]]
        Tutorial = function(cTutorial) Tutorial = cTutorial; end,
        PATH_INDEX__RO = FS.AppDir.."\\index.html",
        --end, --static constructor (runs after class object creation)
        --[[!
        @fqxn CFS.Classes.Tutorial.Methods.BuildHTML
        @pulsarlua function Tutorial.BuildHTML
        @desc Collects tutorial HTML files, orders sections and items, and writes the combined tutorial page.
        !]]
        BuildHTML = function()
            local tFiles = {};
            local oFolder = wx.wxDir(_pTutorials);
            assert(oFolder:IsOpened(), "Tutorial folder is unavailable.");
            local bFound, sName = oFolder:GetFirst("*.html", wx.wxDIR_FILES);
            while (bFound) do
                tFiles[#tFiles + 1] = _pTutorials.."/"..sName;
                bFound, sName = oFolder:GetNext();
            end
            oFolder:delete();
            table.sort(tFiles);
            local pTutorialsFixed   = FixPath(_pTutorials);
            local pImg              = pTutorialsFixed.."/img";

            local tSections      = {}; -- keyed by section name
            local tSectionOrder  = {}; -- first-seen order
            local tFlatOrder     = {}; -- global prev/next order

            -- collect files
            if (type(tFiles) == "table") then

                for _, pFile in ipairs(tFiles) do
                    local sSection, nOrder, sTitle, sHTML = GetFileInfo(pFile);

                    if not tSections[sSection] then
                        tSections[sSection] = {};
                        tSectionOrder[#tSectionOrder + 1] = sSection;
                    end

                    tSections[sSection][#tSections[sSection] + 1] = {
                        Order = nOrder,
                        Title = sTitle,
                        HTML  = sHTML % {img = pImg},
                        Key   = sSection.."~"..string.format("%03d", nOrder),
                    };
                end

            end

            -- sort items inside each section + build flat order
            for _, sSection in ipairs(tSectionOrder) do

                table.sort(tSections[sSection], function(a, b)
                    return a.Order < b.Order;
                end);

                for _, tItem in ipairs(tSections[sSection]) do
                    tFlatOrder[#tFlatOrder + 1] = tItem.Key;
                end

            end

            --build the JSON
            local sJSON = BuildJSON(tSections, tSectionOrder, tFlatOrder);

            -- build final HTML
            local sHTML =
            _sTop % {
                CSS_Path    = pTutorialsFixed.."/css",
                --Nav_Sidebar = BuildNavSidebar(),
            }..
            _sBottom % {
                JS_Path = pTutorialsFixed.."/js",
            }..
            sJSON;

            return sHTML;
        end,
        --[[!
        @fqxn CFS.Classes.Tutorial.Methods.Init
        @pulsarlua function Tutorial.Init
        @desc Builds tutorial HTML through the class's generation method.
        !]]
        Init = function()
            local sHTML = Tutorial.BuildHTML();
            local hFile = assert(io.open(Tutorial.PATH_INDEX, "wb"));
            assert(hFile:write(sHTML));
            assert(hFile:close());
        end
    },
    {--PRIVATE
        --[[!
        @fqxn CFS.Classes.Tutorial.Private.Tutorial
        @desc Retained class initialization hook for tutorial generation.
        @vis private
        !]]
        Tutorial = function(this, cdat) end,
    },
    {--PROTECTED

    },
    {--PUBLIC

    },
    nil,   --extending class
    true,  --if the class is final
    nil    --interface(s) (either nil, or interface(s))
);


