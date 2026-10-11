--[[!
@fqxn CFS.Modules.Wiki.Themes
@desc
<section aria-label="Wiki.Themes overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">Wiki.Themes</h2><p style="font-size:1.15rem;margin:0">Wiki Themes supplies reading and editing palettes for game documents.</p></div>
<h3>How it fits into your work</h3><p>It derives palettes from shared editor themes while allowing the Wiki to retain an independent selection.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Wiki">Wiki</a></h3><p style="margin:0">The Wiki keeps written game material alongside card-making tools.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Wiki.Document">Wiki.Document</a></h3><p style="margin:0">Wiki Document turns rich text into the stored document format and back.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.EditorSettings">EditorSettings</a></h3><p style="margin:0">Shared settings keep the code editors consistent across projects.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">The Wiki palette does not select a Prism or generated API page theme.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

-- Shared palettes with independent wiki preferences and explicit text colors.
local Themes = {};
for _, tTheme in ipairs(require("Windows.EditorSettings").themes()) do
    Themes[#Themes + 1] = {name = tTheme.name, background = tTheme.colors[1], foreground = tTheme.colors[2]};
end
Themes[1].foreground = "#000000";
return Themes;
