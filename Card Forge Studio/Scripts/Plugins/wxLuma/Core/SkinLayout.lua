local SkinLayout = {};
local _tFolders = {
    {"Property Grid", "PropertyGrid"}, {"Circular Progress", "CircularProgress"},
    {"Collapsible Panel", "CollapsiblePanel"}, {"Date Time Picker", "DateTimePicker"},
    {"Dockable Panel", "DockablePanel"}, {"Multiline Text", "MultilineText"},
    {"Globe Progress", "GlobeProgress"}, {"Radial Progress", "RadialProgress"},
    {"Iris Progress", "IrisProgress"}, {"Toggle Button", "ToggleButton"},
    {"Range Slider", "RangeSlider"}, {"Color Picker", "ColorPicker"},
    {"Search Field", "SearchField"}, {"Numeric Field", "NumericField"},
    {"File Picker", "FilePicker"}, {"Combo Box", "ComboBox"}, {"Status Bar", "StatusBar"},
    {"Log Viewer", "LogViewer"}, {"Menu Bar", "MenuBar"},
    {"Menu Row", "ContextMenu"}, {"Menu Arrow", "ContextMenu"}, {"Menu Circle", "RadialMenu"},
    {"Menu Diamond", "RadialMenu"}, {"Menu Square", "RadialMenu"},
    {"Button", "PushButton"}, {"Checkbox", "Checkbox"}, {"Radio", "Radio"},
    {"Slider", "Slider"}, {"Spinner", "Spinner"}, {"Dropdown", "Dropdown"}, {"Progress", "Progress"},
    {"TreeEx", "TreeEx"}, {"ListEx", "ListEx"}, {"Tabs", "Tabs"},
    {"Toolbar", "Toolbar"}, {"Accordion", "Accordion"}, {"Breadcrumb", "Breadcrumb"},
    {"Notification", "Notification"}, {"Dialog", "Dialog"}, {"Knob", "Knob"},
    {"Switch", "Switch"}, {"LED", "LED"}, {"Chart", "Chart"},
};

--[[!
@fqxn wxLuma.UI.SkinLayout.folder
@desc Maps a semantic artwork family to its owning object's skin directory.
    Related implementations share their owner's parts; menu rows and radial
    materials have distinct owners. Unknown custom families use their first word.
!]]
function SkinLayout.folder(sName)
    for _, tEntry in ipairs(_tFolders) do
        if (sName == tEntry[1] or sName:sub(1, #tEntry[1] + 1) == tEntry[1].." ") then return tEntry[2]; end
    end
    return sName:match("^(%S+)");
end

--[[!
@fqxn wxLuma.UI.SkinLayout.path
@desc Resolves artwork exclusively within its owning object's skin directory.
    Only path lookup belongs here; control code never constructs image paths.
!]]
function SkinLayout.path(pRoot, sName)
    local pBase = pRoot:gsub("[/\\]+$", "").."/";
    local sFile = "Control "..sName..".png";
    return pBase..SkinLayout.folder(sName).."/"..sFile;
end

return SkinLayout;
