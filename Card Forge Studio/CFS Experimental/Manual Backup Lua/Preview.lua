-- Preview is the same native canvas without editing chrome.
local Canvas=require('Manual.Canvas');local Preview={};
function Preview.create(parent,editor) return Canvas.create(parent,editor,true);end
return Preview;
