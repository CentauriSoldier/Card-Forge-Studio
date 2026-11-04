-- Change the pinned Bootstrap version here. Overrides follow Bootstrap's CSS.
local sBootstrapVersion = "5.3.8";
local HTML = {};

function HTML.escape(sText)
    return tostring(sText):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;");
end

function HTML.shell(sBaseURL, sGameCSS, sHead, sBody)
    local sCDN = "https://cdn.jsdelivr.net/npm/bootstrap@"..sBootstrapVersion.."/dist/";
    return '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
        ..'<base href="'..HTML.escape(sBaseURL)..'"><title>Game Manual</title><link rel="stylesheet" href="'..sCDN..'css/bootstrap.min.css">'
        ..'<style id="cfs-game-styles">'..sGameCSS:gsub("<", "\\3c ")..'</style>'..(sHead or "")
        ..'<link rel="stylesheet" href="manual.css"></head><body>'..sBody
        ..'<script src="'..sCDN..'js/bootstrap.bundle.min.js"></script></body></html>';
end

function HTML.render(sContent, sBaseURL, sGameCSS)
    local sCSS = '<style>body{margin:0;background:#575d66;color:#222}.cfs-pages{padding:24px}.manual-page{position:relative;margin:0 auto 24px;background:white;overflow:hidden;box-shadow:0 3px 14px #2228;box-sizing:border-box}.manual-object{position:absolute;box-sizing:border-box;transform-origin:center}.manual-text{height:100%;width:100%;box-sizing:border-box;white-space:pre-wrap;overflow:hidden}.manual-text p{margin:0 0 .5em}.manual-image{width:100%;height:100%;display:block}.manual-number{position:absolute;pointer-events:none}.manual-page img{max-width:none}.manual-spread{position:relative;overflow:hidden;background:white}.spread-page{position:absolute;top:0}.spread-page .manual-page{margin:0;box-shadow:none}.page-object-clip{position:absolute;top:0;overflow:hidden;pointer-events:none}.spread-object-slot{position:absolute;inset:0;pointer-events:none}.spread-guides{z-index:1000;pointer-events:none}.manual-text ol,.manual-text ul{white-space:normal}@media print{body{background:white}.cfs-pages{padding:0}.manual-page{margin:0;box-shadow:none;break-after:page}.manual-page:last-child{break-after:auto}}</style>';
    if (not sContent:find('id="cfs-manual-state"', 1, true)) then sContent = '<main style="padding:2rem;background:white;max-width:900px;margin:auto">'..sContent..'</main>'; end
    return HTML.shell(sBaseURL, sGameCSS, sCSS, sContent);
end

return HTML;
