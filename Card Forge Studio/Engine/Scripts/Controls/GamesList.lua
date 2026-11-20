--[[!
@fqxn CardForgeEngine.Controls.GamesList
@desc Application configuration for wxLuma's image-and-text ListEx widget.
    The reusable framework remains unchanged.
!]]
local GamesList = {};

--[[!
@fqxn CardForgeEngine.Controls.GamesList.create
@desc Creates a single-selection game list with a thumbnail and title per row.
    The caller owns the shared skin and must dispose the list before its skin.
    Native controls belong to the parent. No example games are inserted.
@param wxWindow oParent Parent page panel.
@param table wxLuma The loaded local framework.
@param table oSkin Shared skin borrowed from the welcome page.
@param table|nil tItems Array of records: Image (path or nil), Title (text).
    Other row fields are preserved by ListEx for later game-loading metadata.
@ret table List wxLuma ListEx; setItems/addItem/setItem update its rows.
!]]
function GamesList.create(oParent, wxLuma, oSkin, tItems)
    local List = wxLuma.Controls.listEx(oParent, {
        Skin = oSkin,
        RowHeight = 76,
        MultiSelect = false,
        Columns = {
            {Key = "Image", Type = "image", Width = 76, Align = "center"},
            {Key = "Title", Type = "text", Weight = 1},
        },
        Items = tItems or {},
    });
    List.Control:SetName("Games");
    return List;
end

return GamesList;