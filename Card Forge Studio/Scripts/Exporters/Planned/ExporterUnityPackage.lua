--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterUnityPackage
@desc
<section aria-label="ExporterUnityPackage · Deferred overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">ExporterUnityPackage · Deferred</h2><p style="font-size:1.15rem;margin:0">This file reserves a place for a future export format.</p></div>
<h3>How it fits into your work</h3><p>Use the enabled PNG workflow for finished card images. This skeleton records a possible future direction without making it an available grid export.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Exporter">Exporter</a></h3><p style="margin:0">The export coordinator turns a planned batch into finished output files.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Exporter.Exporters.ExporterPNG">PNG Export</a></h3><p style="margin:0">PNG export turns your finished card artwork into individual image files.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Unfinished skeleton: its presence does not promise output files, settings, or integration.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
@vis private
!]]

local _sClass   = "";
local _sName    = "";
local _tReturns = {
    [1] = {""},
};


return class(_sClass,
    {--METAMETHODS

    },
    {--STATIC PUBLIC
        --__INIT = function(stapub) end, --static initializer (runs before class object creation)
        --[_sClass] = function(this, sAuthCode) end, --static constructor (runs after class object creation)
    },
    {--PRIVATE

    },
    {--PROTECTED

    },
    {--PUBLIC
        [_sClass] = function(this, cdat, super)
            super(_sName, _tReturns);
        end,
    },
    Exporter,   --extending class
    false,       --if the class is final
    nil         --interface(s) (either nil, or interface(s))
);
