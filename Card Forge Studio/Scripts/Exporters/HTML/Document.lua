local Data     = require("Exporters.Data");
local Themes   = require("Exporters.HTML.Themes");
local Assets   = require("Exporters.HTML.Assets");
local assert   = assert;
local ipairs   = ipairs;
local math     = math;
local table    = table;
local Document = {};

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterHTML.Document
@desc Builds one portable themed index page, embedded final values, and local gallery assets. Card text is encoded as JSON and displayed as text rather than trusted HTML.
@vis private
!]]

--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterHTML.Document.Functions.build
@desc Creates HTML, CSS, and JavaScript output records. The image plan maps source rows to front and back filenames; shared backs are linked to every selected card.
@param table tData Ordered finalized snapshot.
@param table tImages PNG output records.
@param table tOptions Theme and title.
@param table tNames Card names.
@param number nWidth Output width.
@param number nHeight Output height.
@return table tFiles Page and assets.
@vis private
!]]
function Document.build(tData, tImages, tOptions, tNames, nWidth, nHeight)
    assert(Themes[tOptions.theme], "Unknown HTML theme.");
    local tMap, sShared, tCards, tColumns = {}, nil, {}, {};
    for _, tImage in ipairs(tImages) do
        if (tImage.name == "Shared_Back.png") then sShared = tImage.name;
        else tMap[tImage.row] = tMap[tImage.row] or {}; tMap[tImage.row][tImage.face] = tImage.name; end
    end
    for _, sColumn in ipairs(tData.columns) do tColumns[#tColumns + 1] = Data.quote(sColumn); end
    for _, tCard in ipairs(tData.cards) do
        local tFaces, tValues = tMap[tCard.row] or {}, {};
        for _, sValue in ipairs(tCard.values) do tValues[#tValues + 1] = Data.quote(sValue); end
        tCards[#tCards + 1] = '{"row":'..tCard.row..',"name":'..Data.quote(tNames[tCard.row] or "Card")..',"values":['..table.concat(tValues, ',')..'],"front":'..(tFaces.front and Data.quote(tFaces.front) or 'null')..',"back":'..((tFaces.back or sShared) and Data.quote(tFaces.back or sShared) or 'null')..'}';
    end
    local sManifest = '{"title":'..Data.quote(tOptions.title)..',"width":'..math.floor(nWidth)..',"height":'..math.floor(nHeight)..',"columns":['..table.concat(tColumns, ',')..'],"cards":['..table.concat(tCards, ',')..']}';
    sManifest = sManifest:gsub('<', '\\u003c'):gsub('>', '\\u003e'):gsub('&', '\\u0026');
    local sHTML = [=[<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Card Gallery</title><link rel="stylesheet" href="gallery.css"><script src="gallery.js" defer></script></head>
<body><main><header><p class="eyebrow">Card collection</p><h1 id="title">Card Gallery</h1><p>Explore the artwork, flip cards, and inspect their finalized details.</p></header>
<section class="tools" aria-label="Find cards"><label>Search<input id="search" type="search" placeholder="Name or any card value"></label><label>Filter column<select id="column"></select></label><label>Filter value<select id="value"></select></label><label>Sort<select id="sort"><option value="original">Export order</option><option value="ascending">Name A–Z</option><option value="descending">Name Z–A</option></select></label></section>
<div class="actions"><p id="count" role="status" aria-live="polite"></p><button id="flipAll" type="button">Flip all cards</button><button id="reset" type="button">Clear filters</button></div><section id="grid" class="grid" aria-label="Cards"></section><p id="empty" class="empty" hidden>No cards match. Try another search or clear the filters.</p><button id="more" type="button" hidden>Show more cards</button><p class="note">Select artwork to view a larger card and its data. This gallery works offline; keep its files together.</p><noscript><p>This interactive gallery requires JavaScript.</p></noscript></main>
<dialog id="detail" aria-labelledby="detailTitle"><div class="bar"><button id="previous" type="button">Previous</button><button id="next" type="button">Next</button><button id="detailFlip" type="button">Flip</button><button id="close" type="button">Close</button></div><div class="detail"><img id="detailImage" alt="Selected card"><section><h2 id="detailTitle"></h2><p id="position"></p><dl id="fields"></dl></section></div></dialog>
<script id="manifest" type="application/json">]=]..sManifest..[=[</script></body></html>
]=];
    return {{name = "index.html", bytes = sHTML}, {name = "gallery.css", bytes = Themes[tOptions.theme].css..Assets.css}, {name = "gallery.js", bytes = Assets.js}};
end
return Document;
