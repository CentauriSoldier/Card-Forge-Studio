--[[!
@fqxn CFS.Manual.Bridge
@desc Chunked request/response transport between the original web editor and its game-bound Lua services. Only the owned host document is permitted to send requests by Adapter; this module does not execute browser-supplied Lua.
!]]

local JSON = require("Manual.Lib.dkjson");
local Bridge = {};

--[[!
@fqxn CFS.Manual.Bridge.Private.Functions.encodeText
@desc Percent-encodes UTF-8 bytes before embedding response JSON in a fixed JavaScript receiver call.
@param string sText Response JSON.
@return string sEncoded Script-safe encoded bytes.
@vis private
!]]
local function encodeText(sText)
	local tBytes = {};
	for nIndex = 1, #sText do tBytes[nIndex] = string.format("%%%02X", sText:byte(nIndex)); end
	return table.concat(tBytes);
end

--[[!
@fqxn CFS.Manual.Bridge.Functions.create
@desc Creates a bounded, sequential transport for one editor window. Requests span bounded document-title messages so larger Markdown drafts do not navigate the page or depend on URL-navigation limits.
@param table tService Game-bound service exposing request.
@return table tBridge Navigation handler and close operation.
!]]
function Bridge.create(tService)
	local tBridge = {};
	local tChunks = {};
	local sActive;
	local nExpected = 1;
	local nTotal;
	local nBytes = 0;
	local sCompletedID;
	local sCompletedMessage;
	local sCompletedScript;

	--[[!
	@fqxn CFS.Manual.Bridge.Instance.handle
	@desc Validates one protocol chunk received through the owned page title, acknowledges intermediate chunks, and dispatches complete JSON requests. Returns application-owned JavaScript for Adapter to publish asynchronously in the runtime reply file. Unsupported navigation returns nil.
	@param string sURL Intercepted navigation URL.
	@return string|nil sScript Application-owned acknowledgment or response script.
	!]]
	function tBridge.handle(sURL)
		local sMessage = sURL:gsub("%?attempt=%d+&length=", "?length=");
		local sID, sPart, sCount, sLength, sData = sMessage:match("^cfsmanual://bridge/([1-9]%d*)/(%d+)/(%d+)%?length=(%d+)&data=(.*)$");
		local nPart;
		local nCount;
		local sJSON;
		local tRequest;
		local nEnd;
		local sDecodeError;
		local bOK;
		local tResult;
		-- Retain small legacy messages while old pages are being closed. New
		-- title messages carry their exact encoded length so truncation cannot
		-- silently become a generic JSON parsing failure.
		if (not sID) then sID, sPart, sCount, sData = sMessage:match("^cfsmanual://bridge/([1-9]%d*)/(%d+)/(%d+)%?data=(.*)$"); end
		if (not sID or #sID > 9) then return nil; end
		if (sLength and tonumber(sLength) ~= #sData) then
			tBridge.close();
			return "window.CFSManual.receive("..sID..",decodeURIComponent('"..encodeText(JSON.encode({ok = false, message = "The browser truncated an editor message. No request was executed; restart Studio before retrying."})).."'));";
		end
		nPart, nCount = tonumber(sPart), tonumber(sCount);
		-- Replayed chunks receive their original acknowledgement/result. Never
		-- execute a completed save or export again after a lost browser reply.
		if (sID == sCompletedID and sMessage == sCompletedMessage) then return sCompletedScript; end
		if (sActive == sID and nPart == nExpected - 1 and nCount == nTotal and tChunks[nPart] == sData) then
			return "window.CFSManual.ack("..sID..","..nPart..");";
		end
		if (nPart == 1) then sActive, nExpected, nTotal, nBytes, tChunks = sID, 1, nCount, 0, {}; end
		if (sActive ~= sID or nPart ~= nExpected or nCount ~= nTotal or nCount < 1 or nCount > 4096 or #sData > 2048 or nBytes + #sData > 8000000) then
			tBridge.close();
			return "window.CFSManual.receive("..sID..",decodeURIComponent('"..encodeText(JSON.encode({ok = false, message = "Invalid or oversized editor request."})).."'));";
		end
		tChunks[nPart] = sData;
		nBytes, nExpected = nBytes + #sData, nExpected + 1;
		if (nPart < nTotal) then return "window.CFSManual.ack("..sID..","..nPart..");"; end
		sJSON = table.concat(tChunks):gsub("%%(%x%x)", function(sHex) return string.char(tonumber(sHex, 16)); end);
		tBridge.close();
		tRequest, nEnd, sDecodeError = JSON.decode(sJSON);
		if (sDecodeError or type(tRequest) ~= "table" or not sJSON:sub(nEnd):match("^%s*$")) then
			tResult = {ok = false, message = "Invalid editor request JSON."};
		else
			bOK, tResult = pcall(tService.request, tRequest);
			if (not bOK) then tResult = {ok = false, message = tostring(tResult)}; end
		end
		sCompletedID, sCompletedMessage = sID, sMessage;
		sCompletedScript = "window.CFSManual.receive("..sID..",decodeURIComponent('"..encodeText(JSON.encode(tResult)).."'));";
		return sCompletedScript;
	end

	--[[!
	@fqxn CFS.Manual.Bridge.Instance.close
	@desc Releases buffered request bytes. Safe after completion and during window close.
	!]]
	function tBridge.close()
		tChunks, sActive, nExpected, nTotal, nBytes = {}, nil, 1, nil, 0;
	end
	return tBridge;
end

return Bridge;
