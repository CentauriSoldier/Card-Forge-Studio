local fDialogExClose = DialogEx.Close;
local fDialogExShow = DialogEx.Show;
local _vDialogExDefaultRet = fDialogExClose;
local _vDialogExRet;
--TODO look more closely at this! why this ? _vDialogExDefaultRet
function DialogEx.Close(...)
    _vDialogExRet = {...};
    _vDialogExDefaultRet = fDialogExClose();
end

function DialogEx.Show(sName, bUseParentCoords, nX, nY)
    fDialogExShow(sName, bUseParentCoords or false, nX or nil, nY or nil);
    --return table.unpack(_vDialogExRet or {});
    return table.unpack(_vDialogExRet or {});
end
