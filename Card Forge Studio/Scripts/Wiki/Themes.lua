--[[!
@fqxn CFS.Modules.Wiki.Themes
@desc Wiki palettes derived from the shared code-editor themes, with independent wiki selection.
!]]

-- Shared palettes with independent wiki preferences and explicit text colors.
local Themes = {};
for _, tTheme in ipairs(require("Windows.EditorSettings").themes()) do
    Themes[#Themes + 1] = {name = tTheme.name, background = tTheme.colors[1], foreground = tTheme.colors[2]};
end
Themes[1].foreground = "#000000";
return Themes;
